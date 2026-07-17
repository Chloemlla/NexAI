namespace NexAI.Core.Navigation;

public enum AppPage
{
    Chat,
    Notes,
    Tools,
    Settings,
}

public sealed record NavigationItem(
    AppPage Page,
    string Title,
    string Glyph,
    string Tag);

public static class NavigationCatalog
{
    public static IReadOnlyList<NavigationItem> PrimaryItems { get; } =
    [
        new(AppPage.Chat, "Chat", "\uE8BD", "chat"),
        new(AppPage.Notes, "Notes", "\uE70B", "notes"),
        new(AppPage.Tools, "Tools", "\uEC7A", "tools"),
        new(AppPage.Settings, "Settings", "\uE713", "settings"),
    ];

    public static NavigationItem Get(AppPage page) =>
        PrimaryItems.First(item => item.Page == page);

    public static NavigationItem? FindByTag(string? tag) =>
        PrimaryItems.FirstOrDefault(item =>
            string.Equals(item.Tag, tag, StringComparison.OrdinalIgnoreCase));
}
