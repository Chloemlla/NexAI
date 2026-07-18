using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using NexAI.Core;

namespace NexAI.Infrastructure.Security;

public sealed class NexaiCertPin
{
    public string Sha256Hex { get; init; } = string.Empty;
    public DateTimeOffset? ExpiresAt { get; init; }
}

public interface INexaiCertPinStore
{
    Task<NexaiCertPin?> GetAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(X509Certificate2 certificate, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
}

public sealed class NexaiCertPinStore : INexaiCertPinStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private static string FilePath => Path.Combine(AppPaths.RootDirectory, "cert-pin.dpapi.json");

    public async Task<NexaiCertPin?> GetAsync(CancellationToken cancellationToken = default)
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
            var pin = JsonSerializer.Deserialize<NexaiCertPin>(json, Options);
            if (pin is null || string.IsNullOrWhiteSpace(pin.Sha256Hex))
            {
                return null;
            }

            if (pin.ExpiresAt is not null && pin.ExpiresAt <= DateTimeOffset.UtcNow)
            {
                await ClearAsync(cancellationToken).ConfigureAwait(false);
                return null;
            }

            return pin;
        }
        catch
        {
            return null;
        }
    }

    public async Task SaveAsync(X509Certificate2 certificate, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(certificate);
        var pin = new NexaiCertPin
        {
            Sha256Hex = Sha256Hex(certificate),
            ExpiresAt = certificate.NotAfter.ToUniversalTime(),
        };

        AppPaths.EnsureRoot();
        var protectedValue = SecretProtector.Protect(JsonSerializer.Serialize(pin, Options));
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

    public static string Sha256Hex(X509Certificate2 certificate)
    {
        var hash = SHA256.HashData(certificate.RawData);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
