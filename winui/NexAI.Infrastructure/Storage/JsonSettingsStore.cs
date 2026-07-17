using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Settings;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonSettingsStore : ISettingsStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private AppSettings _current = new();

    public AppSettings Current
    {
        get
        {
            lock (_gate)
            {
                return _current.Clone();
            }
        }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        var path = AppPaths.SettingsFilePath;
        if (!File.Exists(path))
        {
            await SaveAsync(new AppSettings(), cancellationToken).ConfigureAwait(false);
            return;
        }

        await using var stream = File.OpenRead(path);
        var loaded = await JsonSerializer
            .DeserializeAsync<AppSettings>(stream, SerializerOptions, cancellationToken)
            .ConfigureAwait(false);

        lock (_gate)
        {
            _current = AppSettingsValidator.Normalize(loaded ?? new AppSettings());
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(settings);

        var snapshot = AppSettingsValidator.Normalize(settings);
        var error = AppSettingsValidator.Validate(snapshot);
        if (error is not null)
        {
            throw new InvalidOperationException(error);
        }

        AppPaths.EnsureRoot();
        var path = AppPaths.SettingsFilePath;
        var tempPath = path + ".tmp";

        await using (var stream = File.Create(tempPath))
        {
            await JsonSerializer
                .SerializeAsync(stream, snapshot, SerializerOptions, cancellationToken)
                .ConfigureAwait(false);
        }

        File.Copy(tempPath, path, overwrite: true);
        File.Delete(tempPath);

        lock (_gate)
        {
            _current = snapshot;
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }
}
