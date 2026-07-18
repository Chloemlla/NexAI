using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Tools;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Storage;

public sealed class ProtectedPasswordVaultStore : IPasswordVaultStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private List<SavedPassword> _passwords = [];

    public IReadOnlyList<SavedPassword> Passwords
    {
        get { lock (_gate) { return _passwords.Select(x => x.Clone()).ToList(); } }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(AppPaths.PasswordsFilePath))
        {
            lock (_gate) { _passwords = []; }
            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        try
        {
            var packed = await File.ReadAllBytesAsync(AppPaths.PasswordsFilePath, cancellationToken).ConfigureAwait(false);
            var key = await GetOrCreateKeyAsync(cancellationToken).ConfigureAwait(false);
            var json = Decrypt(packed, key);
            var loaded = JsonSerializer.Deserialize<List<SavedPassword>>(json, Options) ?? [];
            lock (_gate)
            {
                _passwords = loaded.Select(x => x.Clone()).OrderByDescending(x => x.CreatedAt).ToList();
            }
        }
        catch
        {
            lock (_gate) { _passwords = []; }
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task AddAsync(SavedPassword password, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(password);
        lock (_gate)
        {
            _passwords.Insert(0, password.Clone());
        }

        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task DeleteAsync(string id, CancellationToken cancellationToken = default)
    {
        lock (_gate) { _passwords.RemoveAll(x => x.Id == id); }
        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ClearAsync(CancellationToken cancellationToken = default)
    {
        lock (_gate) { _passwords = []; }
        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ReplaceAllAsync(IEnumerable<SavedPassword> passwords, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(passwords);
        lock (_gate)
        {
            _passwords = passwords.Select(x => x.Clone()).OrderByDescending(x => x.CreatedAt).ToList();
        }

        await PersistAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public string ExportCsv()
    {
        var sb = new StringBuilder();
        sb.AppendLine("Category,Password,Strength,Note,CreatedAt");
        IReadOnlyList<SavedPassword> snapshot;
        lock (_gate) { snapshot = _passwords.Select(x => x.Clone()).ToList(); }
        foreach (var item in snapshot)
        {
            var strength = PasswordGenerator.StrengthLabel(item.Strength);
            sb.Append('"').Append(Escape(item.Category)).Append("\",\"")
                .Append(Escape(item.Password)).Append("\",\"")
                .Append(Escape(strength)).Append("\",\"")
                .Append(Escape(item.Note)).Append("\",\"")
                .Append(item.CreatedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")).Append('"')
                .AppendLine();
        }

        return sb.ToString();
    }

    public async Task<string> CreateBackupAsync(string passphrase, CancellationToken cancellationToken = default)
    {
        IReadOnlyList<SavedPassword> snapshot;
        lock (_gate) { snapshot = _passwords.Select(x => x.Clone()).ToList(); }
        return await Task.Run(() => PasswordBackupCrypto.CreateBackup(snapshot, passphrase), cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task RestoreBackupAsync(string backupJson, string? passphrase = null, CancellationToken cancellationToken = default)
    {
        var restored = await Task.Run(() => PasswordBackupCrypto.RestoreBackup(backupJson, passphrase), cancellationToken)
            .ConfigureAwait(false);
        await ReplaceAllAsync(restored, cancellationToken).ConfigureAwait(false);
    }

    private async Task PersistAsync(CancellationToken cancellationToken)
    {
        List<SavedPassword> snapshot;
        lock (_gate) { snapshot = _passwords.Select(x => x.Clone()).ToList(); }
        var json = JsonSerializer.Serialize(snapshot, Options);
        var key = await GetOrCreateKeyAsync(cancellationToken).ConfigureAwait(false);
        var packed = Encrypt(Encoding.UTF8.GetBytes(json), key);
        AppPaths.EnsureRoot();
        var temp = AppPaths.PasswordsFilePath + ".tmp";
        await File.WriteAllBytesAsync(temp, packed, cancellationToken).ConfigureAwait(false);
        File.Copy(temp, AppPaths.PasswordsFilePath, true);
        File.Delete(temp);
    }

    private static async Task<byte[]> GetOrCreateKeyAsync(CancellationToken cancellationToken)
    {
        AppPaths.EnsureRoot();
        if (File.Exists(AppPaths.PasswordsKeyFilePath))
        {
            var existing = (await File.ReadAllTextAsync(AppPaths.PasswordsKeyFilePath, cancellationToken).ConfigureAwait(false)).Trim();
            if (!string.IsNullOrWhiteSpace(existing))
            {
                try
                {
                    if (SecretProtector.IsProtected(existing))
                    {
                        return SecretProtector.UnprotectBytes(
                            Convert.FromBase64String(existing["dpapi:".Length..]));
                    }

                    // Legacy plaintext key on disk: re-protect with DPAPI.
                    var legacy = Base64UrlDecode(existing);
                    await PersistKeyAsync(legacy, cancellationToken).ConfigureAwait(false);
                    return legacy;
                }
                catch
                {
                    // Fall through and rotate if unreadable.
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
                AppPaths.PasswordsKeyFilePath,
                "dpapi:" + Convert.ToBase64String(protectedBytes),
                cancellationToken)
            .ConfigureAwait(false);
    }

    private static byte[] Encrypt(byte[] plaintext, byte[] key)
    {
        var nonce = RandomNumberGenerator.GetBytes(12);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];
        using var aes = new AesGcm(key, 16);
        aes.Encrypt(nonce, plaintext, ciphertext, tag);
        var packed = new byte[12 + ciphertext.Length + 16];
        Buffer.BlockCopy(nonce, 0, packed, 0, 12);
        Buffer.BlockCopy(ciphertext, 0, packed, 12, ciphertext.Length);
        Buffer.BlockCopy(tag, 0, packed, 12 + ciphertext.Length, 16);
        return packed;
    }

    private static string Decrypt(byte[] packed, byte[] key)
    {
        if (packed.Length <= 28)
        {
            throw new CryptographicException("Password vault payload too short.");
        }

        var nonce = packed[..12];
        var tag = packed[^16..];
        var ciphertext = packed[12..^16];
        var plaintext = new byte[ciphertext.Length];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(nonce, ciphertext, tag, plaintext);
        return Encoding.UTF8.GetString(plaintext);
    }

    private static string Escape(string value) => (value ?? string.Empty).Replace("\"", "\"\"");

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
}
