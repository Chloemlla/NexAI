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
    string TitleKey,
    string DescriptionKey,
    string CategoryKey,
    string Glyph);

public static class ToolCatalog
{
    public static IReadOnlyList<ToolDefinition> All { get; } =
    [
        new(ToolKind.DateTime, "Tool.DateTime.Title", "Tool.DateTime.Description", "Tool.Category.Convert", "\uE823"),
        new(ToolKind.Base64, "Tool.Base64.Title", "Tool.Base64.Description", "Tool.Category.Convert", "\uE943"),
        new(ToolKind.Password, "Tool.Password.Title", "Tool.Password.Description", "Tool.Category.Security", "\uE72E"),
        new(ToolKind.ShortUrl, "Tool.ShortUrl.Title", "Tool.ShortUrl.Description", "Tool.Category.Network", "\uE71B"),
        new(ToolKind.Translation, "Tool.Translation.Title", "Tool.Translation.Description", "Tool.Category.AI", "\uF2B7"),
        new(ToolKind.ImageGeneration, "Tool.ImageGeneration.Title", "Tool.ImageGeneration.Description", "Tool.Category.AI", "\uE790"),
        new(ToolKind.Artifacts, "Tool.Artifacts.Title", "Tool.Artifacts.Description", "Tool.Category.Network", "\uE72D"),
        new(ToolKind.VideoCompress, "Tool.VideoCompress.Title", "Tool.VideoCompress.Description", "Tool.Category.Media", "\uE714"),
        new(ToolKind.VideoToAudio, "Tool.VideoToAudio.Title", "Tool.VideoToAudio.Description", "Tool.Category.Media", "\uE189"),
    ];
}
