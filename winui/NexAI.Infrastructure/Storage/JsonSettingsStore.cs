using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Settings;
using NexAI.Infrastructure.Security;

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
            _current = AppSettingsValidator.Normalize(UnprotectSecrets(loaded ?? new AppSettings()));
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
        var toPersist = ProtectSecrets(snapshot);

        await using (var stream = File.Create(tempPath))
        {
            await JsonSerializer
                .SerializeAsync(stream, toPersist, SerializerOptions, cancellationToken)
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

    private static AppSettings ProtectSecrets(AppSettings settings)
    {
        var protectedCopy = settings.Clone();
        protectedCopy.ApiKey = SecretProtector.Protect(protectedCopy.ApiKey);
        protectedCopy.VertexApiKey = SecretProtector.Protect(protectedCopy.VertexApiKey);
        protectedCopy.WebDavPassword = SecretProtector.Protect(protectedCopy.WebDavPassword);
        protectedCopy.UpstashToken = SecretProtector.Protect(protectedCopy.UpstashToken);
        return protectedCopy;
    }

    private static AppSettings UnprotectSecrets(AppSettings settings)
    {
        var plain = settings.Clone();
        plain.ApiKey = SecretProtector.Unprotect(plain.ApiKey);
        plain.VertexApiKey = SecretProtector.Unprotect(plain.VertexApiKey);
        plain.WebDavPassword = SecretProtector.Unprotect(plain.WebDavPassword);
        plain.UpstashToken = SecretProtector.Unprotect(plain.UpstashToken);
        return plain;
    }
}
