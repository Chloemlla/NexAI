using System.Net;
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
    public const string PinnedHost = "chloemlla.com";

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

        // Keep rawBody consistent with what we sign: 写方法即使没有 body 也发并签 "{}"。
        if (string.IsNullOrEmpty(rawBody)
            && (method == HttpMethod.Post || method == HttpMethod.Put || method == HttpMethod.Patch))
        {
            rawBody = "{}";
        }

        // Synapse 首访闸门：主机根下每个 /api/** 请求都要带 X-Fingerprint / X-IP-Verification-Token。
        // 缺令牌时服务端在业务之前就 403 IP_VERIFICATION_REQUIRED，所以必须先带上再发。
        var gateHeaders = await NexaiIpVerification.HeadersAsync(cancellationToken).ConfigureAwait(false);

        var response = await SendOnceAsync(
                method,
                absoluteUrl,
                bearerToken,
                refreshTokenForBodySign,
                rawBody,
                requireSignature,
                gateHeaders,
                cancellationToken)
            .ConfigureAwait(false);
        NotifySoftSignatureHeaders(response, absoluteUrl);

        if (response.StatusCode != HttpStatusCode.Forbidden)
        {
            return response;
        }

        // 403 的 body 一读就没了：非闸门的 403（例如令牌过期）要原样交回调用方，读之前先判状态。
        var gateBody = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (!NexaiIpVerification.LooksGated(gateBody))
        {
            return NexaiIpVerification.RebuildResponse(response, gateBody);
        }

        // 闸门 403 说明请求根本没进业务逻辑，重放安全；换不到令牌就把原 403 交回调用方。
        var refreshed = await NexaiIpVerification
            .RefreshAsync(new Uri(absoluteUrl), _client, cancellationToken, force: true)
            .ConfigureAwait(false);
        if (string.IsNullOrEmpty(refreshed))
        {
            return NexaiIpVerification.RebuildResponse(response, gateBody);
        }

        response.Dispose();
        var retried = await SendOnceAsync(
                method,
                absoluteUrl,
                bearerToken,
                refreshTokenForBodySign,
                rawBody,
                requireSignature,
                NexaiIpVerification.WithToken(gateHeaders, refreshed),
                cancellationToken)
            .ConfigureAwait(false);
        NotifySoftSignatureHeaders(retried, absoluteUrl);

        // TOFU bootstrap: if no pin yet and host is pinned host, capture peer cert when available.
        // Validation callback already stores pin on first successful system-CA validated handshake.
        return retried;
    }

    /// <summary>
    /// 发一次请求（每次新建 <see cref="HttpRequestMessage"/>）。
    ///
    /// 必须每次重新签名：签名 canonical 含一次性 nonce，重放旧签名在启用验签的部署上
    /// 会被当成 nonce_replay 拒掉；退回闸门重试时走的正是这条路径。
    /// </summary>
    private async Task<HttpResponseMessage> SendOnceAsync(
        HttpMethod method,
        string absoluteUrl,
        string? bearerToken,
        string? refreshTokenForBodySign,
        string rawBody,
        bool requireSignature,
        IReadOnlyDictionary<string, string> gateHeaders,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(method, absoluteUrl);
        if (!string.IsNullOrEmpty(rawBody))
        {
            request.Content = new StringContent(rawBody, Encoding.UTF8, "application/json");
        }

        if (!string.IsNullOrWhiteSpace(bearerToken))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        }

        foreach (var pair in gateHeaders)
        {
            request.Headers.TryAddWithoutValidation(pair.Key, pair.Value);
        }

        if (requireSignature && !IsSignatureExempt(method, absoluteUrl))
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
                // Gated anonymous paths (login, register, etc.) are allowed without a signing key
                // so that fresh sign-in works without a pre-provisioned device key.
                if (!string.IsNullOrWhiteSpace(bearerToken))
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

        return await _client.SendAsync(request, cancellationToken).ConfigureAwait(false);
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

            _ = _pinStore.SaveAsync(cert2).ContinueWith(t =>
                {
                    if (t.Exception is not null)
                    {
                        System.Diagnostics.Debug.WriteLine("[NexAI Http] Pin store save failed: " + t.Exception);
                    }
                }, TaskContinuationOptions.OnlyOnFaulted);
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

            _ = _pinStore.SaveAsync(cert2).ContinueWith(t =>
                {
                    if (t.Exception is not null)
                    {
                        System.Diagnostics.Debug.WriteLine("[NexAI Http] Pin store save (rotation) failed: " + t.Exception);
                    }
                }, TaskContinuationOptions.OnlyOnFaulted);
            return true;
        }

        return false;
    }

    private static string? TryGetRequestHost(object sender)
    {
        // SslStream callback sender is typically SslStream; recover the actual target host.
        // Only apply pinning when the host matches the known pinned backend.
        try
        {
            if (sender is SslStream sslStream)
            {
                // TargetHostName was added in .NET 5+ and is available on SslStream.
                var targetHost = sslStream.TargetHostName;
                if (!string.IsNullOrWhiteSpace(targetHost))
                {
                    return targetHost;
                }
            }
        }
        catch
        {
            // ignore
        }

        // Could not determine the target host; default to standard CA validation.
        return null;
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

    /// <summary>
    /// Method-aware public exemptions aligned with Happy-TTS 5baba9cd:
    /// GET/HEAD only for oauth-config, github callback, release manifest, artifact shortId.
    /// Mutating artifact methods are NOT exempt.
    /// </summary>
    public static bool IsSignatureExempt(HttpMethod method, string absoluteUrl)
    {
        var m = method.Method.ToUpperInvariant();
        if (m is not ("GET" or "HEAD"))
        {
            return false;
        }

        var path = NexaiRequestSigner.NormalizePath(absoluteUrl);
        if (path == "/api/nexai/auth/oauth-config") return true;
        if (path == "/api/nexai/auth/github/callback") return true;
        if (System.Text.RegularExpressions.Regex.IsMatch(path, @"^/api/nexai/releases/[^/]+/manifest$")) return true;
        if (System.Text.RegularExpressions.Regex.IsMatch(path, @"^/api/nexai/artifacts/[^/]+$")) return true;
        return false;
    }

    public void Dispose() => _client.Dispose();

    private static void NotifySoftSignatureHeaders(HttpResponseMessage response, string absoluteUrl)
    {
        if (!response.Headers.TryGetValues("X-NexAI-Sig-Result", out var results) &&
            !response.Headers.TryGetValues("X-NexAI-Sig-Code", out _))
        {
            return;
        }

        string? result = null;
        string? code = null;
        if (response.Headers.TryGetValues("X-NexAI-Sig-Result", out var resultValues))
        {
            result = resultValues.FirstOrDefault();
        }

        if (response.Headers.TryGetValues("X-NexAI-Sig-Code", out var codeValues))
        {
            code = codeValues.FirstOrDefault();
        }

        NexaiSoftSigNotice.MaybeNotify(
            result,
            code,
            NexaiRequestSigner.NormalizePath(absoluteUrl));
    }
}
