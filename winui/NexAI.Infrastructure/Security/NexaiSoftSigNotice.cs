namespace NexAI.Infrastructure.Security;

public sealed class NexaiSoftSigNoticeEventArgs : EventArgs
{
    public required string Result { get; init; }
    public required string Code { get; init; }
    public required string Path { get; init; }
    public required string Message { get; init; }
}

/// Soft-mode signature failure bus for user-visible prompts.
public static class NexaiSoftSigNotice
{
    private static DateTimeOffset _lastShownAt = DateTimeOffset.MinValue;
    private static string? _lastCode;
    private static readonly TimeSpan Throttle = TimeSpan.FromSeconds(12);

    public static event EventHandler<NexaiSoftSigNoticeEventArgs>? Raised;

    private static readonly Dictionary<string, string> CodeHints = new(StringComparer.OrdinalIgnoreCase)
    {
        ["NEXAI_SIG_MISSING"] = "Missing request signature headers",
        ["NEXAI_SIG_VERSION"] = "Unsupported signature version",
        ["NEXAI_SIG_EXPIRED"] = "Request timestamp expired; check system clock",
        ["NEXAI_SIG_REPLAY"] = "Replay detected",
        ["NEXAI_SIG_INVALID"] = "Invalid request signature",
        ["NEXAI_SIG_KEY"] = "No usable signing key",
    };

    public static void MaybeNotify(string? result, string? code, string path)
    {
        if (string.IsNullOrWhiteSpace(result) && string.IsNullOrWhiteSpace(code))
        {
            return;
        }

        var normalized = (result ?? string.Empty).Trim().ToLowerInvariant();
        var isFail = normalized is "fail" or "false" ||
                     (!string.IsNullOrWhiteSpace(code) && code.StartsWith("NEXAI_SIG_", StringComparison.OrdinalIgnoreCase));
        if (!isFail)
        {
            return;
        }

        var now = DateTimeOffset.UtcNow;
        if (now - _lastShownAt < Throttle &&
            string.Equals(_lastCode, code, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        _lastShownAt = now;
        _lastCode = code;

        var hint = (!string.IsNullOrWhiteSpace(code) && CodeHints.TryGetValue(code, out var mapped))
            ? mapped
            : "Server soft mode accepted the request, but signature verification failed";
        var message = string.IsNullOrWhiteSpace(code)
            ? $"Signature notice: {hint} · {path}"
            : $"Signature notice: {hint} ({code}) · {path}";

        System.Diagnostics.Debug.WriteLine(message);
        Raised?.Invoke(null, new NexaiSoftSigNoticeEventArgs
        {
            Result = result ?? "fail",
            Code = code ?? string.Empty,
            Path = path,
            Message = message,
        });
    }
}
