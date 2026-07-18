using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Tools;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonShortUrlHistoryStore : IShortUrlHistoryStore
{
    private const int MaxItems = 100;
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private List<ShortUrlRecord> _history = [];

    public IReadOnlyList<ShortUrlRecord> History
    {
        get { lock (_gate) { return _history.Select(x => x.Clone()).ToList(); } }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(AppPaths.ShortUrlHistoryFilePath))
        {
            lock (_gate) { _history = []; }
            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        await using var stream = File.OpenRead(AppPaths.ShortUrlHistoryFilePath);
        var loaded = await JsonSerializer.DeserializeAsync<List<ShortUrlRecord>>(stream, Options, cancellationToken)
            .ConfigureAwait(false);
        lock (_gate)
        {
            _history = (loaded ?? []).Select(x => x.Clone()).OrderByDescending(x => x.CreatedAt).Take(MaxItems).ToList();
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task AddAsync(ShortUrlRecord record, CancellationToken cancellationToken = default)
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
        List<ShortUrlRecord> snapshot;
        lock (_gate) { snapshot = _history.Select(x => x.Clone()).ToList(); }
        AppPaths.EnsureRoot();
        var temp = AppPaths.ShortUrlHistoryFilePath + ".tmp";
        await using (var stream = File.Create(temp))
        {
            await JsonSerializer.SerializeAsync(stream, snapshot, Options, cancellationToken).ConfigureAwait(false);
        }

        File.Copy(temp, AppPaths.ShortUrlHistoryFilePath, true);
        File.Delete(temp);
    }
}
