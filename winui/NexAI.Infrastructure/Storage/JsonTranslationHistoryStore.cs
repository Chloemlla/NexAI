using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Tools;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonTranslationHistoryStore : ITranslationHistoryStore
{
    private const int MaxItems = 200;
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private List<TranslationRecord> _history = [];

    public IReadOnlyList<TranslationRecord> History
    {
        get { lock (_gate) { return _history.Select(x => x.Clone()).ToList(); } }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(AppPaths.TranslationHistoryFilePath))
        {
            lock (_gate) { _history = []; }
            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        var loaded = await ReadProtectedListAsync<TranslationRecord>(
            AppPaths.TranslationHistoryFilePath,
            cancellationToken).ConfigureAwait(false);
        lock (_gate)
        {
            _history = loaded.Select(x => x.Clone()).OrderByDescending(x => x.CreatedAt).Take(MaxItems).ToList();
        }

        // Re-persist if we loaded legacy plaintext so the file is upgraded at rest.
        if (loaded.Count > 0 && !await IsProtectedFileAsync(AppPaths.TranslationHistoryFilePath, cancellationToken).ConfigureAwait(false))
        {
            await PersistAsync(cancellationToken).ConfigureAwait(false);
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task AddAsync(TranslationRecord record, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(record);
        lock (_gate)
        {
            _history.Insert(0, record.Clone());
            if (_history.Count > MaxItems)
            {
                _history = _history.Take(MaxItems).ToList();
            }
        }

        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task DeleteAsync(string id, CancellationToken cancellationToken = default)
    {
        lock (_gate) { _history.RemoveAll(x => x.Id == id); }
        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ClearAsync(CancellationToken cancellationToken = default)
    {
        lock (_gate) { _history = []; }
        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private async Task PersistAsync(CancellationToken cancellationToken)
    {
        List<TranslationRecord> snapshot;
        lock (_gate) { snapshot = _history.Select(x => x.Clone()).ToList(); }
        await WriteProtectedListAsync(AppPaths.TranslationHistoryFilePath, snapshot, cancellationToken)
            .ConfigureAwait(false);
    }

    internal static async Task<List<T>> ReadProtectedListAsync<T>(string path, CancellationToken cancellationToken)
    {
        var raw = await File.ReadAllTextAsync(path, cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrWhiteSpace(raw))
        {
            return [];
        }

        string json;
        if (SecretProtector.IsProtected(raw.Trim()))
        {
            json = SecretProtector.Unprotect(raw.Trim());
        }
        else
        {
            // Backward compatible legacy plaintext JSON array.
            json = raw;
        }

        return JsonSerializer.Deserialize<List<T>>(json, Options) ?? [];
    }

    internal static async Task WriteProtectedListAsync<T>(string path, List<T> snapshot, CancellationToken cancellationToken)
    {
        AppPaths.EnsureRoot();
        var json = JsonSerializer.Serialize(snapshot, Options);
        var protectedPayload = SecretProtector.Protect(json);
        var temp = path + ".tmp";
        await File.WriteAllTextAsync(temp, protectedPayload, Encoding.UTF8, cancellationToken).ConfigureAwait(false);
        File.Copy(temp, path, true);
        File.Delete(temp);
    }

    private static async Task<bool> IsProtectedFileAsync(string path, CancellationToken cancellationToken)
    {
        var raw = (await File.ReadAllTextAsync(path, cancellationToken).ConfigureAwait(false)).Trim();
        return SecretProtector.IsProtected(raw);
    }
}
