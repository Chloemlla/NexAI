using System.Security.Cryptography;
using System.Text;

namespace NexAI.Infrastructure.Security;

/// <summary>
/// Happy-TTS / NexAI nexai-sig-v2 request signer.
/// Canonical: ts\nnonce\nMETHOD\npath\nrawBody
/// </summary>
public static class NexaiRequestSigner
{
    public const string Version = "2";
    public const string AppKeyIdDefault = "app:v1";

    public static IReadOnlyDictionary<string, string> Sign(
        string method,
        string path,
        string rawBody,
        string signingKey,
        string keyId)
    {
        if (string.IsNullOrWhiteSpace(signingKey))
        {
            throw new InvalidOperationException("Missing NexAI signing key.");
        }

        var ts = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();
        var nonce = CreateNonce(24);
        var canonical = string.Join('\n',
        [
            ts,
            nonce,
            method.Trim().ToUpperInvariant(),
            NormalizePath(path),
            rawBody ?? string.Empty,
        ]);

        var sig = HmacSha256Hex(signingKey, canonical);
        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["X-NexAI-Sig-Version"] = Version,
            ["X-NexAI-Ts"] = ts,
            ["X-NexAI-Nonce"] = nonce,
            ["X-NexAI-Sig"] = sig,
            ["X-NexAI-Key-Id"] = string.IsNullOrWhiteSpace(keyId) ? "token" : keyId,
        };
    }

    public static string NormalizePath(string? pathOrUrl)
    {
        if (string.IsNullOrWhiteSpace(pathOrUrl))
        {
            return "/";
        }

        if (Uri.TryCreate(pathOrUrl, UriKind.Absolute, out var uri))
        {
            return string.IsNullOrEmpty(uri.AbsolutePath) ? "/" : uri.AbsolutePath;
        }

        var path = pathOrUrl.Split('?', 2)[0];
        return string.IsNullOrEmpty(path) ? "/" : path;
    }

    private static string CreateNonce(int length)
    {
        const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var bytes = RandomNumberGenerator.GetBytes(length);
        var sb = new StringBuilder(length);
        for (var i = 0; i < length; i++)
        {
            sb.Append(chars[bytes[i] % chars.Length]);
        }

        return sb.ToString();
    }

    private static string HmacSha256Hex(string key, string message)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(message));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
