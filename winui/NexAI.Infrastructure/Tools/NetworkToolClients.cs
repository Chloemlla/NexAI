using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using NexAI.Core.Tools;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Tools;

public sealed class MmpShortUrlClient : IShortUrlClient
{
    private readonly HttpClient _httpClient;

    public MmpShortUrlClient(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<ShortUrlResult> CreateAsync(string longUrl, CancellationToken cancellationToken = default)
    {
        if (!Uri.TryCreate(longUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            throw new InvalidOperationException("Please provide a valid http(s) URL.");
        }

        var requestUri = "https://api.mmp.cc/api/dwz?longurl=" + Uri.EscapeDataString(longUrl);
        using var response = await _httpClient.GetAsync(requestUri, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Short URL API failed: HTTP {(int)response.StatusCode}");
        }

        if (doc.RootElement.TryGetProperty("status", out var status) &&
            status.ValueKind == JsonValueKind.Number &&
            status.GetInt32() == 200 &&
            doc.RootElement.TryGetProperty("shorturl", out var shortUrl) &&
            shortUrl.ValueKind == JsonValueKind.String)
        {
            return new ShortUrlResult
            {
                OriginalUrl = longUrl,
                ShortUrl = shortUrl.GetString() ?? string.Empty,
            };
        }

        var message = doc.RootElement.TryGetProperty("msg", out var msg)
            ? msg.GetString()
            : "Short URL API returned an unexpected payload.";
        throw new InvalidOperationException(message ?? "Short URL creation failed.");
    }
}

public sealed class NexaiArtifactsClient : IArtifactsClient
{
    private readonly INexaiHttp _http;

    public NexaiArtifactsClient(INexaiHttp http) => _http = http;

    public async Task<ArtifactCreateResult> CreateAsync(
        string backendBaseUrl,
        string accessToken,
        string title,
        string content,
        string contentType = "text",
        string? language = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            throw new InvalidOperationException("Sign in before creating artifacts.");
        }

        var url = (backendBaseUrl?.Trim().TrimEnd('/') ?? string.Empty) + "/artifacts";
        var payload = new Dictionary<string, object?>
        {
            ["title"] = string.IsNullOrWhiteSpace(title) ? "NexAI Artifact" : title.Trim(),
            ["content_type"] = string.IsNullOrWhiteSpace(contentType) ? "text" : contentType,
            ["content"] = Convert.ToBase64String(Encoding.UTF8.GetBytes(content ?? string.Empty)),
            ["visibility"] = "public",
        };
        if (!string.IsNullOrWhiteSpace(language))
        {
            payload["language"] = language;
        }

        using var response = await _http.SendAsync(
                HttpMethod.Post,
                url,
                bearerToken: accessToken,
                jsonBody: payload,
                requireSignature: true,
                cancellationToken: cancellationToken)
            .ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        if ((int)response.StatusCode is not (200 or 201))
        {
            var err = doc.RootElement.TryGetProperty("error", out var error)
                ? error.GetString()
                : $"HTTP {(int)response.StatusCode}";
            throw new InvalidOperationException(err ?? "Failed to create artifact.");
        }

        if (!doc.RootElement.TryGetProperty("data", out var data) || data.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidOperationException("Artifact API returned no data.");
        }

        var shortId = data.TryGetProperty("shortId", out var sid) ? sid.GetString()
            : data.TryGetProperty("short_id", out var sid2) ? sid2.GetString()
            : data.TryGetProperty("id", out var id) ? id.GetString()
            : null;
        var resultUrl = data.TryGetProperty("url", out var u) ? u.GetString()
            : data.TryGetProperty("shareUrl", out var su) ? su.GetString()
            : null;
        if (string.IsNullOrWhiteSpace(shortId) && string.IsNullOrWhiteSpace(resultUrl))
        {
            throw new InvalidOperationException("Artifact API response missing short id/url.");
        }

        return new ArtifactCreateResult
        {
            ShortId = shortId ?? string.Empty,
            Url = resultUrl ?? ((backendBaseUrl?.Trim().TrimEnd('/') ?? string.Empty) + "/artifacts/" + shortId),
            Title = data.TryGetProperty("title", out var t) ? t.GetString() : title,
        };
    }
}

public sealed class OpenAiImageGenerationClient : IImageGenerationClient
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly HttpClient _httpClient;

    public OpenAiImageGenerationClient(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<ImageGenerationResult> GenerateAsync(
        string baseUrl,
        string apiKey,
        string model,
        string prompt,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(prompt))
        {
            throw new InvalidOperationException("Prompt is required.");
        }

        var endpoint = (baseUrl?.Trim().TrimEnd('/') ?? string.Empty) + "/images/generations";
        var payload = new Dictionary<string, object?>
        {
            ["model"] = model,
            ["prompt"] = prompt,
            ["size"] = "1024x1024",
            ["response_format"] = "url",
            ["n"] = 1,
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload, Options), Encoding.UTF8, "application/json"),
        };
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey.Trim());
        }

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            return await GenerateViaChatFallbackAsync(
                    baseUrl ?? string.Empty,
                    apiKey ?? string.Empty,
                    model,
                    prompt,
                    body,
                    cancellationToken)
                .ConfigureAwait(false);
        }

        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        var urls = new List<string>();
        if (doc.RootElement.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in data.EnumerateArray())
            {
                if (item.TryGetProperty("url", out var url) && url.ValueKind == JsonValueKind.String)
                {
                    var value = url.GetString();
                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        urls.Add(value);
                    }
                }
                else if (item.TryGetProperty("b64_json", out var b64) && b64.ValueKind == JsonValueKind.String)
                {
                    urls.Add("data:image/png;base64," + b64.GetString());
                }
            }
        }

        if (urls.Count == 0)
        {
            throw new InvalidOperationException("Image API returned no image URLs.");
        }

        return new ImageGenerationResult { ImageUrls = urls, RawResponse = body };
    }

    private async Task<ImageGenerationResult> GenerateViaChatFallbackAsync(
        string? baseUrl,
        string? apiKey,
        string model,
        string prompt,
        string primaryErrorBody,
        CancellationToken cancellationToken)
    {
        var endpoint = (baseUrl?.Trim().TrimEnd('/') ?? string.Empty) + "/chat/completions";
        var payload = new
        {
            model,
            stream = false,
            messages = new[]
            {
                new { role = "user", content = prompt },
            },
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload, Options), Encoding.UTF8, "application/json"),
        };
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey.Trim());
        }

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Image generation failed. images/generations error + chat fallback HTTP {(int)response.StatusCode}. {Trim(primaryErrorBody)}");
        }

        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        var content = doc.RootElement.TryGetProperty("choices", out var choices) &&
                      choices.ValueKind == JsonValueKind.Array &&
                      choices.GetArrayLength() > 0 &&
                      choices[0].TryGetProperty("message", out var message) &&
                      message.TryGetProperty("content", out var c) &&
                      c.ValueKind == JsonValueKind.String
            ? c.GetString() ?? string.Empty
            : body;

        var urls = Regex.Matches(content, "https?://[^\\s\\)\\]\"']+")
            .Select(m => m.Value)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (urls.Count == 0)
        {
            throw new InvalidOperationException("No image URL found in chat fallback response.");
        }

        return new ImageGenerationResult { ImageUrls = urls, RawResponse = content };
    }

    private static string Trim(string value)
    {
        var compact = (value ?? string.Empty).ReplaceLineEndings(" ").Trim();
        return compact.Length <= 240 ? compact : compact[..240] + "…";
    }
}
