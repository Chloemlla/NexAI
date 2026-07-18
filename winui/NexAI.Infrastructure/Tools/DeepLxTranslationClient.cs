using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using NexAI.Core.Tools;

namespace NexAI.Infrastructure.Tools;

/// <summary>
/// DeepLX public translation client aligned with Project-Lumen.
/// </summary>
public sealed class DeepLxTranslationClient : ITranslationClient
{
    public const string DefaultBaseUrl = "https://tts.chloemlla.com";
    private const string FallbackSigningSecret = "project-lumen-local-request-signing-key";
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;

    public DeepLxTranslationClient(HttpClient httpClient)
        : this(httpClient, DefaultBaseUrl)
    {
    }

    public DeepLxTranslationClient(HttpClient httpClient, string baseUrl)
    {
        _httpClient = httpClient;
        _baseUrl = string.IsNullOrWhiteSpace(baseUrl) ? DefaultBaseUrl : baseUrl.Trim().TrimEnd('/');
    }

    public async Task<TranslationServiceConfig> GetConfigAsync(CancellationToken cancellationToken = default)
    {
        using var response = await SendAsync(HttpMethod.Get, "/api/public/deeplx/config", body: null, cancellationToken)
            .ConfigureAwait(false);
        using var doc = await ReadJsonAsync(response, cancellationToken).ConfigureAwait(false);
        EnsureSuccess(response, doc);
        var root = doc.RootElement;
        return new TranslationServiceConfig
        {
            Enabled = root.TryGetProperty("enabled", out var enabled) && enabled.ValueKind == JsonValueKind.True,
            RequiresApiKey = root.TryGetProperty("requiresApiKey", out var req) && req.ValueKind == JsonValueKind.True,
            BaseUrl = root.TryGetProperty("baseUrl", out var baseUrl) ? baseUrl.GetString() ?? string.Empty : string.Empty,
            EndpointPath = root.TryGetProperty("endpointPath", out var endpoint) ? endpoint.GetString() ?? string.Empty : string.Empty,
        };
    }

    public async Task<TranslationResult> TranslateAsync(
        string sourceLanguage,
        string targetLanguage,
        string text,
        CancellationToken cancellationToken = default)
    {
        var trimmed = (text ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            throw new InvalidOperationException("Enter source text.");
        }

        if (trimmed.Length > ToolInputLimits.MaxTranslationInputChars)
        {
            throw new InvalidOperationException(
                $"Text is too long. Keep it under {ToolInputLimits.MaxTranslationInputChars} characters.");
        }

        var source = string.IsNullOrWhiteSpace(sourceLanguage) ? "auto" : sourceLanguage.Trim();
        var target = string.IsNullOrWhiteSpace(targetLanguage) ? "ZH" : targetLanguage.Trim();
        var payload = JsonSerializer.Serialize(new
        {
            text = trimmed,
            sourceLang = source,
            targetLang = target,
        });

        using var response = await SendAsync(HttpMethod.Post, "/api/public/deeplx/translate", payload, cancellationToken)
            .ConfigureAwait(false);
        using var doc = await ReadJsonAsync(response, cancellationToken).ConfigureAwait(false);
        EnsureSuccess(response, doc);

        var root = doc.RootElement;
        var translated = root.TryGetProperty("translatedText", out var t) ? t.GetString()?.Trim() : null;
        if (string.IsNullOrWhiteSpace(translated))
        {
            throw new InvalidOperationException("Translation failed: empty result.");
        }

        var alternatives = new List<string>();
        if (root.TryGetProperty("alternatives", out var alt) && alt.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in alt.EnumerateArray())
            {
                var value = item.GetString()?.Trim();
                if (!string.IsNullOrWhiteSpace(value))
                {
                    alternatives.Add(value);
                }
            }
        }

        return new TranslationResult
        {
            TranslatedText = translated,
            SourceLang = root.TryGetProperty("sourceLang", out var sl) ? sl.GetString() ?? source : source,
            TargetLang = root.TryGetProperty("targetLang", out var tl) ? tl.GetString() ?? target : target,
            Alternatives = alternatives,
        };
    }

    private async Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string path,
        string? body,
        CancellationToken cancellationToken)
    {
        var uri = new Uri(_baseUrl + path);
        using var request = new HttpRequestMessage(method, uri);
        request.Headers.TryAddWithoutValidation("Accept", "application/json");
        request.Headers.TryAddWithoutValidation("User-Agent", "NexAI-WinUI");
        foreach (var header in BuildLumenHeaders(method.Method, uri, body ?? string.Empty))
        {
            request.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        if (body is not null)
        {
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        }

        return await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
    }

    private static async Task<JsonDocument> ReadJsonAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        return JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
    }

    private static void EnsureSuccess(HttpResponseMessage response, JsonDocument doc)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        throw new InvalidOperationException(ParseError(doc.RootElement, (int)response.StatusCode));
    }

    private static string ParseError(JsonElement root, int statusCode)
    {
        if (root.TryGetProperty("error", out var error))
        {
            if (error.ValueKind == JsonValueKind.Object &&
                error.TryGetProperty("message", out var message) &&
                !string.IsNullOrWhiteSpace(message.GetString()))
            {
                return message.GetString()!;
            }

            if (error.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(error.GetString()))
            {
                return error.GetString()!;
            }
        }

        if (root.TryGetProperty("message", out var topMessage) &&
            !string.IsNullOrWhiteSpace(topMessage.GetString()))
        {
            return topMessage.GetString()!;
        }

        return statusCode switch
        {
            429 => "Translation request limit reached.",
            503 => "Translation service is not configured.",
            _ => $"Translation failed with HTTP {statusCode}.",
        };
    }

    private static Dictionary<string, string> BuildLumenHeaders(string method, Uri uri, string body)
    {
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var nonce = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
        var bodySha = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(body ?? string.Empty))).ToLowerInvariant();
        var values = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["bodySha256"] = bodySha,
            ["method"] = method.ToUpperInvariant(),
            ["nonce"] = nonce,
            ["path"] = uri.AbsolutePath,
            ["query"] = uri.Query.StartsWith('?') ? uri.Query[1..] : uri.Query,
            ["timestamp"] = timestamp,
        };
        var canonical = string.Join('\n', values.Select(kv => $"{kv.Key}={kv.Value}"));
        var secret = Environment.GetEnvironmentVariable("LUMEN_REQUEST_SIGNING_SECRET");
        if (string.IsNullOrWhiteSpace(secret))
        {
            secret = FallbackSigningSecret;
        }

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var signature = Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
        return new Dictionary<string, string>
        {
            ["X-Lumen-Timestamp"] = timestamp,
            ["X-Lumen-Nonce"] = nonce,
            ["X-Lumen-Signature"] = signature,
        };
    }
}
