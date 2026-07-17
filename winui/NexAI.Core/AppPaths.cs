namespace NexAI.Core;

public static class AppPaths
{
    public static string RootDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NexAI",
        "WinUI3");

    public static string SettingsFilePath => Path.Combine(RootDirectory, "settings.json");
    public static string ConversationsFilePath => Path.Combine(RootDirectory, "conversations.json");

    public static void EnsureRoot()
    {
        Directory.CreateDirectory(RootDirectory);
    }
}
