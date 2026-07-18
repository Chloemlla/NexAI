using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace NexAI.Core.Tools;

public enum PasswordGeneratorType
{
    Random,
    Memorable,
    Pin,
}

public sealed class PasswordGeneratorOptions
{
    public PasswordGeneratorType Type { get; set; } = PasswordGeneratorType.Random;
    public int Length { get; set; } = 16;
    public bool IncludeUppercase { get; set; } = true;
    public bool IncludeLowercase { get; set; } = true;
    public bool IncludeNumbers { get; set; } = true;
    public bool IncludeSymbols { get; set; } = true;
    public int WordCount { get; set; } = 4;
    public bool CapitalizeWords { get; set; } = true;
    public bool AddNumbers { get; set; } = true;
    public int PinLength { get; set; } = 6;
}

public static class PasswordGenerator
{
    private static readonly string[] WordList =
    [
        "apple", "banana", "cherry", "dragon", "eagle", "forest", "garden", "happy",
        "island", "jungle", "kitten", "lemon", "mountain", "nature", "ocean", "panda",
        "quartz", "river", "sunset", "tiger", "umbra", "violet", "willow", "yellow",
        "zephyr", "anchor", "bridge", "canyon", "delta", "ember", "falcon", "glacier",
    ];

    public static string Generate(PasswordGeneratorOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);
        return options.Type switch
        {
            PasswordGeneratorType.Memorable => GenerateMemorable(options),
            PasswordGeneratorType.Pin => GeneratePin(options),
            _ => GenerateRandom(options),
        };
    }

    public static IReadOnlyList<string> GenerateBatch(PasswordGeneratorOptions options, int count)
    {
        ArgumentNullException.ThrowIfNull(options);
        count = Math.Clamp(count, 1, 100);
        var set = new HashSet<string>(StringComparer.Ordinal);
        while (set.Count < count)
        {
            set.Add(Generate(options));
        }

        return set.ToList();
    }

    public static int CalculateStrength(string password)
    {
        if (string.IsNullOrEmpty(password))
        {
            return 0;
        }

        var strength = 0;
        if (password.Length >= 8) strength += 20;
        if (password.Length >= 12) strength += 20;
        if (password.Length >= 16) strength += 10;
        if (Regex.IsMatch(password, "[a-z]")) strength += 15;
        if (Regex.IsMatch(password, "[A-Z]")) strength += 15;
        if (Regex.IsMatch(password, "[0-9]")) strength += 10;
        if (Regex.IsMatch(password, @"[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]")) strength += 10;
        return Math.Clamp(strength, 0, 100);
    }

    public static string StrengthLabel(int strength) => strength switch
    {
        < 40 => "Weak",
        < 70 => "Medium",
        _ => "Strong",
    };

    private static string GenerateRandom(PasswordGeneratorOptions options)
    {
        var length = Math.Clamp(options.Length, 4, 32);
        var chars = new StringBuilder();
        if (options.IncludeLowercase) chars.Append("abcdefghijklmnopqrstuvwxyz");
        if (options.IncludeUppercase) chars.Append("ABCDEFGHIJKLMNOPQRSTUVWXYZ");
        if (options.IncludeNumbers) chars.Append("0123456789");
        if (options.IncludeSymbols) chars.Append("!@#$%^&*()_+-=[]{}|;:,.<>?");
        if (chars.Length == 0)
        {
            chars.Append("abcdefghijklmnopqrstuvwxyz");
        }

        var alphabet = chars.ToString();
        var bytes = RandomNumberGenerator.GetBytes(length);
        var result = new char[length];
        for (var i = 0; i < length; i++)
        {
            result[i] = alphabet[bytes[i] % alphabet.Length];
        }

        return new string(result);
    }

    private static string GenerateMemorable(PasswordGeneratorOptions options)
    {
        var wordCount = Math.Clamp(options.WordCount, 2, 6);
        var available = WordList.ToList();
        var selected = new List<string>(wordCount);
        for (var i = 0; i < wordCount; i++)
        {
            var index = RandomNumberGenerator.GetInt32(available.Count);
            var word = available[index];
            available.RemoveAt(index);
            if (options.CapitalizeWords && word.Length > 0)
            {
                word = char.ToUpperInvariant(word[0]) + word[1..];
            }

            selected.Add(word);
        }

        var password = string.Join('-', selected);
        if (options.AddNumbers)
        {
            password += RandomNumberGenerator.GetInt32(0, 100).ToString();
        }

        return password;
    }

    private static string GeneratePin(PasswordGeneratorOptions options)
    {
        var length = Math.Clamp(options.PinLength, 4, 12);
        var bytes = RandomNumberGenerator.GetBytes(length);
        var chars = new char[length];
        for (var i = 0; i < length; i++)
        {
            chars[i] = (char)('0' + (bytes[i] % 10));
        }

        return new string(chars);
    }
}
