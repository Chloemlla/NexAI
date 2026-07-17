using System.Text.Json;
using NexAI.Core;
using NexAI.Core.Chat;
using NexAI.Core.Migration;
using NexAI.Core.Notes;
using NexAI.Core.Settings;

namespace NexAI.Infrastructure.Migration;

public sealed class FlutterDataMigrator : IFlutterDataMigrator
{
    private readonly ISettingsStore _settingsStore;
    private readonly IConversationStore _conversationStore;
    private readonly INotesStore _notesStore;

    public FlutterDataMigrator(
        ISettingsStore settingsStore,
        IConversationStore conversationStore,
        INotesStore notesStore)
    {
        _settingsStore = settingsStore;
        _conversationStore = conversationStore;
        _notesStore = notesStore;
    }

    public async Task<FlutterMigrationResult> TryMigrateAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (File.Exists(AppPaths.MigrationMarkerPath))
        {
            return new FlutterMigrationResult
            {
                Attempted = false,
                Applied = false,
                Message = "Flutter migration already completed.",
            };
        }

        // Skip if WinUI already has local content.
        if (_conversationStore.Conversations.Count > 0 || _notesStore.Notes.Count > 0)
        {
            await WriteMarkerAsync("skipped-existing-winui-data", cancellationToken).ConfigureAwait(false);
            return new FlutterMigrationResult
            {
                Attempted = true,
                Applied = false,
                Message = "Skipped because WinUI local data already exists.",
            };
        }

        var candidates = DiscoverFlutterDocumentRoots().ToList();
        if (candidates.Count == 0)
        {
            await WriteMarkerAsync("no-flutter-data", cancellationToken).ConfigureAwait(false);
            return new FlutterMigrationResult
            {
                Attempted = true,
                Applied = false,
                Message = "No Flutter document data found.",
            };
        }

        var importedConversations = 0;
        var importedNotes = 0;
        var importedSettings = false;
        var messages = new List<string>();

        foreach (var root in candidates)
        {
            var chats = Path.Combine(root, "nexai_chats.json");
            if (File.Exists(chats))
            {
                importedConversations += await ImportConversationsAsync(chats, cancellationToken).ConfigureAwait(false);
                messages.Add($"chats:{chats}");
            }

            var notes = Path.Combine(root, "nexai_notes.json");
            if (File.Exists(notes))
            {
                importedNotes += await ImportNotesAsync(notes, cancellationToken).ConfigureAwait(false);
                messages.Add($"notes:{notes}");
            }
        }

        // SharedPreferences file migration is best-effort and optional.
        foreach (var prefs in DiscoverSharedPreferencesFiles())
        {
            if (await TryImportSettingsFromPrefsAsync(prefs, cancellationToken).ConfigureAwait(false))
            {
                importedSettings = true;
                messages.Add($"prefs:{prefs}");
                break;
            }
        }

        await WriteMarkerAsync(string.Join(" | ", messages), cancellationToken).ConfigureAwait(false);
        return new FlutterMigrationResult
        {
            Attempted = true,
            Applied = importedConversations > 0 || importedNotes > 0 || importedSettings,
            Message = importedConversations + importedNotes > 0 || importedSettings
                ? $"Imported {importedConversations} chats, {importedNotes} notes, settings={importedSettings}."
                : "Flutter paths found but no importable content.",
            ImportedConversations = importedConversations,
            ImportedNotes = importedNotes,
            ImportedSettings = importedSettings,
        };
    }

    private async Task<int> ImportConversationsAsync(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        if (doc.RootElement.ValueKind != JsonValueKind.Array)
        {
            return 0;
        }

        var count = 0;
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            var created = await _conversationStore.CreateAsync(cancellationToken).ConfigureAwait(false);
            var title = item.TryGetProperty("title", out var t) ? t.GetString() ?? "Imported chat" : "Imported chat";
            await _conversationStore.RenameAsync(created.Id, title, cancellationToken).ConfigureAwait(false);

            if (item.TryGetProperty("messages", out var messages) && messages.ValueKind == JsonValueKind.Array)
            {
                foreach (var message in messages.EnumerateArray())
                {
                    await _conversationStore.AppendMessageAsync(
                        created.Id,
                        new ChatMessage
                        {
                            Role = message.TryGetProperty("role", out var role) ? role.GetString() ?? ChatRoles.User : ChatRoles.User,
                            Content = message.TryGetProperty("content", out var content) ? content.GetString() ?? string.Empty : string.Empty,
                            Timestamp = message.TryGetProperty("timestamp", out var ts) && DateTime.TryParse(ts.GetString(), out var parsed)
                                ? parsed.ToUniversalTime()
                                : DateTime.UtcNow,
                            IsError = message.TryGetProperty("isError", out var err) && err.ValueKind == JsonValueKind.True,
                        },
                        persist: true,
                        cancellationToken: cancellationToken).ConfigureAwait(false);
                }
            }

            count++;
        }

        return count;
    }

    private async Task<int> ImportNotesAsync(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        if (doc.RootElement.ValueKind != JsonValueKind.Array)
        {
            return 0;
        }

        var notes = new List<Note>();
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            notes.Add(new Note
            {
                Id = item.TryGetProperty("id", out var id) ? id.GetString() ?? Guid.NewGuid().ToString("D") : Guid.NewGuid().ToString("D"),
                Title = item.TryGetProperty("title", out var title) ? title.GetString() ?? "Untitled Note" : "Untitled Note",
                Content = item.TryGetProperty("content", out var content) ? content.GetString() ?? string.Empty : string.Empty,
                CreatedAt = item.TryGetProperty("createdAt", out var created) && DateTime.TryParse(created.GetString(), out var c)
                    ? c.ToUniversalTime()
                    : DateTime.UtcNow,
                UpdatedAt = item.TryGetProperty("updatedAt", out var updated) && DateTime.TryParse(updated.GetString(), out var u)
                    ? u.ToUniversalTime()
                    : DateTime.UtcNow,
                IsStarred = item.TryGetProperty("isStarred", out var starred) && starred.ValueKind == JsonValueKind.True,
            });
        }

        if (notes.Count == 0)
        {
            return 0;
        }

        await _notesStore.ReplaceAllAsync(notes, cancellationToken).ConfigureAwait(false);
        return notes.Count;
    }

    private async Task<bool> TryImportSettingsFromPrefsAsync(string prefsPath, CancellationToken cancellationToken)
    {
        // Flutter Windows shared_preferences often stores values in a JSON map file.
        try
        {
            var text = await File.ReadAllTextAsync(prefsPath, cancellationToken).ConfigureAwait(false);
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.ValueKind != JsonValueKind.Object)
            {
                return false;
            }

            var settings = _settingsStore.Current;
            var changed = false;

            if (TryGetPrefString(doc.RootElement, "flutter.openaiBaseUrl", out var baseUrl) ||
                TryGetPrefString(doc.RootElement, "openaiBaseUrl", out baseUrl))
            {
                settings.BaseUrl = baseUrl;
                changed = true;
            }

            if (TryGetPrefString(doc.RootElement, "flutter.selectedModel", out var model) ||
                TryGetPrefString(doc.RootElement, "selectedModel", out model))
            {
                settings.SelectedModel = model;
                changed = true;
            }

            if (TryGetPrefString(doc.RootElement, "flutter.themeMode", out var theme) ||
                TryGetPrefString(doc.RootElement, "themeMode", out theme))
            {
                if (Enum.TryParse<AppThemeMode>(theme, true, out var mode))
                {
                    settings.ThemeMode = mode;
                    changed = true;
                }
            }

            if (!changed)
            {
                return false;
            }

            await _settingsStore.SaveAsync(settings, cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool TryGetPrefString(JsonElement root, string key, out string value)
    {
        value = string.Empty;
        if (!root.TryGetProperty(key, out var prop))
        {
            return false;
        }

        if (prop.ValueKind == JsonValueKind.String)
        {
            value = prop.GetString() ?? string.Empty;
            return !string.IsNullOrWhiteSpace(value);
        }

        return false;
    }

    private static IEnumerable<string> DiscoverFlutterDocumentRoots()
    {
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var roots = new[]
        {
            Path.Combine(local, "com.chloemlla.nexai"),
            Path.Combine(local, "NexAI"),
            Path.Combine(roaming, "com.chloemlla.nexai"),
            Path.Combine(roaming, "NexAI"),
        };

        foreach (var root in roots.Where(Directory.Exists))
        {
            yield return root;
            foreach (var child in Directory.EnumerateDirectories(root))
            {
                yield return child;
            }
        }
    }

    private static IEnumerable<string> DiscoverSharedPreferencesFiles()
    {
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var candidates = new List<string>();
        foreach (var root in new[]
                 {
                     Path.Combine(local, "com.chloemlla.nexai"),
                     Path.Combine(local, "NexAI"),
                     Path.Combine(roaming, "com.chloemlla.nexai"),
                     Path.Combine(roaming, "NexAI"),
                 }.Where(Directory.Exists))
        {
            candidates.AddRange(Directory.EnumerateFiles(root, "*.json", SearchOption.AllDirectories)
                .Where(p => p.Contains("shared_preferences", StringComparison.OrdinalIgnoreCase) ||
                            p.EndsWith("flutter_shared_preferences.json", StringComparison.OrdinalIgnoreCase)));
        }

        return candidates;
    }

    private static async Task WriteMarkerAsync(string detail, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.Serialize(new
        {
            completedAt = DateTime.UtcNow.ToString("O"),
            detail,
        });
        await File.WriteAllTextAsync(AppPaths.MigrationMarkerPath, payload, cancellationToken).ConfigureAwait(false);
    }
}
