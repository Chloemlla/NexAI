namespace NexAI.Core.Tools;

public static class Base64Codec
{
    public static string Encode(string input, bool urlSafe = false)
    {
        input ??= string.Empty;
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
}
