using System.Text;
using System.Text.Json;
using NexAI.Core.Auth;
using NexAI.Core.Chat;
using NexAI.Core.Notes;
using NexAI.Core.Settings;
using NexAI.Core.Sync;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Sync;

public sealed class NexaiSyncService : ISyncService
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly ISettingsStore _settingsStore;
    private readonly IAuthSessionStore _authStore;
    private readonly IConversationStore _conversationStore;
    private readonly INotesStore _notesStore;
    private readonly ISyncCrypto _syncCrypto;
    private readonly INexaiHttp _http;
    private SyncState _state = new();

    public NexaiSyncService(
        ISettingsStore settingsStore,
        IAuthSessionStore authStore,
        IConversationStore conversationStore,
        INotesStore notesStore,
        ISyncCrypto syncCrypto,
        INexaiHttp http)
    {
        _settingsStore = settingsStore;
        _authStore = authStore;
        _conversationStore = conversationStore;
        _notesStore = notesStore;
        _syncCrypto = syncCrypto;
        _http = http;
    }

    public SyncState State => new()
    {
        Status = _state.Status,
        ErrorMessage = _state.ErrorMessage,
        LastSyncedAt = _state.LastSyncedAt,
        RecoveryKeyHint = _state.RecoveryKeyHint,
    };

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var key = await _syncCrypto.ExportRecoveryKeyAsync(cancellationToken).ConfigureAwait(false);
            _state.RecoveryKeyHint = key.Length <= 12 ? key : key[..8] + "…" + key[^4..];
        }
        catch
        {
            _state.RecoveryKeyHint = null;
        }

        RaiseChanged();
    }

    public Task<string> ExportRecoveryKeyAsync(CancellationToken cancellationToken = default)
        => _syncCrypto.ExportRecoveryKeyAsync(cancellationToken);

    public async Task ImportRecoveryKeyAsync(string encoded, CancellationToken cancellationToken = default)
    {
        await _syncCrypto.ImportRecoveryKeyAsync(encoded, cancellationToken).ConfigureAwait(false);
        await LoadAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<bool> UploadAsync(CancellationToken cancellationToken = default)
    {
        var auth = _authStore.Current;
        if (!auth.IsAuthenticated)
        {
            return Fail("Please sign in before syncing.");
        }

        _state.Status = SyncStatus.Uploading;
        _state.ErrorMessage = null;
        RaiseChanged();

        try
        {
            var settings = _settingsStore.Current;
            if (settings.SyncMethod != SyncBackendKind.NexAI)
            {
                return Fail($"Sync backend '{settings.SyncMethod}' is configured, but only NexAI /sync/v2 is implemented in WinUI.");
            }

            var snapshot = await BuildSnapshotAsync(cancellationToken).ConfigureAwait(false);
            var url = Combine(settings.BackendBaseUrl, "/sync/v2");
            using var response = await _http.SendAsync(
                    HttpMethod.Put,
                    url,
                    bearerToken: auth.AccessToken,
                    jsonBody: snapshot,
                    requireSignature: true,
                    cancellationToken: cancellationToken)
                .ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode || !IsSuccessBody(body))
            {
                return Fail($"Upload failed: HTTP {(int)response.StatusCode}");
            }

            _state.Status = SyncStatus.Success;
            _state.LastSyncedAt = DateTime.UtcNow;
            RaiseChanged();
            return true;
        }
        catch (Exception ex)
        {
            return Fail(ex.Message);
        }
    }

    public async Task<bool> DownloadAsync(CancellationToken cancellationToken = default)
    {
        var auth = _authStore.Current;
        if (!auth.IsAuthenticated)
        {
            return Fail("Please sign in before syncing.");
        }

        _state.Status = SyncStatus.Downloading;
        _state.ErrorMessage = null;
        RaiseChanged();

        try
        {
            var settings = _settingsStore.Current;
            if (settings.SyncMethod != SyncBackendKind.NexAI)
            {
                return Fail($"Sync backend '{settings.SyncMethod}' is configured, but only NexAI /sync/v2 is implemented in WinUI.");
            }

            var url = Combine(settings.BackendBaseUrl, "/sync/v2");
            using var response = await _http.SendAsync(
                    HttpMethod.Get,
                    url,
                    bearerToken: auth.AccessToken,
                    requireSignature: true,
                    cancellationToken: cancellationToken)
                .ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                return Fail($"Download failed: HTTP {(int)response.StatusCode}");
            }

            using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
            if (!doc.RootElement.TryGetProperty("success", out var success) || success.ValueKind != JsonValueKind.True)
            {
                return Fail("Cloud has no sync data.");
            }

            if (!doc.RootElement.TryGetProperty("data", out var data) || data.ValueKind != JsonValueKind.Object)
            {
                return Fail("Cloud sync payload is empty.");
            }

            await RestoreSnapshotAsync(data, cancellationToken).ConfigureAwait(false);
            _state.Status = SyncStatus.Success;
            _state.LastSyncedAt = DateTime.UtcNow;
            RaiseChanged();
            return true;
        }
        catch (Exception ex)
        {
            return Fail(ex.Message);
        }
    }

    private async Task<Dictionary<string, object?>> BuildSnapshotAsync(CancellationToken cancellationToken)
    {
        var snapshotTime = DateTime.UtcNow.ToString("O");
        var records = new List<Dictionary<string, object?>>();
        var settings = _settingsStore.Current;

        records.Add(await _syncCrypto.EncryptRecordAsync(
            "settings",
            "settings",
            snapshotTime,
            new Dictionary<string, object?>
            {
                ["baseUrl"] = settings.BaseUrl,
                ["selectedModel"] = settings.SelectedModel,
                ["themeMode"] = settings.ThemeMode.ToString().ToLowerInvariant(),
                ["temperature"] = settings.Temperature,
                ["maxTokens"] = settings.MaxTokens,
                ["systemPrompt"] = settings.SystemPrompt,
                ["syncEnabled"] = settings.SyncEnabled,
                ["syncMethod"] = settings.SyncMethod.ToString(),
                ["webdavServer"] = settings.WebDavServer,
                ["webdavUser"] = settings.WebDavUser,
                ["upstashUrl"] = settings.UpstashUrl,
                ["notesAutoSave"] = settings.NotesAutoSave,
            },
            cancellationToken).ConfigureAwait(false));

        foreach (var note in _notesStore.Notes)
        {
            records.Add(await _syncCrypto.EncryptRecordAsync(
                note.Id,
                "notes",
                note.UpdatedAt.ToUniversalTime().ToString("O"),
                note.ToJsonMap(),
                cancellationToken).ConfigureAwait(false));
        }

        foreach (var conversation in _conversationStore.Conversations)
        {
            var updatedAt = conversation.Messages.LastOrDefault()?.Timestamp ?? conversation.UpdatedAt;
            records.Add(await _syncCrypto.EncryptRecordAsync(
                conversation.Id,
                "conversations",
                updatedAt.ToUniversalTime().ToString("O"),
                new Dictionary<string, object?>
                {
                    ["id"] = conversation.Id,
                    ["title"] = conversation.Title,
                    ["createdAt"] = conversation.CreatedAt.ToString("O"),
                    ["messages"] = conversation.Messages.Select(m => new Dictionary<string, object?>
                    {
                        ["role"] = m.Role,
                        ["content"] = m.Content,
                        ["timestamp"] = m.Timestamp.ToString("O"),
                        ["isError"] = m.IsError,
                    }).ToList(),
                },
                cancellationToken).ConfigureAwait(false));
        }

        return new Dictionary<string, object?>
        {
            ["schemaVersion"] = 2,
            ["deviceId"] = Environment.MachineName,
            ["snapshotId"] = "snap_" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            ["updatedAt"] = snapshotTime,
            ["records"] = records,
        };
    }

    private async Task RestoreSnapshotAsync(JsonElement data, CancellationToken cancellationToken)
    {
        if (!data.TryGetProperty("records", out var records) || records.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException("Cloud sync data format invalid: records is not a list.");
        }

        var notes = new List<Note>();
        var conversations = new List<Conversation>();
        Dictionary<string, object?>? settingsPayload = null;

        foreach (var item in records.EnumerateArray())
        {
            var record = JsonSerializer.Deserialize<Dictionary<string, object?>>(item.GetRawText())
                ?? throw new InvalidOperationException("Invalid sync record.");
            if (record.TryGetValue("deleted", out var deleted) && deleted is true or "true")
            {
                continue;
            }

            var payload = await _syncCrypto.DecryptRecordAsync(record, cancellationToken).ConfigureAwait(false)
                ?? throw new InvalidOperationException("Unable to decrypt a cloud record.");

            var category = record.TryGetValue("category", out var cat) ? cat?.ToString() : null;
            switch (category)
            {
                case "settings":
                    settingsPayload = payload;
                    break;
                case "notes":
                    notes.Add(Note.FromJsonMap(payload));
                    break;
                case "conversations":
                    conversations.Add(ParseConversation(payload));
                    break;
            }
        }

        if (settingsPayload is not null)
        {
            var current = _settingsStore.Current;
            if (settingsPayload.TryGetValue("baseUrl", out var baseUrl) && baseUrl is not null)
            {
                current.BaseUrl = baseUrl.ToString() ?? current.BaseUrl;
            }
            if (settingsPayload.TryGetValue("selectedModel", out var model) && model is not null)
            {
                current.SelectedModel = model.ToString() ?? current.SelectedModel;
            }
            if (settingsPayload.TryGetValue("temperature", out var temp) && double.TryParse(temp?.ToString(), out var t))
            {
                current.Temperature = t;
            }
            if (settingsPayload.TryGetValue("maxTokens", out var mt) && int.TryParse(mt?.ToString(), out var maxTokens))
            {
                current.MaxTokens = maxTokens;
            }
            if (settingsPayload.TryGetValue("systemPrompt", out var sp) && sp is not null)
            {
                current.SystemPrompt = sp.ToString() ?? current.SystemPrompt;
            }
            await _settingsStore.SaveAsync(current, cancellationToken).ConfigureAwait(false);
        }

        await _notesStore.ReplaceAllAsync(notes, cancellationToken).ConfigureAwait(false);

        // Atomic conversation replace preserves ids and avoids multi-step delete/create races.
        var ordered = conversations
            .Select(c =>
            {
                var clone = c.Clone();
                if (clone.UpdatedAt == default)
                {
                    clone.UpdatedAt = clone.Messages.LastOrDefault()?.Timestamp ?? clone.CreatedAt;
                }
                return clone;
            })
            .OrderByDescending(c => c.UpdatedAt)
            .ToList();
        await _conversationStore.ReplaceAllAsync(
            ordered,
            currentConversationId: ordered.FirstOrDefault()?.Id,
            cancellationToken).ConfigureAwait(false);
    }

    private static Conversation ParseConversation(Dictionary<string, object?> payload)
    {
        var conversation = new Conversation
        {
            Id = payload.GetValueOrDefault("id")?.ToString() ?? Guid.NewGuid().ToString("D"),
            Title = payload.GetValueOrDefault("title")?.ToString() ?? "New chat",
            CreatedAt = DateTime.TryParse(payload.GetValueOrDefault("createdAt")?.ToString(), out var created)
                ? created.ToUniversalTime()
                : DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Messages = [],
        };

        if (payload.TryGetValue("messages", out var messagesObj) && messagesObj is JsonElement element && element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
            {
                conversation.Messages.Add(new ChatMessage
                {
                    Role = item.TryGetProperty("role", out var role) ? role.GetString() ?? ChatRoles.User : ChatRoles.User,
                    Content = item.TryGetProperty("content", out var content) ? content.GetString() ?? string.Empty : string.Empty,
                    Timestamp = item.TryGetProperty("timestamp", out var ts) && DateTime.TryParse(ts.GetString(), out var parsed)
                        ? parsed.ToUniversalTime()
                        : DateTime.UtcNow,
                    IsError = item.TryGetProperty("isError", out var err) && err.ValueKind == JsonValueKind.True,
                });
            }
        }

        conversation.UpdatedAt = conversation.Messages.LastOrDefault()?.Timestamp ?? conversation.CreatedAt;
        return conversation;
    }

    private static bool IsSuccessBody(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
            return doc.RootElement.TryGetProperty("success", out var success) && success.ValueKind == JsonValueKind.True;
        }
        catch
        {
            return false;
        }
    }

    private static string Combine(string baseUrl, string path)
        => (baseUrl?.Trim().TrimEnd('/') ?? string.Empty) + path;

    private bool Fail(string message)
    {
        _state.Status = SyncStatus.Error;
        _state.ErrorMessage = message;
        RaiseChanged();
        return false;
    }

    private void RaiseChanged() => Changed?.Invoke(this, EventArgs.Empty);
}
