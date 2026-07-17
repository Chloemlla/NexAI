using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using NexAI.Core.Chat;

namespace NexAI.Infrastructure.Chat;

public sealed class OpenAiCompatibleChatClient : IChatStreamingClient
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly HttpClient _httpClient;

    public OpenAiCompatibleChatClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
        _httpClient.Timeout = Timeout.InfiniteTimeSpan;
    }

    public async IAsyncEnumerable<string> StreamAsync(
        ChatCompletionRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var endpoint = BuildEndpoint(request.BaseUrl);
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, endpoint);
        httpRequest.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("text/event-stream"));
        if (!string.IsNullOrWhiteSpace(request.ApiKey))
        {
            httpRequest.Headers.Authorization =
                new AuthenticationHeaderValue("Bearer", request.ApiKey.Trim());
        }

        var payload = new Dictionary<string, object?>
        {
            ["model"] = request.Model,
            ["messages"] = BuildMessages(request),
            ["temperature"] = request.Temperature,
            ["max_tokens"] = request.MaxTokens,
            ["stream"] = true,
        };

        httpRequest.Content = new StringContent(
            JsonSerializer.Serialize(payload, SerializerOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient
            .SendAsync(httpRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
            .ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            throw new HttpRequestException(BuildErrorMessage(response, body));
        }

        await using var stream = await response.Content
            .ReadAsStreamAsync(cancellationToken)
            .ConfigureAwait(false);
        using var reader = new StreamReader(stream);

        while (!reader.EndOfStream)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var line = await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
            if (line is null)
            {
                break;
            }

            var trimmed = line.Trim();
            if (trimmed.Length == 0 || !trimmed.StartsWith("data:", StringComparison.Ordinal))
            {
                continue;
            }

            var data = trimmed[5..].TrimStart();
            if (data is "[DONE]")
            {
                yield break;
            }

            string? delta = null;
            try
            {
                using var document = JsonDocument.Parse(data);
                if (document.RootElement.TryGetProperty("choices", out var choices) &&
                    choices.ValueKind == JsonValueKind.Array &&
                    choices.GetArrayLength() > 0)
                {
                    var first = choices[0];
                    if (first.TryGetProperty("delta", out var deltaElement) &&
                        deltaElement.ValueKind == JsonValueKind.Object &&
                        deltaElement.TryGetProperty("content", out var contentElement) &&
                        contentElement.ValueKind == JsonValueKind.String)
                    {
                        delta = contentElement.GetString();
                    }
                }
            }
            catch (JsonException)
            {
                // Skip malformed SSE chunks, matching Flutter client behavior.
            }

            if (!string.IsNullOrEmpty(delta))
            {
                yield return delta;
            }
        }
    }

    private static List<Dictionary<string, string>> BuildMessages(ChatCompletionRequest request)
    {
        var messages = new List<Dictionary<string, string>>();
        if (!string.IsNullOrWhiteSpace(request.SystemPrompt))
        {
            messages.Add(new Dictionary<string, string>
            {
                ["role"] = ChatRoles.System,
                ["content"] = request.SystemPrompt.Trim(),
            });
        }

        foreach (var message in request.Messages)
        {
            if (message.IsError || string.IsNullOrWhiteSpace(message.Content))
            {
                continue;
            }

            messages.Add(new Dictionary<string, string>
            {
                ["role"] = message.Role,
                ["content"] = message.Content,
            });
        }

        return messages;
    }

    private static Uri BuildEndpoint(string baseUrl)
    {
        var trimmed = (baseUrl ?? string.Empty).Trim().TrimEnd('/');
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            throw new InvalidOperationException("Base URL must be an absolute http(s) URL.");
        }

        if (trimmed.EndsWith("/chat/completions", StringComparison.OrdinalIgnoreCase))
        {
            return new Uri(trimmed);
        }

        return new Uri(trimmed + "/chat/completions");
    }

    private static string BuildErrorMessage(HttpResponseMessage response, string body)
    {
        var status = (int)response.StatusCode;
        if (string.IsNullOrWhiteSpace(body))
        {
            return $"HTTP {status} {response.ReasonPhrase}".Trim();
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            if (document.RootElement.TryGetProperty("error", out var errorElement))
            {
                if (errorElement.ValueKind == JsonValueKind.Object &&
                    errorElement.TryGetProperty("message", out var messageElement) &&
                    messageElement.ValueKind == JsonValueKind.String)
                {
                    return $"HTTP {status}: {messageElement.GetString()}";
                }

                if (errorElement.ValueKind == JsonValueKind.String)
                {
                    return $"HTTP {status}: {errorElement.GetString()}";
                }
            }
        }
        catch (JsonException)
        {
            // Fall through to truncated raw body.
        }

        var compact = body.ReplaceLineEndings(" ").Trim();
        if (compact.Length > 280)
        {
            compact = compact[..280] + "…";
        }

        return $"HTTP {status}: {compact}";
    }
}
