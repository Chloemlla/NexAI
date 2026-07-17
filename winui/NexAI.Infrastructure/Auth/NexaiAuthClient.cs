using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using NexAI.Core.Auth;

namespace NexAI.Infrastructure.Auth;

public sealed class NexaiAuthClient : IAuthClient
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly HttpClient _httpClient;

    public NexaiAuthClient(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<AuthSession> LoginAsync(
        string backendBaseUrl,
        string identifier,
        string password,
        CancellationToken cancellationToken = default)
    {
        var url = Combine(backendBaseUrl, "/auth/login");
        using var request = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(
                JsonSerializer.Serialize(new { identifier, password }, Options),
                Encoding.UTF8,
                "application/json"),
        };

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        if (!response.IsSuccessStatusCode ||
            !doc.RootElement.TryGetProperty("success", out var success) ||
            success.ValueKind != JsonValueKind.True)
        {
            var message = doc.RootElement.TryGetProperty("message", out var msg)
                ? msg.GetString()
                : $"HTTP {(int)response.StatusCode}";
            throw new InvalidOperationException(message ?? "Login failed.");
        }

        var data = doc.RootElement.GetProperty("data");
        return new AuthSession
        {
            AccessToken = GetString(data, "accessToken"),
            RefreshToken = GetString(data, "refreshToken"),
            Username = GetNestedString(data, "user", "username"),
            Email = GetNestedString(data, "user", "email"),
            DisplayName = GetNestedString(data, "user", "displayName"),
        };
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
        using var request = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent("{}", Encoding.UTF8, "application/json"),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        try
        {
            using var _ = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
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
