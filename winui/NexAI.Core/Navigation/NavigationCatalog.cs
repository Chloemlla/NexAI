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
    string TitleKey,
    string Glyph,
    string Tag);

public static class NavigationCatalog
{
    public static IReadOnlyList<NavigationItem> PrimaryItems { get; } =
    [
        new(AppPage.Chat, "Nav.Chat", "\uE8BD", "chat"),
        new(AppPage.Notes, "Nav.Notes", "\uE70B", "notes"),
        new(AppPage.Tools, "Nav.Tools", "\uEC7A", "tools"),
        new(AppPage.Settings, "Nav.Settings", "\uE713", "settings"),
    ];

    public static NavigationItem Get(AppPage page) =>
        PrimaryItems.First(item => item.Page == page);

    public static NavigationItem? FindByTag(string? tag) =>
        PrimaryItems.FirstOrDefault(item =>
            string.Equals(item.Tag, tag, StringComparison.OrdinalIgnoreCase));
}
