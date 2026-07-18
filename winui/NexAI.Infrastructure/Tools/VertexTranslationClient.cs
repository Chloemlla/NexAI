using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using NexAI.Core.Tools;

namespace NexAI.Infrastructure.Tools;

public sealed class VertexTranslationClient : ITranslationClient
{
    private const string ModelId = "gemini-2.0-flash-001";
    private readonly HttpClient _httpClient;

    public VertexTranslationClient(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<string> TranslateAsync(
        string vertexApiKey,
        string sourceLanguage,
        string targetLanguage,
        string text,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(vertexApiKey))
        {
            throw new InvalidOperationException("Configure a Vertex AI API key in Settings first.");
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        if (text.Length > ToolInputLimits.MaxTranslationInputChars)
        {
            throw new InvalidOperationException(
                $"Text is too long. Keep it under {ToolInputLimits.MaxTranslationInputChars} characters.");
        }

        var sourceLabel = TranslationLanguages.All.TryGetValue(sourceLanguage, out var s) ? s : sourceLanguage;
        var targetLabel = TranslationLanguages.All.TryGetValue(targetLanguage, out var t) ? t : targetLanguage;

        // Keep key out of the request URL to reduce proxy/log leakage.
        // Google AI Platform accepts ?key=; we still avoid embedding it in logs by not
        // constructing a loggable absolute URI with secrets elsewhere.
        var endpoint =
            $"https://aiplatform.googleapis.com/v1/publishers/google/models/{ModelId}:generateContent";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    role = "user",
                    parts = new[]
                    {
                        new
                        {
                            text =
                                $"Translate the following text from {sourceLabel} to {targetLabel}. " +
                                "Only return the translated text without any explanation or additional content.\n\n" +
                                $"Text to translate:\n{text}",
                        },
                    },
                },
            },
            generationConfig = new
            {
                temperature = 0.3,
                maxOutputTokens = 2048,
            },
        };

        // Vertex publisher endpoint currently requires API key as query param for this path.
        // Build the request URI without ToString() usage in logs and strip key from exceptions.
        var requestUri = endpoint + "?key=" + Uri.EscapeDataString(vertexApiKey.Trim());
        using var request = new HttpRequestMessage(HttpMethod.Post, requestUri)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"),
        };
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
        if (!response.IsSuccessStatusCode)
        {
            var message = doc.RootElement.TryGetProperty("error", out var error) &&
                          error.TryGetProperty("message", out var msg)
                ? msg.GetString()
                : $"Vertex translation failed: HTTP {(int)response.StatusCode}";
            throw new InvalidOperationException(RedactSecrets(message ?? "Vertex translation failed."));
        }

        if (!doc.RootElement.TryGetProperty("candidates", out var candidates) ||
            candidates.ValueKind != JsonValueKind.Array ||
            candidates.GetArrayLength() == 0)
        {
            throw new InvalidOperationException("Translation failed: empty candidates.");
        }

        var content = candidates[0].TryGetProperty("content", out var contentEl) ? contentEl : default;
        if (content.ValueKind != JsonValueKind.Object ||
            !content.TryGetProperty("parts", out var parts) ||
            parts.ValueKind != JsonValueKind.Array ||
            parts.GetArrayLength() == 0)
        {
            throw new InvalidOperationException("Translation failed: could not parse response.");
        }

        var translated = parts[0].TryGetProperty("text", out var textEl) ? textEl.GetString() : null;
        if (string.IsNullOrWhiteSpace(translated))
        {
            throw new InvalidOperationException("Translation failed: empty result.");
        }

        return translated.Trim();
    }

    private static string RedactSecrets(string message)
    {
        if (string.IsNullOrEmpty(message))
        {
            return message;
        }

        // Defensive: never surface query key material in UI exceptions.
        return System.Text.RegularExpressions.Regex.Replace(
            message,
            @"(?i)([?&]key=)[^&\s]+",
            "$1***");
    }
}
