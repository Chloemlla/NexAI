using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NexAI.Core.Tools;

public sealed class PasswordBackupException : Exception
{
    public PasswordBackupException(string message) : base(message)
    {
    }
}

public static class PasswordBackupCrypto
{
    public const string EncryptedBackupFormat = "nexai-password-backup-v2";
    public const string EncryptedBackupVersion = "2.0";
    public const int DefaultIterations = 120_000;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    public static string CreateBackup(IEnumerable<SavedPassword> passwords, string passphrase, int iterations = DefaultIterations)
    {
        ArgumentNullException.ThrowIfNull(passwords);
        var normalized = (passphrase ?? string.Empty).Trim();
        if (normalized.Length < 8)
        {
            throw new PasswordBackupException("Backup passphrase must be at least 8 characters.");
        }

        iterations = Math.Max(10_000, iterations);
        var payload = new Dictionary<string, object?>
        {
            ["version"] = "1.0",
            ["timestamp"] = DateTime.UtcNow.ToString("O"),
            ["passwords"] = passwords.Select(p => p.ToDictionary()).ToList(),
        };

        var plaintext = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload, JsonOptions));
        var salt = RandomNumberGenerator.GetBytes(16);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var key = DeriveKey(normalized, salt, iterations);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];
        using (var aes = new AesGcm(key, 16))
        {
            aes.Encrypt(nonce, plaintext, ciphertext, tag);
        }

        var packed = new byte[ciphertext.Length + tag.Length];
        Buffer.BlockCopy(ciphertext, 0, packed, 0, ciphertext.Length);
        Buffer.BlockCopy(tag, 0, packed, ciphertext.Length, tag.Length);

        var backup = new Dictionary<string, object?>
        {
            ["version"] = EncryptedBackupVersion,
            ["format"] = EncryptedBackupFormat,
            ["timestamp"] = DateTime.UtcNow.ToString("O"),
            ["crypto"] = new Dictionary<string, object?>
            {
                ["alg"] = "AES-256-GCM",
                ["kdf"] = "PBKDF2-HMAC-SHA256",
                ["iterations"] = iterations,
                ["salt"] = Base64UrlEncode(salt),
                ["nonce"] = Base64UrlEncode(nonce),
                ["ciphertext"] = Base64UrlEncode(packed),
            },
        };

        return JsonSerializer.Serialize(backup, JsonOptions);
    }

    public static IReadOnlyList<SavedPassword> RestoreBackup(string backupJson, string? passphrase = null)
    {
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(backupJson) ? "{}" : backupJson);
        var root = doc.RootElement;

        var format = root.TryGetProperty("format", out var formatEl) ? formatEl.GetString() : null;
        var version = root.TryGetProperty("version", out var versionEl) ? versionEl.GetString() : null;
        if (string.Equals(format, EncryptedBackupFormat, StringComparison.Ordinal) ||
            string.Equals(version, EncryptedBackupVersion, StringComparison.Ordinal))
        {
            var normalized = (passphrase ?? string.Empty).Trim();
            if (normalized.Length < 8)
            {
                throw new PasswordBackupException("Enter the backup passphrase (at least 8 characters).");
            }

            return DecryptV2(root, normalized).Select(SavedPassword.FromDictionary).ToList();
        }

        // Legacy v1 is plaintext + checksum only (no confidentiality).
        // Keep parser available for an explicit UI confirmation path.
        if (!IsLegacyV1(root))
        {
            throw new PasswordBackupException("Unsupported or invalid password backup.");
        }

        throw new PasswordBackupException(
            "This is a legacy plaintext backup (v1). Confirm import explicitly before restoring.");
    }

    private static List<Dictionary<string, object?>> DecryptV2(JsonElement root, string passphrase)
    {
        if (!root.TryGetProperty("crypto", out var crypto) || crypto.ValueKind != JsonValueKind.Object)
        {
            throw new PasswordBackupException("Backup is missing crypto fields.");
        }

        var alg = crypto.TryGetProperty("alg", out var algEl) ? algEl.GetString() : null;
        var kdf = crypto.TryGetProperty("kdf", out var kdfEl) ? kdfEl.GetString() : null;
        if (!string.Equals(alg, "AES-256-GCM", StringComparison.Ordinal) ||
            !string.Equals(kdf, "PBKDF2-HMAC-SHA256", StringComparison.Ordinal))
        {
            throw new PasswordBackupException("Unsupported backup crypto algorithm.");
        }

        if (!crypto.TryGetProperty("iterations", out var iterEl) ||
            !iterEl.TryGetInt32(out var iterations) ||
            iterations < 10_000)
        {
            throw new PasswordBackupException("Invalid backup KDF parameters.");
        }

        var salt = Base64UrlDecode(crypto.TryGetProperty("salt", out var saltEl) ? saltEl.GetString() ?? string.Empty : string.Empty);
        var nonce = Base64UrlDecode(crypto.TryGetProperty("nonce", out var nonceEl) ? nonceEl.GetString() ?? string.Empty : string.Empty);
        var packed = Base64UrlDecode(crypto.TryGetProperty("ciphertext", out var ctEl) ? ctEl.GetString() ?? string.Empty : string.Empty);
        if (salt.Length == 0 || nonce.Length == 0 || packed.Length <= 16)
        {
            throw new PasswordBackupException("Backup ciphertext is incomplete.");
        }

        try
        {
            var key = DeriveKey(passphrase, salt, iterations);
            var ciphertext = packed[..^16];
            var tag = packed[^16..];
            var plaintext = new byte[ciphertext.Length];
            using (var aes = new AesGcm(key, 16))
            {
                aes.Decrypt(nonce, ciphertext, tag, plaintext);
            }

            using var payloadDoc = JsonDocument.Parse(Encoding.UTF8.GetString(plaintext));
            if (!payloadDoc.RootElement.TryGetProperty("passwords", out var passwords) ||
                passwords.ValueKind != JsonValueKind.Array)
            {
                throw new PasswordBackupException("Decrypted backup is missing the password list.");
            }

            var list = new List<Dictionary<string, object?>>();
            foreach (var item in passwords.EnumerateArray())
            {
                list.Add(SavedPassword.ToDictionary(item));
            }

            return list;
        }
        catch (PasswordBackupException)
        {
            throw;
        }
        catch
        {
            throw new PasswordBackupException("Wrong passphrase or corrupted backup.");
        }
    }


    public static bool IsLegacyPlaintextBackup(string backupJson)
    {
        try
        {
            using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(backupJson) ? "{}" : backupJson);
            return IsLegacyV1(doc.RootElement);
        }
        catch
        {
            return false;
        }
    }

    public static IReadOnlyList<SavedPassword> RestoreLegacyPlaintextBackup(string backupJson)
    {
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(backupJson) ? "{}" : backupJson);
        var root = doc.RootElement;
        if (!IsLegacyV1(root))
        {
            throw new PasswordBackupException("Not a legacy plaintext backup.");
        }

        if (!root.TryGetProperty("checksum", out var checksumEl) ||
            !root.TryGetProperty("passwords", out var passwordsEl) ||
            passwordsEl.ValueKind != JsonValueKind.Array)
        {
            throw new PasswordBackupException("Unsupported or invalid password backup.");
        }

        var passwordsJson = passwordsEl.GetRawText();
        var expected = checksumEl.GetString() ?? string.Empty;
        var actual = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(passwordsJson))).ToLowerInvariant();
        if (!string.Equals(expected, actual, StringComparison.OrdinalIgnoreCase))
        {
            throw new PasswordBackupException("Backup checksum mismatch.");
        }

        return passwordsEl.EnumerateArray()
            .Select(item => SavedPassword.FromJsonElement(item))
            .ToList();
    }

    private static bool IsLegacyV1(JsonElement root)
    {
        if (!root.TryGetProperty("checksum", out _) ||
            !root.TryGetProperty("passwords", out var passwordsEl) ||
            passwordsEl.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        var format = root.TryGetProperty("format", out var formatEl) ? formatEl.GetString() : null;
        var version = root.TryGetProperty("version", out var versionEl) ? versionEl.GetString() : null;
        return !string.Equals(format, EncryptedBackupFormat, StringComparison.Ordinal) &&
               !string.Equals(version, EncryptedBackupVersion, StringComparison.Ordinal);
    }

    private static byte[] DeriveKey(string passphrase, byte[] salt, int iterations)
        => Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(passphrase),
            salt,
            iterations,
            HashAlgorithmName.SHA256,
            32);

    private static string Base64UrlEncode(byte[] bytes)
        => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] Base64UrlDecode(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return [];
        }

        var padded = value.Replace('-', '+').Replace('_', '/');
        switch (padded.Length % 4)
        {
            case 2: padded += "=="; break;
            case 3: padded += "="; break;
        }

        return Convert.FromBase64String(padded);
    }
}
