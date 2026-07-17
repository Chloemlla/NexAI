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
        if (!File.Exists(inputPath))
        {
            throw new FileNotFoundException("Input video not found.", inputPath);
        }

        crf = Math.Clamp(crf, 18, 40);
        var output = outputPath;
        if (string.IsNullOrWhiteSpace(output))
        {
            var dir = Path.Combine(Path.GetTempPath(), "NexAI", "media");
            Directory.CreateDirectory(dir);
            output = Path.Combine(
                dir,
                Path.GetFileNameWithoutExtension(inputPath) + $"_compressed_{DateTime.Now:yyyyMMdd_HHmmss}.mp4");
        }

        var args = $"-y -i \"{inputPath}\" -vcodec libx264 -crf {crf} -preset medium -acodec aac -b:a 128k \"{output}\"";
        return RunFfmpegAsync(inputPath, output!, args, cancellationToken);
    }

    public Task<MediaProcessResult> ExtractAudioAsync(
        string inputPath,
        string? outputPath = null,
        string format = "mp3",
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(inputPath))
        {
            throw new FileNotFoundException("Input video not found.", inputPath);
        }

        format = string.IsNullOrWhiteSpace(format) ? "mp3" : format.Trim().TrimStart('.').ToLowerInvariant();
        var codecArgs = format switch
        {
            "aac" => "-c:a aac -b:a 192k",
            "wav" => "-c:a pcm_s16le",
            _ => "-c:a libmp3lame -b:a 192k",
        };

        var output = outputPath;
        if (string.IsNullOrWhiteSpace(output))
        {
            var dir = Path.Combine(Path.GetTempPath(), "NexAI", "media");
            Directory.CreateDirectory(dir);
            output = Path.Combine(
                dir,
                Path.GetFileNameWithoutExtension(inputPath) + $"_{DateTime.Now:yyyyMMdd_HHmmss}.{format}");
        }

        var args = $"-y -i \"{inputPath}\" -vn {codecArgs} \"{output}\"";
        return RunFfmpegAsync(inputPath, output!, args, cancellationToken);
    }

    private static async Task<MediaProcessResult> RunFfmpegAsync(
        string inputPath,
        string outputPath,
        string args,
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
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

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

        return new MediaProcessResult
        {
            InputPath = inputPath,
            OutputPath = outputPath,
            Command = $"ffmpeg {args}",
            ExitCode = process.ExitCode,
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
}
