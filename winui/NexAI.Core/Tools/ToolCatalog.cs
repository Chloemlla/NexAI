namespace NexAI.Core.Tools;

public enum ToolKind
{
    Base64,
    DateTime,
    Password,
    ShortUrl,
    Translation,
    ImageGeneration,
    VideoCompress,
    VideoToAudio,
    Artifacts,
}

public sealed record ToolDefinition(
    ToolKind Kind,
    string Title,
    string Description,
    string Category,
    string Glyph);

public static class ToolCatalog
{
    public static IReadOnlyList<ToolDefinition> All { get; } =
    [
        new(ToolKind.DateTime, "Date / Time Converter", "Convert timestamps and common date formats", "Convert", "\uE823"),
        new(ToolKind.Base64, "Base64 Encoder", "Encode and decode Base64 strings", "Convert", "\uE943"),
        new(ToolKind.Password, "Password Generator", "Generate strong random passwords", "Security", "\uE72E"),
        new(ToolKind.ShortUrl, "Short URL", "Create short links via NexAI backend", "Network", "\uE71B"),
        new(ToolKind.Translation, "AI Translation", "Translate text using the configured chat API", "AI", "\uF2B7"),
        new(ToolKind.ImageGeneration, "AI Image Generation", "Generate images through compatible image endpoints", "AI", "\uE790"),
        new(ToolKind.Artifacts, "Artifacts Share", "Share text/code artifacts (backend-backed)", "Network", "\uE72D"),
        new(ToolKind.VideoCompress, "Video Compressor", "Compress local videos (Windows pipeline)", "Media", "\uE714"),
        new(ToolKind.VideoToAudio, "Video to Audio", "Extract audio tracks from videos", "Media", "\uE189"),
    ];
}
