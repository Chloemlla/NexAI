using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace NexAI.Infrastructure.Security;

/// <summary>
/// Synapse 首访闸门（<c>/api/ip-verification</c>）在 NexAI Windows 端的实现。
///
/// 闸门开启时（线上 chloemlla.com 就是开着的），主机根下 <c>/api/**</c> 的每个请求都要带
/// <c>X-Fingerprint</c> 与 <c>X-IP-Verification-Token</c>；缺令牌一律
/// <c>403 {errorCode:"IP_VERIFICATION_REQUIRED", requiresVerification:true}</c>，
/// 请求根本进不到业务逻辑。NexAI 之前完全不参与这套握手，等于所有后端调用都被挡在门口。
///
/// 语义与 Flutter 端 <c>lib/services/nexai_ip_verification.dart</c> 逐条对齐：
/// 干净 IP 由服务端直接签发 <c>issuedBy:"auto"</c> 的令牌；被标记的 IP 回
/// <c>requiresVerification:true</c> 需要人机验证，此时不伪造、不硬撞，仅记录原因；
/// 令牌有效期听服务端（<c>expiresAt</c> 优先），本地提前 60 秒换新；令牌只活在进程内。
/// </summary>
internal static class NexaiIpVerification
{
    public const string FingerprintHeader = "X-Fingerprint";
    public const string TokenHeader = "X-IP-Verification-Token";
    public const string ErrorCode = "IP_VERIFICATION_REQUIRED";

    private const string SessionPath = "/api/ip-verification/session";
    private const int DefaultTtlMinutes = 40;
    private static readonly TimeSpan RefreshSkew = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan RetryCooldown = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(8);

    private static readonly SemaphoreSlim Gate = new(1, 1);
    private static readonly object StateLock = new();

    private static string? _fingerprint;
    private static string? _token;
    private static DateTimeOffset? _expiresAt;
    private static DateTimeOffset? _blockedUntil;

    /// <summary>最近一次握手失败的原因（诊断用，不参与任何判定）。</summary>
    public static string? LastFailureReason { get; private set; }

    public static string ClientName => "NexAI";

    public static string PlatformLabel
    {
        get
        {
            if (OperatingSystem.IsWindows()) return "Windows";
            if (OperatingSystem.IsLinux()) return "Linux";
            if (OperatingSystem.IsMacOS()) return "macOS";
            if (OperatingSystem.IsAndroid()) return "Android";
            if (OperatingSystem.IsIOS()) return "iOS";
            return "unknown";
        }
    }

    /// <summary>身份头 + 闸门头。取不到指纹时只给身份头，不发注定被拒的握手。</summary>
    public static async Task<IReadOnlyDictionary<string, string>> HeadersAsync(CancellationToken cancellationToken)
    {
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["X-Client-Name"] = ClientName,
            ["X-Platform"] = PlatformLabel,
            ["X-Device-Name"] = SafeMachineName(),
        };

        var fingerprint = await FingerprintAsync(cancellationToken).ConfigureAwait(false);
        if (!string.IsNullOrEmpty(fingerprint))
        {
            headers[FingerprintHeader] = fingerprint;
            headers["X-Device-Id"] = fingerprint;

            lock (StateLock)
            {
                var token = _token;
                if (token is not null && IsFresh(_expiresAt, DateTimeOffset.UtcNow))
                {
                    headers[TokenHeader] = token;
                }
            }
        }

        return headers;
    }

    /// <summary>把新令牌并入一包头（重放时用）。</summary>
    public static IReadOnlyDictionary<string, string> WithToken(
        IReadOnlyDictionary<string, string> headers,
        string token)
    {
        var merged = new Dictionary<string, string>(headers, StringComparer.OrdinalIgnoreCase)
        {
            [TokenHeader] = token,
        };
        return merged;
    }

    /// <summary>
    /// 设备指纹：本地持久化的 32 位 hex（满足服务端 <c>^[A-Za-z0-9_-]{8,200}$</c>）。
    /// 必须跨重启稳定，否则每次启动都会换一个「新设备」，令牌也每次都要重新握手。
    /// </summary>
    public static async Task<string> FingerprintAsync(CancellationToken cancellationToken)
    {
        if (!string.IsNullOrEmpty(_fingerprint)) return _fingerprint;

        await Gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (!string.IsNullOrEmpty(_fingerprint)) return _fingerprint;

            var path = FingerprintPath();
            try
            {
                if (File.Exists(path))
                {
                    var existing = (await File.ReadAllTextAsync(path, cancellationToken).ConfigureAwait(false)).Trim();
                    if (IsValidFingerprint(existing))
                    {
                        _fingerprint = existing;
                        return existing;
                    }
                }

                var created = Guid.NewGuid().ToString("N");
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                await File.WriteAllTextAsync(path, created, cancellationToken).ConfigureAwait(false);
                _fingerprint = created;
                return created;
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                // 落盘失败也不能让每个请求都拿不到指纹：退回进程内临时值（本次运行内稳定）。
                _fingerprint = Guid.NewGuid().ToString("N");
                return _fingerprint;
            }
        }
        finally
        {
            Gate.Release();
        }
    }

    /// <summary>
    /// 拿一个可用令牌：复用缓存 → 向服务端要一个。失败返回 null，绝不抛错。
    /// </summary>
    public static async Task<string?> RefreshAsync(
        Uri requestUrl,
        HttpClient client,
        CancellationToken cancellationToken,
        bool force = false)
    {
        var fingerprint = await FingerprintAsync(cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrEmpty(fingerprint) || !requestUrl.IsAbsoluteUri)
        {
            LastFailureReason = "missing_fingerprint";
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        lock (StateLock)
        {
            if (!force && _token is not null && IsFresh(_expiresAt, now)) return _token;
            if (!force && _blockedUntil is { } blocked && now < blocked) return null;
        }

        var sessionUri = new UriBuilder(requestUrl.Scheme, requestUrl.Host, requestUrl.IsDefaultPort ? -1 : requestUrl.Port, SessionPath).Uri;
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, sessionUri)
            {
                Content = new StringContent(
                    JsonSerializer.Serialize(new Dictionary<string, string> { ["fingerprint"] = fingerprint }),
                    Encoding.UTF8,
                    "application/json"),
            };
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            request.Headers.TryAddWithoutValidation("User-Agent", "NexAI-WinUI");

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(RequestTimeout);
            using var response = await client.SendAsync(request, timeout.Token).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(timeout.Token).ConfigureAwait(false);

            if (LooksBanned(body))
            {
                Block();
                LastFailureReason = "ip_banned";
                return null;
            }
            if ((int)response.StatusCode >= 400)
            {
                Block();
                LastFailureReason = $"http_{(int)response.StatusCode}";
                return null;
            }

            using var json = TryParse(body);
            if (json is null)
            {
                Block();
                LastFailureReason = "invalid_json";
                return null;
            }

            var root = json.RootElement;
            var token = root.TryGetProperty("token", out var tokenElement) ? tokenElement.GetString() : null;
            var verified = !root.TryGetProperty("verified", out var verifiedElement)
                || verifiedElement.ValueKind != JsonValueKind.False;

            if (!string.IsNullOrWhiteSpace(token) && verified)
            {
                lock (StateLock)
                {
                    _token = token;
                    _expiresAt = ResolveExpiry(root);
                    _blockedUntil = null;
                }
                LastFailureReason = null;
                return token;
            }

            if (root.TryGetProperty("requiresVerification", out var requires) && requires.ValueKind == JsonValueKind.True)
            {
                Block();
                var reason = root.TryGetProperty("reason", out var reasonElement) ? reasonElement.GetString() : null;
                LastFailureReason = reason == "ip_risk_blocked" ? "ip_banned" : "requires_human";
                return null;
            }

            Block();
            LastFailureReason = "no_token_issued";
            return null;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            Block();
            LastFailureReason = "timeout";
            return null;
        }
        catch (Exception)
        {
            Block();
            LastFailureReason = "exception";
            return null;
        }
    }

    /// <summary>403 + 闸门标记：请求没进业务逻辑，重放安全。别的 403 不许乱重放。</summary>
    public static bool LooksGated(string? body)
    {
        if (string.IsNullOrEmpty(body)) return false;
        return body.Contains(ErrorCode, StringComparison.Ordinal)
            || body.Contains("\"requiresVerification\":true", StringComparison.Ordinal);
    }

    public static bool LooksBanned(string? body)
    {
        if (string.IsNullOrEmpty(body)) return false;
        return body.Contains("IP已被封禁", StringComparison.Ordinal)
            || body.Contains("\"IP_BANNED\"", StringComparison.Ordinal)
            || body.Contains("\"banned\":true", StringComparison.Ordinal);
    }

    /// <summary>
    /// 把已经读过 body 的响应重建出来交回调用方：<see cref="HttpContent"/> 只能读一次，
    /// 直接返回原对象会让上层拿到空 body（看起来像服务端不返回内容）。
    /// </summary>
    public static HttpResponseMessage RebuildResponse(HttpResponseMessage original, string body)
    {
        var rebuilt = new HttpResponseMessage(original.StatusCode)
        {
            RequestMessage = original.RequestMessage,
            Version = original.Version,
            ReasonPhrase = original.ReasonPhrase,
            Content = new StringContent(
                body ?? string.Empty,
                Encoding.UTF8,
                original.Content?.Headers.ContentType?.MediaType ?? "application/json"),
        };

        foreach (var header in original.Headers)
        {
            rebuilt.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        if (original.Content is not null)
        {
            foreach (var header in original.Content.Headers)
            {
                if (string.Equals(header.Key, "Content-Type", StringComparison.OrdinalIgnoreCase)) continue;
                rebuilt.Content.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }
        }

        original.Dispose();
        return rebuilt;
    }

    private static void Block()
    {
        lock (StateLock)
        {
            _token = null;
            _expiresAt = null;
            _blockedUntil = DateTimeOffset.UtcNow.Add(RetryCooldown);
        }
    }

    private static DateTimeOffset ResolveExpiry(JsonElement root)
    {
        if (root.TryGetProperty("expiresAt", out var expiresElement)
            && expiresElement.ValueKind == JsonValueKind.String
            && DateTimeOffset.TryParse(expiresElement.GetString(), out var parsed))
        {
            return parsed.ToUniversalTime();
        }

        var minutes = DefaultTtlMinutes;
        if (root.TryGetProperty("tokenTtlMinutes", out var ttlElement)
            && ttlElement.ValueKind == JsonValueKind.Number
            && ttlElement.TryGetInt32(out var ttl)
            && ttl > 0)
        {
            minutes = ttl;
        }

        return DateTimeOffset.UtcNow.AddMinutes(minutes);
    }

    private static bool IsFresh(DateTimeOffset? expiresAt, DateTimeOffset now) =>
        expiresAt is { } expiry && now.Add(RefreshSkew) < expiry;

    private static JsonDocument? TryParse(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return null;
        try
        {
            return JsonDocument.Parse(body);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static bool IsValidFingerprint(string value) =>
        value.Length is >= 8 and <= 200 && value.All(c => char.IsLetterOrDigit(c) || c is '_' or '-');

    private static string FingerprintPath()
    {
        var root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrEmpty(root))
        {
            root = Path.GetTempPath();
        }

        return Path.Combine(root, "NexAI", "ip-verification-fingerprint.txt");
    }

    private static string SafeMachineName()
    {
        try
        {
            var name = Environment.MachineName;
            return string.IsNullOrWhiteSpace(name) ? PlatformLabel : name;
        }
        catch (Exception)
        {
            return PlatformLabel;
        }
    }
}
