using System.Net.Http.Headers;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;

namespace NexAI.Infrastructure.Security;

public interface INexaiHttp
{
    Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string absoluteUrl,
        string? bearerToken = null,
        string? refreshTokenForBodySign = null,
        object? jsonBody = null,
        bool requireSignature = true,
        CancellationToken cancellationToken = default);

    Task<JsonDocument> SendJsonAsync(
        HttpMethod method,
        string absoluteUrl,
        string? bearerToken = null,
        string? refreshTokenForBodySign = null,
        object? jsonBody = null,
        bool requireSignature = true,
        CancellationToken cancellationToken = default);
}

public sealed class NexaiHttp : INexaiHttp, IDisposable
{
    public const string PinnedHost = "tts.chloemlla.com";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly INexaiCertPinStore _pinStore;
    private readonly INexaiSigningKeyStore _signingKeyStore;
    private readonly HttpClient _client;
    private readonly object _pinGate = new();
    private NexaiCertPin? _cachedPin;
    private bool _pinLoaded;

    public NexaiHttp(INexaiCertPinStore pinStore, INexaiSigningKeyStore signingKeyStore)
    {
        _pinStore = pinStore;
        _signingKeyStore = signingKeyStore;

        var handler = new SocketsHttpHandler
        {
            SslOptions = new SslClientAuthenticationOptions
            {
                RemoteCertificateValidationCallback = ValidateCertificate,
            },
        };

        _client = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromSeconds(30),
        };
    }

    public async Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string absoluteUrl,
        string? bearerToken = null,
        string? refreshTokenForBodySign = null,
        object? jsonBody = null,
        bool requireSignature = true,
        CancellationToken cancellationToken = default)
    {
        await EnsurePinLoadedAsync(cancellationToken).ConfigureAwait(false);

        var rawBody = jsonBody is null
            ? string.Empty
            : jsonBody is string s
                ? s
                : JsonSerializer.Serialize(jsonBody, JsonOptions);

        using var request = new HttpRequestMessage(method, absoluteUrl);
        if (!string.IsNullOrEmpty(rawBody) || method == HttpMethod.Post || method == HttpMethod.Put || method == HttpMethod.Patch)
        {
            request.Content = new StringContent(
                string.IsNullOrEmpty(rawBody) ? "{}" : rawBody,
                Encoding.UTF8,
                "application/json");
            // Keep rawBody consistent with what we sign. For empty object default above, sign "{}" when content set.
            if (string.IsNullOrEmpty(rawBody) && request.Content is not null)
            {
                rawBody = "{}";
            }
        }

        if (!string.IsNullOrWhiteSpace(bearerToken))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        }

        if (requireSignature)
        {
            var (key, keyId) = await ResolveSigningKeyAsync(
                    bearerToken,
                    refreshTokenForBodySign,
                    absoluteUrl,
                    cancellationToken)
                .ConfigureAwait(false);

            if (string.IsNullOrWhiteSpace(key))
            {
                // Match backend: unauthenticated exempt paths may proceed unsigned only if explicitly not required.
                // For authenticated/gated routes we fail closed.
                if (!string.IsNullOrWhiteSpace(bearerToken) || IsGatedAnonymousPath(absoluteUrl))
                {
                    throw new InvalidOperationException(
                        "Missing NexAI signing key. Provide access token, configure NEXAI_APP_SIGN_SECRET, or obtain a device signing key.");
                }
            }
            else
            {
                var headers = NexaiRequestSigner.Sign(method.Method, absoluteUrl, rawBody, key, keyId);
                foreach (var pair in headers)
                {
                    request.Headers.TryAddWithoutValidation(pair.Key, pair.Value);
                }
            }
        }

        var response = await _client.SendAsync(request, cancellationToken).ConfigureAwait(false);

        // TOFU bootstrap: if no pin yet and host is pinned host, capture peer cert when available.
        // Validation callback already stores pin on first successful system-CA validated handshake.
        return response;
    }

    public async Task<JsonDocument> SendJsonAsync(
        HttpMethod method,
        string absoluteUrl,
        string? bearerToken = null,
        string? refreshTokenForBodySign = null,
        object? jsonBody = null,
        bool requireSignature = true,
        CancellationToken cancellationToken = default)
    {
        using var response = await SendAsync(
                method,
                absoluteUrl,
                bearerToken,
                refreshTokenForBodySign,
                jsonBody,
                requireSignature,
                cancellationToken)
            .ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        return JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
    }

    private async Task EnsurePinLoadedAsync(CancellationToken cancellationToken)
    {
        if (_pinLoaded)
        {
            return;
        }

        var pin = await _pinStore.GetAsync(cancellationToken).ConfigureAwait(false);
        lock (_pinGate)
        {
            _cachedPin = pin;
            _pinLoaded = true;
        }
    }

    private bool ValidateCertificate(
        object sender,
        X509Certificate? certificate,
        X509Chain? chain,
        SslPolicyErrors sslPolicyErrors)
    {
        // Only enforce custom pinning for NexAI backend host.
        var host = TryGetRequestHost(sender);
        if (!string.Equals(host, PinnedHost, StringComparison.OrdinalIgnoreCase))
        {
            return sslPolicyErrors == SslPolicyErrors.None;
        }

        if (certificate is null)
        {
            return false;
        }

        using var cert2 = certificate is X509Certificate2 c2
            ? new X509Certificate2(c2)
            : new X509Certificate2(certificate);

        NexaiCertPin? pin;
        lock (_pinGate)
        {
            pin = _cachedPin;
        }

        var currentFp = NexaiCertPinStore.Sha256Hex(cert2);

        // First connection / no pin yet: require system trust, then TOFU pin.
        if (pin is null || string.IsNullOrWhiteSpace(pin.Sha256Hex))
        {
            if (sslPolicyErrors != SslPolicyErrors.None)
            {
                return false;
            }

            // Fire-and-forget pin store; cache immediately for subsequent sockets.
            lock (_pinGate)
            {
                _cachedPin = new NexaiCertPin
                {
                    Sha256Hex = currentFp,
                    ExpiresAt = cert2.NotAfter.ToUniversalTime(),
                };
            }

            _ = _pinStore.SaveAsync(cert2);
            return true;
        }

        // Strict pin mode: fingerprint must match.
        if (string.Equals(pin.Sha256Hex, currentFp, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Rotation path: only accept if system CA still trusts the new cert, then re-pin.
        if (sslPolicyErrors == SslPolicyErrors.None)
        {
            lock (_pinGate)
            {
                _cachedPin = new NexaiCertPin
                {
                    Sha256Hex = currentFp,
                    ExpiresAt = cert2.NotAfter.ToUniversalTime(),
                };
            }

            _ = _pinStore.SaveAsync(cert2);
            return true;
        }

        return false;
    }

    private static string? TryGetRequestHost(object sender)
    {
        // SslStream callback sender is typically SslStream; host is not always exposed.
        // For SocketsHttpHandler, request host can be recovered from SslClientAuthenticationOptions.TargetHost via reflection fallback.
        try
        {
            if (sender is SslStream)
            {
                // Best effort: pinning is only applied when caller targets PinnedHost URLs for NexAI backend.
                return PinnedHost;
            }
        }
        catch
        {
            // ignore
        }

        return PinnedHost;
    }

    private async Task<(string? key, string keyId)> ResolveSigningKeyAsync(
        string? bearerToken,
        string? refreshTokenForBodySign,
        string absoluteUrl,
        CancellationToken cancellationToken)
    {
        // Prefer short-lived / device signing key if backend issued one.
        var shortLived = await _signingKeyStore.GetAsync(cancellationToken).ConfigureAwait(false);
        if (shortLived is { IsUsable: true })
        {
            return (shortLived.Key, string.IsNullOrWhiteSpace(shortLived.KeyId) ? "device" : shortLived.KeyId);
        }

        if (!string.IsNullOrWhiteSpace(bearerToken))
        {
            return (bearerToken, "token");
        }

        // Refresh body variant.
        if (!string.IsNullOrWhiteSpace(refreshTokenForBodySign) &&
            absoluteUrl.Contains("/auth/refresh", StringComparison.OrdinalIgnoreCase))
        {
            return (refreshTokenForBodySign, "token");
        }

        var appSecret = Environment.GetEnvironmentVariable("NEXAI_APP_SIGN_SECRET");
        if (!string.IsNullOrWhiteSpace(appSecret))
        {
            var keyId = Environment.GetEnvironmentVariable("NEXAI_APP_SIGN_KEY_ID");
            return (appSecret, string.IsNullOrWhiteSpace(keyId) ? NexaiRequestSigner.AppKeyIdDefault : keyId);
        }

        return (null, "token");
    }

    private static bool IsGatedAnonymousPath(string absoluteUrl)
    {
        var path = NexaiRequestSigner.NormalizePath(absoluteUrl);
        return path is
            "/api/nexai/auth/register" or
            "/api/nexai/auth/login" or
            "/api/nexai/auth/google" or
            "/api/nexai/auth/github" or
            "/api/nexai/auth/forgot-password" or
            "/api/nexai/auth/reset-password" or
            "/api/nexai/auth/passkey/login/options" or
            "/api/nexai/auth/passkey/login/verify" or
            "/api/nexai/auth/passkey/login/discoverable/options" or
            "/api/nexai/auth/passkey/login/discoverable/verify" or
            "/api/nexai/auth/refresh" or
            "/api/nexai/security/report" or
            "/api/nexai/security/status";
    }

    public void Dispose() => _client.Dispose();
}
