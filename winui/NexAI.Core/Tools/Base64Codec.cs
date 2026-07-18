namespace NexAI.Core.Tools;

public static class Base64Codec
{
    public const int MaxInputChars = 5 * 1024 * 1024;

    public static string Encode(string input, bool urlSafe = false)
    {
        input ??= string.Empty;
        EnsureWithinLimit(input);
        var encoded = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(input));
        if (!urlSafe)
        {
            return encoded;
        }

        return encoded.TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }

    public static string Decode(string input, bool urlSafe = false)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return string.Empty;
        }

        var normalized = input.Trim();
        EnsureWithinLimit(normalized);
        if (urlSafe)
        {
            normalized = normalized.Replace('-', '+').Replace('_', '/');
            var mod = normalized.Length % 4;
            if (mod != 0)
            {
                normalized += new string('=', 4 - mod);
            }
        }

        var bytes = Convert.FromBase64String(normalized);
        return System.Text.Encoding.UTF8.GetString(bytes);
    }

    private static void EnsureWithinLimit(string value)
    {
        if (value.Length > MaxInputChars)
        {
            throw new InvalidOperationException(
                $"Base64 input is too large. Keep it under {MaxInputChars / (1024 * 1024)} MB.");
        }
    }
}
