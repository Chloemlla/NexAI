namespace NexAI.Core.Tools;

public sealed class ShortUrlResult
{
    public required string OriginalUrl { get; init; }
    public required string ShortUrl { get; init; }
}

public sealed class ArtifactCreateResult
{
    public required string ShortId { get; init; }
    public required string Url { get; init; }
    public string? Title { get; init; }
}

public sealed class ImageGenerationResult
{
    public required IReadOnlyList<string> ImageUrls { get; init; }
    public string? RawResponse { get; init; }
}

public sealed class MediaProcessResult
{
    public required string InputPath { get; init; }
    public required string OutputPath { get; init; }
    public required string Command { get; init; }
    public required int ExitCode { get; init; }
    public string StdOut { get; init; } = string.Empty;
    public string StdErr { get; init; } = string.Empty;
    public bool Success => ExitCode == 0 && File.Exists(OutputPath);
}

public interface IShortUrlClient
{
    Task<ShortUrlResult> CreateAsync(string longUrl, CancellationToken cancellationToken = default);
}

public interface IArtifactsClient
{
    Task<ArtifactCreateResult> CreateAsync(
        string backendBaseUrl,
        string accessToken,
        string title,
        string content,
        string contentType = "text",
        string? language = null,
        CancellationToken cancellationToken = default);
}

public interface IImageGenerationClient
{
    Task<ImageGenerationResult> GenerateAsync(
        string baseUrl,
        string apiKey,
        string model,
        string prompt,
        CancellationToken cancellationToken = default);
}

public interface IMediaToolService
{
    Task<MediaProcessResult> CompressVideoAsync(
        string inputPath,
        string? outputPath = null,
        int crf = 28,
        CancellationToken cancellationToken = default);

    Task<MediaProcessResult> ExtractAudioAsync(
        string inputPath,
        string? outputPath = null,
        string format = "mp3",
        CancellationToken cancellationToken = default);
}
