using System.Text.Json;
using NexAI.Core;

namespace NexAI.Infrastructure.Security;

/// <summary>
/// Optional short-lived / device-bound signing key issued by backend.
/// Backend may return this from future `/security/track` or dedicated endpoint.
/// Falls back to accessToken / NEXAI_APP_SIGN_SECRET when absent.
/// </summary>
public sealed class NexaiSigningKeyMaterial
{
    public string Key { get; init; } = string.Empty;
    public string KeyId { get; init; } = "device";
    public DateTimeOffset? ExpiresAt { get; init; }

    public bool IsUsable =>
        !string.IsNullOrWhiteSpace(Key) &&
        (ExpiresAt is null || ExpiresAt > DateTimeOffset.UtcNow.AddMinutes(1));
}

public interface INexaiSigningKeyStore
{
    Task<NexaiSigningKeyMaterial?> GetAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(NexaiSigningKeyMaterial material, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
}

public sealed class NexaiSigningKeyStore : INexaiSigningKeyStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private static string FilePath => Path.Combine(AppPaths.RootDirectory, "signing-key.dpapi.json");

    public async Task<NexaiSigningKeyMaterial?> GetAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(FilePath))
        {
            return null;
        }

        try
        {
            var stored = (await File.ReadAllTextAsync(FilePath, cancellationToken).ConfigureAwait(false)).Trim();
            var json = SecretProtector.Unprotect(stored);
            var material = JsonSerializer.Deserialize<NexaiSigningKeyMaterial>(json, Options);
            return material is { IsUsable: true } ? material : null;
        }
        catch
        {
            return null;
        }
    }

    public async Task SaveAsync(NexaiSigningKeyMaterial material, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(material);
        if (!material.IsUsable)
        {
            await ClearAsync(cancellationToken).ConfigureAwait(false);
            return;
        }

        AppPaths.EnsureRoot();
        var json = JsonSerializer.Serialize(material, Options);
        var protectedValue = SecretProtector.Protect(json);
        var temp = FilePath + ".tmp";
        await File.WriteAllTextAsync(temp, protectedValue, cancellationToken).ConfigureAwait(false);
        File.Copy(temp, FilePath, true);
        File.Delete(temp);
    }

    public Task ClearAsync(CancellationToken cancellationToken = default)
    {
        if (File.Exists(FilePath))
        {
            File.Delete(FilePath);
        }

        return Task.CompletedTask;
    }
}
