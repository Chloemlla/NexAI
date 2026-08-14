using System.Diagnostics;
using System.Text;
using NexAI.Core.Tools;

namespace NexAI.Infrastructure.Media;

public sealed class FfmpegMediaToolService : IMediaToolService
{
    public Task<MediaProcessResult> CompressVideoAsync(
        string inputPath,
        string? outputPath = null,
        int crf = 28,
        CancellationToken cancellationToken = default)
    {
        var safeInput = ValidateExistingMediaPath(inputPath, nameof(inputPath));
        crf = Math.Clamp(crf, 18, 40);
        var safeOutput = string.IsNullOrWhiteSpace(outputPath)
            ? CreateManagedOutputPath(safeInput, "compressed", "mp4")
            : ValidateOutputPath(outputPath, nameof(outputPath));

        var args = new[]
        {
            "-y",
            "-i", safeInput,
            "-vcodec", "libx264",
            "-crf", crf.ToString(),
            "-preset", "medium",
            "-acodec", "aac",
            "-b:a", "128k",
            safeOutput,
        };
        return RunFfmpegAsync(safeInput, safeOutput, args, cancellationToken);
    }

    public Task<MediaProcessResult> ExtractAudioAsync(
        string inputPath,
        string? outputPath = null,
        string format = "mp3",
        CancellationToken cancellationToken = default)
    {
        var safeInput = ValidateExistingMediaPath(inputPath, nameof(inputPath));
        format = string.IsNullOrWhiteSpace(format) ? "mp3" : format.Trim().TrimStart('.').ToLowerInvariant();
        if (format is not ("mp3" or "aac" or "wav"))
        {
            throw new ArgumentOutOfRangeException(nameof(format), "Supported formats: mp3, aac, wav.");
        }

        var codecArgs = format switch
        {
            "aac" => new[] { "-c:a", "aac", "-b:a", "192k" },
            "wav" => new[] { "-c:a", "pcm_s16le" },
            _ => new[] { "-c:a", "libmp3lame", "-b:a", "192k" },
        };

        var safeOutput = string.IsNullOrWhiteSpace(outputPath)
            ? CreateManagedOutputPath(safeInput, "audio", format)
            : ValidateOutputPath(outputPath, nameof(outputPath));

        var args = new List<string> { "-y", "-i", safeInput, "-vn" };
        args.AddRange(codecArgs);
        args.Add(safeOutput);
        return RunFfmpegAsync(safeInput, safeOutput, args, cancellationToken);
    }

    private static async Task<MediaProcessResult> RunFfmpegAsync(
        string inputPath,
        string outputPath,
        IReadOnlyList<string> args,
        CancellationToken cancellationToken)
    {
        var ffmpeg = ResolveFfmpegPath();
        if (ffmpeg is null)
        {
            throw new InvalidOperationException(
                "ffmpeg was not found. Install ffmpeg and ensure it is on PATH, or set NEXAI_FFMPEG to the executable path.");
        }

        var psi = new ProcessStartInfo
        {
            FileName = ffmpeg,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        using var process = new Process { StartInfo = psi };
        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        process.OutputDataReceived += (_, e) =>
        {
            if (e.Data is not null)
            {
                stdout.AppendLine(e.Data);
            }
        };
        process.ErrorDataReceived += (_, e) =>
        {
            if (e.Data is not null)
            {
                stderr.AppendLine(e.Data);
            }
        };

        if (!process.Start())
        {
            throw new InvalidOperationException("Failed to start ffmpeg.");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);

        // Give the async output readers a moment to drain remaining data after the process exits.
        // Without this, the final lines of stdout/stderr may be truncated.
        await Task.Delay(100, cancellationToken).ConfigureAwait(false);

        var exitCode = process.ExitCode;

        // Best-effort cleanup of stale temp media files older than 1 hour.
        CleanupStaleTempFiles(outputPath);

        return new MediaProcessResult
        {
            InputPath = inputPath,
            OutputPath = exitCode != 0 ? TryCleanupFailedOutput(outputPath) : outputPath,
            Command = "ffmpeg " + string.Join(' ', args.Select(QuoteForDisplay)),
            ExitCode = exitCode,
            StdOut = stdout.ToString(),
            StdErr = stderr.ToString(),
        };
    }

    private static string? ResolveFfmpegPath()
    {
        var env = Environment.GetEnvironmentVariable("NEXAI_FFMPEG");
        if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
        {
            return env;
        }

        var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var dir in pathEnv.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(dir.Trim('"'), OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private static string ValidateExistingMediaPath(string path, string paramName)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw new ArgumentException("Media path is required.", paramName);
        }

        string full;
        try
        {
            full = Path.GetFullPath(path);
        }
        catch (Exception ex)
        {
            throw new ArgumentException("Invalid media path.", paramName, ex);
        }

        if (!File.Exists(full))
        {
            throw new FileNotFoundException("Input video not found.", full);
        }

        // Reject shell metacharacters that should never appear in validated absolute paths
        // for this tool surface.
        if (full.IndexOfAny(['\r', '\n', '\0']) >= 0)
        {
            throw new ArgumentException("Media path contains illegal control characters.", paramName);
        }

        return full;
    }

    private static string ValidateOutputPath(string path, string paramName)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw new ArgumentException("Output path is required.", paramName);
        }

        string full;
        try
        {
            full = Path.GetFullPath(path);
        }
        catch (Exception ex)
        {
            throw new ArgumentException("Invalid output path.", paramName, ex);
        }

        var dir = Path.GetDirectoryName(full);
        if (string.IsNullOrWhiteSpace(dir))
        {
            throw new ArgumentException("Output path must include a directory.", paramName);
        }

        Directory.CreateDirectory(dir);
        if (full.IndexOfAny(['\r', '\n', '\0']) >= 0)
        {
            throw new ArgumentException("Output path contains illegal control characters.", paramName);
        }

        return full;
    }

    private static string CreateManagedOutputPath(string inputPath, string suffix, string extension)
    {
        var dir = Path.Combine(Path.GetTempPath(), "NexAI", "media");
        Directory.CreateDirectory(dir);
        var name = Path.GetFileNameWithoutExtension(inputPath);
        // Keep generated names filesystem-safe and free of quote/space surprises.
        foreach (var c in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(c, '_');
        }

        return Path.Combine(dir, $"{name}_{suffix}_{DateTime.Now:yyyyMMdd_HHmmss}.{extension}");
    }

    private static string QuoteForDisplay(string value) =>
        value.Contains(' ') || value.Contains('"')
            ? "\"" + value.Replace("\"", "\\\"") + "\""
            : value;

    private static void CleanupStaleTempFiles(string currentOutputPath)
    {
        try
        {
            var tempDir = Path.Combine(Path.GetTempPath(), "NexAI", "media");
            if (!Directory.Exists(tempDir))
            {
                return;
            }

            var stale = DateTime.UtcNow.AddHours(-1);
            foreach (var file in Directory.GetFiles(tempDir))
            {
                if (string.Equals(file, currentOutputPath, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try
                {
                    if (File.GetLastWriteTimeUtc(file) < stale)
                    {
                        File.Delete(file);
                    }
                }
                catch
                {
                    // Best-effort; skip files that are locked or inaccessible.
                }
            }
        }
        catch
        {
            // Best-effort cleanup; never crash the caller.
        }
    }

    private static string? TryCleanupFailedOutput(string outputPath)
    {
        try
        {
            if (File.Exists(outputPath))
            {
                File.Delete(outputPath);
            }
        }
        catch
        {
            // Best-effort; the caller will get a non-zero exit code.
        }

        return null;
    }
}
