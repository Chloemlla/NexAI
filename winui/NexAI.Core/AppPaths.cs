namespace NexAI.Core;

public static class AppPaths
{
    public static string RootDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NexAI",
        "WinUI3");

    public static string SettingsFilePath => Path.Combine(RootDirectory, "settings.json");
    public static string ConversationsFilePath => Path.Combine(RootDirectory, "conversations.json");
    public static string NotesFilePath => Path.Combine(RootDirectory, "notes.json");
    public static string AuthFilePath => Path.Combine(RootDirectory, "auth.json");
    public static string SyncKeyFilePath => Path.Combine(RootDirectory, "sync-key.b64");
    public static string SyncMetaFilePath => Path.Combine(RootDirectory, "sync-meta.json");
    public static string MigrationMarkerPath => Path.Combine(RootDirectory, "flutter-migration.json");

    public static void EnsureRoot() => Directory.CreateDirectory(RootDirectory);
}
