using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using NexAI.Core.Auth;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Auth;

public sealed class NexaiAuthClient : IAuthClient
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly INexaiHttp _http;
    private readonly INexaiSecurityClient _securityClient;

    public NexaiAuthClient(INexaiHttp http, INexaiSecurityClient securityClient)
    {
        _http = http;
        _securityClient = securityClient;
    }

    public async Task<AuthSession> LoginAsync(
        string backendBaseUrl,
        string identifier,
        string password,
        CancellationToken cancellationToken = default)
    {
        var url = Combine(backendBaseUrl, "/auth/login");
        using var doc = await _http.SendJsonAsync(
                HttpMethod.Post,
                url,
                jsonBody: new { identifier, password },
                requireSignature: true,
                cancellationToken: cancellationToken)
            .ConfigureAwait(false);

        if (!doc.RootElement.TryGetProperty("success", out var success) ||
            success.ValueKind != JsonValueKind.True)
        {
            var message = doc.RootElement.TryGetProperty("message", out var msg)
                ? msg.GetString()
                : doc.RootElement.TryGetProperty("error", out var err) ? err.GetString() : "Login failed.";
            throw new InvalidOperationException(message ?? "Login failed.");
        }

        var data = doc.RootElement.GetProperty("data");
        var session = new AuthSession
        {
            AccessToken = GetString(data, "accessToken"),
            RefreshToken = GetString(data, "refreshToken"),
            Username = GetNestedString(data, "user", "username"),
            Email = GetNestedString(data, "user", "email"),
            DisplayName = GetNestedString(data, "user", "displayName"),
        };

        // Best-effort device track + future short-lived signing key ingestion.
        if (!string.IsNullOrWhiteSpace(session.AccessToken))
        {
            try
            {
                await _securityClient.TrackDeviceAndMaybeRefreshSigningKeyAsync(
                        backendBaseUrl,
                        session.AccessToken!,
                        cancellationToken)
                    .ConfigureAwait(false);
            }
            catch
            {
                // Non-fatal: login succeeded even if track is unavailable.
            }
        }

        return session;
    }

    public async Task LogoutAsync(
        string backendBaseUrl,
        string accessToken,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return;
        }

        var url = Combine(backendBaseUrl, "/auth/logout");
        try
        {
            using var _ = await _http.SendAsync(
                    HttpMethod.Post,
                    url,
                    bearerToken: accessToken,
                    jsonBody: new { },
                    requireSignature: true,
                    cancellationToken: cancellationToken)
                .ConfigureAwait(false);
        }
        catch
        {
            // Best effort logout.
        }
    }

    private static string Combine(string baseUrl, string path)
        => (baseUrl?.Trim().TrimEnd('/') ?? string.Empty) + path;

    private static string? GetString(JsonElement element, string name)
        => element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static string? GetNestedString(JsonElement element, string objectName, string name)
    {
        if (!element.TryGetProperty(objectName, out var obj) || obj.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        return GetString(obj, name);
    }
}
