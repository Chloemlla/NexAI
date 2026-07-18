using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using NexAI.Core;
using NexAI.Core.Sync;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Sync;

public sealed class AesGcmSyncCrypto : ISyncCrypto
{
    private const string Algorithm = "AES-256-GCM";
    private const string KeyId = "local-secure-storage-v1";

    public async Task<string> ExportRecoveryKeyAsync(CancellationToken cancellationToken = default)
    {
        var key = await GetOrCreateKeyAsync(cancellationToken).ConfigureAwait(false);
        return Base64UrlEncode(key);
    }

    public async Task ImportRecoveryKeyAsync(string encoded, CancellationToken cancellationToken = default)
    {
        var bytes = Base64UrlDecode(encoded.Trim());
        if (bytes.Length != 32)
        {
            throw new FormatException("Sync recovery key must decode to 32 bytes.");
        }

        AppPaths.EnsureRoot();
        await PersistKeyAsync(bytes, cancellationToken).ConfigureAwait(false);
    }

    public async Task<Dictionary<string, object?>> EncryptRecordAsync(
        string id,
        string category,
        string updatedAt,
        Dictionary<string, object?> payload,
        CancellationToken cancellationToken = default)
    {
        var key = await GetOrCreateKeyAsync(cancellationToken).ConfigureAwait(false);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var aad = Encoding.UTF8.GetBytes($"{category}:{id}:{updatedAt}");
        var plaintext = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload));
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];

        using var aes = new AesGcm(key, 16);
        aes.Encrypt(nonce, plaintext, ciphertext, tag, aad);

        var packed = new byte[ciphertext.Length + tag.Length];
        Buffer.BlockCopy(ciphertext, 0, packed, 0, ciphertext.Length);
        Buffer.BlockCopy(tag, 0, packed, ciphertext.Length, tag.Length);

        return new Dictionary<string, object?>
        {
            ["id"] = id,
            ["category"] = category,
            ["updatedAt"] = updatedAt,
            ["deleted"] = false,
            ["crypto"] = new Dictionary<string, object?>
            {
                ["alg"] = Algorithm,
                ["kdf"] = "none",
                ["keyId"] = KeyId,
                ["nonce"] = Base64UrlEncode(nonce),
                ["aad"] = Base64UrlEncode(aad),
                ["ciphertext"] = Base64UrlEncode(packed),
            },
        };
    }

    public async Task<Dictionary<string, object?>?> DecryptRecordAsync(
        Dictionary<string, object?> record,
        CancellationToken cancellationToken = default)
    {
        if (!record.TryGetValue("crypto", out var cryptoObj))
        {
            return null;
        }

        var crypto = ToDict(cryptoObj);
        if (crypto is null)
        {
            return null;
        }

        if (!string.Equals(GetString(crypto, "alg"), Algorithm, StringComparison.Ordinal))
        {
            return null;
        }

        var key = await GetOrCreateKeyAsync(cancellationToken).ConfigureAwait(false);
        var nonce = Base64UrlDecode(GetString(crypto, "nonce") ?? string.Empty);
        var packed = Base64UrlDecode(GetString(crypto, "ciphertext") ?? string.Empty);
        if (packed.Length <= 16)
        {
            return null;
        }

        var ciphertext = packed[..^16];
        var tag = packed[^16..];
        byte[] aad;
        var aadValue = GetString(crypto, "aad");
        if (!string.IsNullOrWhiteSpace(aadValue))
        {
            aad = Base64UrlDecode(aadValue);
        }
        else
        {
            aad = Encoding.UTF8.GetBytes($"{GetString(record, "category")}:{GetString(record, "id")}:{GetString(record, "updatedAt")}");
        }

        var plaintext = new byte[ciphertext.Length];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(nonce, ciphertext, tag, plaintext, aad);
        return JsonSerializer.Deserialize<Dictionary<string, object?>>(Encoding.UTF8.GetString(plaintext));
    }

    private static async Task<byte[]> GetOrCreateKeyAsync(CancellationToken cancellationToken)
    {
        AppPaths.EnsureRoot();
        if (File.Exists(AppPaths.SyncKeyFilePath))
        {
            var existing = (await File.ReadAllTextAsync(AppPaths.SyncKeyFilePath, cancellationToken).ConfigureAwait(false)).Trim();
            if (!string.IsNullOrWhiteSpace(existing))
            {
                try
                {
                    if (SecretProtector.IsProtected(existing))
                    {
                        return SecretProtector.UnprotectBytes(
                            Convert.FromBase64String(existing["dpapi:".Length..]));
                    }

                    var legacy = Base64UrlDecode(existing);
                    await PersistKeyAsync(legacy, cancellationToken).ConfigureAwait(false);
                    return legacy;
                }
                catch
                {
                    // Fall through and create a new key.
                }
            }
        }

        var key = RandomNumberGenerator.GetBytes(32);
        await PersistKeyAsync(key, cancellationToken).ConfigureAwait(false);
        return key;
    }

    private static async Task PersistKeyAsync(byte[] key, CancellationToken cancellationToken)
    {
        var protectedBytes = SecretProtector.ProtectBytes(key);
        await File.WriteAllTextAsync(
                AppPaths.SyncKeyFilePath,
                "dpapi:" + Convert.ToBase64String(protectedBytes),
                cancellationToken)
            .ConfigureAwait(false);
    }

    private static string Base64UrlEncode(byte[] bytes)
        => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] Base64UrlDecode(string value)
    {
        var padded = value.Replace('-', '+').Replace('_', '/');
        switch (padded.Length % 4)
        {
            case 2: padded += "=="; break;
            case 3: padded += "="; break;
        }
        return Convert.FromBase64String(padded);
    }

    private static Dictionary<string, object?>? ToDict(object? value)
    {
        if (value is Dictionary<string, object?> dict)
        {
            return dict;
        }

        if (value is JsonElement element && element.ValueKind == JsonValueKind.Object)
        {
            var result = new Dictionary<string, object?>();
            foreach (var prop in element.EnumerateObject())
            {
                result[prop.Name] = prop.Value.ValueKind switch
                {
                    JsonValueKind.String => prop.Value.GetString(),
                    JsonValueKind.Number => prop.Value.TryGetInt64(out var l) ? l : prop.Value.GetDouble(),
                    JsonValueKind.True => true,
                    JsonValueKind.False => false,
                    JsonValueKind.Object => ToDict(prop.Value),
                    JsonValueKind.Array => prop.Value.EnumerateArray().Select(x => (object?)x.ToString()).ToList(),
                    _ => prop.Value.ToString(),
                };
            }
            return result;
        }

        return null;
    }

    private static string? GetString(Dictionary<string, object?> map, string key)
        => map.TryGetValue(key, out var value) ? value?.ToString() : null;
}
