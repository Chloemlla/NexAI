using System.Text.Json;

namespace NexAI.Infrastructure.Security;

public interface INexaiSecurityClient
{
    /// <summary>
    /// Calls POST /security/track. If backend returns a device/signing secret,
    /// it is stored as a short-lived signing key. Today Happy-TTS mainly returns
    /// tracking metadata; this remains forward-compatible.
    /// </summary>
    Task TrackDeviceAndMaybeRefreshSigningKeyAsync(
        string backendBaseUrl,
        string accessToken,
        CancellationToken cancellationToken = default);
}

public sealed class NexaiSecurityClient : INexaiSecurityClient
{
    private readonly INexaiHttp _http;
    private readonly INexaiSigningKeyStore _signingKeyStore;

    public NexaiSecurityClient(INexaiHttp http, INexaiSigningKeyStore signingKeyStore)
    {
        _http = http;
        _signingKeyStore = signingKeyStore;
    }

    public async Task TrackDeviceAndMaybeRefreshSigningKeyAsync(
        string backendBaseUrl,
        string accessToken,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return;
        }

        var url = Combine(backendBaseUrl, "/security/track");
        using var doc = await _http.SendJsonAsync(
                HttpMethod.Post,
                url,
                bearerToken: accessToken,
                jsonBody: new { },
                requireSignature: true,
                cancellationToken: cancellationToken)
            .ConfigureAwait(false);

        // Future contract keys accepted:
        // data.deviceSecret / data.signingKey / deviceSecret / signingKey
        // data.keyId / keyId
        // data.expiresAt / expiresAt
        if (!TryReadSigningMaterial(doc.RootElement, out var material) || material is null)
        {
            return;
        }

        await _signingKeyStore.SaveAsync(material, cancellationToken).ConfigureAwait(false);
    }

    private static bool TryReadSigningMaterial(JsonElement root, out NexaiSigningKeyMaterial? material)
    {
        material = null;
        JsonElement data = root;
        if (root.TryGetProperty("data", out var dataEl) && dataEl.ValueKind == JsonValueKind.Object)
        {
            data = dataEl;
        }

        var key =
            GetString(data, "deviceSecret") ??
            GetString(data, "device_secret") ??
            GetString(data, "signingKey") ??
            GetString(data, "signing_key") ??
            GetString(root, "deviceSecret") ??
            GetString(root, "signingKey");

        if (string.IsNullOrWhiteSpace(key))
        {
            return false;
        }

        var keyId =
            GetString(data, "keyId") ??
            GetString(data, "key_id") ??
            GetString(root, "keyId") ??
            "device";

        DateTimeOffset? expiresAt = null;
        var exp =
            GetString(data, "expiresAt") ??
            GetString(data, "expires_at") ??
            GetString(root, "expiresAt");
        if (!string.IsNullOrWhiteSpace(exp) && DateTimeOffset.TryParse(exp, out var parsed))
        {
            expiresAt = parsed.ToUniversalTime();
        }
        else if (data.TryGetProperty("expiresIn", out var expiresIn) && expiresIn.TryGetInt32(out var seconds) && seconds > 0)
        {
            expiresAt = DateTimeOffset.UtcNow.AddSeconds(seconds);
        }

        material = new NexaiSigningKeyMaterial
        {
            Key = key,
            KeyId = keyId ?? "device",
            ExpiresAt = expiresAt,
        };
        return material.IsUsable;
    }

    private static string? GetString(JsonElement element, string name)
        => element.ValueKind == JsonValueKind.Object &&
           element.TryGetProperty(name, out var value) &&
           value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static string Combine(string baseUrl, string path)
        => (baseUrl?.Trim().TrimEnd('/') ?? string.Empty) + path;
}
