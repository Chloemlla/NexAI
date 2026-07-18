using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Text;

namespace NexAI.Infrastructure.Security;

/// <summary>
/// DPAPI helper for current-user secret protection on Windows.
/// Values are stored as: "dpapi:" + base64(protectedBytes)
/// </summary>
[SupportedOSPlatform("windows")]
public static class SecretProtector
{
    private const string Prefix = "dpapi:";

    public static bool IsProtected(string? value) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.StartsWith(Prefix, StringComparison.Ordinal);

    public static string Protect(string? plaintext)
    {
        if (string.IsNullOrEmpty(plaintext))
        {
            return string.Empty;
        }

        if (IsProtected(plaintext))
        {
            return plaintext;
        }

        var bytes = Encoding.UTF8.GetBytes(plaintext);
        var protectedBytes = ProtectedData.Protect(
            bytes,
            optionalEntropy: null,
            scope: DataProtectionScope.CurrentUser);
        return Prefix + Convert.ToBase64String(protectedBytes);
    }

    public static string Unprotect(string? stored)
    {
        if (string.IsNullOrEmpty(stored))
        {
            return string.Empty;
        }

        if (!IsProtected(stored))
        {
            // Backward compatible: previously plain values.
            return stored;
        }

        var b64 = stored[Prefix.Length..];
        var protectedBytes = Convert.FromBase64String(b64);
        var bytes = ProtectedData.Unprotect(
            protectedBytes,
            optionalEntropy: null,
            scope: DataProtectionScope.CurrentUser);
        return Encoding.UTF8.GetString(bytes);
    }

    public static byte[] ProtectBytes(byte[] plaintext)
    {
        ArgumentNullException.ThrowIfNull(plaintext);
        return ProtectedData.Protect(plaintext, null, DataProtectionScope.CurrentUser);
    }

    public static byte[] UnprotectBytes(byte[] protectedBytes)
    {
        ArgumentNullException.ThrowIfNull(protectedBytes);
        return ProtectedData.Unprotect(protectedBytes, null, DataProtectionScope.CurrentUser);
    }
}
