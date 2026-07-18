using System.Text.Json;

namespace NexAI.Core.Tools;

public sealed class TranslationRecord
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string SourceLanguage { get; set; } = "en";
    public string TargetLanguage { get; set; } = "zh-CN";
    public string SourceText { get; set; } = string.Empty;
    public string TranslatedText { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public TranslationRecord Clone() => new()
    {
        Id = Id,
        SourceLanguage = SourceLanguage,
        TargetLanguage = TargetLanguage,
        SourceText = SourceText,
        TranslatedText = TranslatedText,
        CreatedAt = CreatedAt,
    };
}

public sealed class ShortUrlRecord
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string OriginalUrl { get; set; } = string.Empty;
    public string ShortUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ShortUrlRecord Clone() => new()
    {
        Id = Id,
        OriginalUrl = OriginalUrl,
        ShortUrl = ShortUrl,
        CreatedAt = CreatedAt,
    };
}

public sealed class SavedPassword
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Password { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Note { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public int Strength { get; set; }

    public SavedPassword Clone() => new()
    {
        Id = Id,
        Password = Password,
        Category = Category,
        Note = Note,
        CreatedAt = CreatedAt,
        Strength = Strength,
    };

    public Dictionary<string, object?> ToDictionary() => new()
    {
        ["id"] = Id,
        ["password"] = Password,
        ["category"] = Category,
        ["note"] = Note,
        ["createdAt"] = CreatedAt.ToString("O"),
        ["strength"] = Strength,
    };

    public static Dictionary<string, object?> ToDictionary(JsonElement element)
    {
        var dict = new Dictionary<string, object?>();
        if (element.ValueKind != JsonValueKind.Object)
        {
            return dict;
        }

        foreach (var prop in element.EnumerateObject())
        {
            dict[prop.Name] = prop.Value.ValueKind switch
            {
                JsonValueKind.String => prop.Value.GetString(),
                JsonValueKind.Number => prop.Value.TryGetInt32(out var i) ? i : prop.Value.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                _ => prop.Value.ToString(),
            };
        }

        return dict;
    }

    public static SavedPassword FromDictionary(Dictionary<string, object?> map)
    {
        return new SavedPassword
        {
            Id = map.TryGetValue("id", out var id) ? id?.ToString() ?? Guid.NewGuid().ToString("N") : Guid.NewGuid().ToString("N"),
            Password = map.TryGetValue("password", out var password) ? password?.ToString() ?? string.Empty : string.Empty,
            Category = map.TryGetValue("category", out var category) ? category?.ToString() ?? string.Empty : string.Empty,
            Note = map.TryGetValue("note", out var note) ? note?.ToString() ?? string.Empty : string.Empty,
            CreatedAt = map.TryGetValue("createdAt", out var createdAt) && DateTime.TryParse(createdAt?.ToString(), out var dt)
                ? dt.ToUniversalTime()
                : DateTime.UtcNow,
            Strength = map.TryGetValue("strength", out var strength) && int.TryParse(strength?.ToString(), out var s) ? s : 0,
        };
    }

    public static SavedPassword FromJsonElement(JsonElement element)
        => FromDictionary(ToDictionary(element));
}

public interface ITranslationHistoryStore
{
    IReadOnlyList<TranslationRecord> History { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task AddAsync(TranslationRecord record, CancellationToken cancellationToken = default);
    Task DeleteAsync(string id, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
}

public interface IShortUrlHistoryStore
{
    IReadOnlyList<ShortUrlRecord> History { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task AddAsync(ShortUrlRecord record, CancellationToken cancellationToken = default);
    Task DeleteAsync(string id, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
}

public interface IPasswordVaultStore
{
    IReadOnlyList<SavedPassword> Passwords { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task AddAsync(SavedPassword password, CancellationToken cancellationToken = default);
    Task DeleteAsync(string id, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
    Task ReplaceAllAsync(IEnumerable<SavedPassword> passwords, CancellationToken cancellationToken = default);
    string ExportCsv();
    Task<string> CreateBackupAsync(string passphrase, CancellationToken cancellationToken = default);
    Task RestoreBackupAsync(string backupJson, string? passphrase = null, CancellationToken cancellationToken = default);
}

public sealed class TranslationServiceConfig
{
    public bool Enabled { get; init; } = true;
    public bool RequiresApiKey { get; init; }
    public string BaseUrl { get; init; } = string.Empty;
    public string EndpointPath { get; init; } = string.Empty;
}

public sealed class TranslationResult
{
    public required string TranslatedText { get; init; }
    public string SourceLang { get; init; } = "auto";
    public string TargetLang { get; init; } = "ZH";
    public IReadOnlyList<string> Alternatives { get; init; } = Array.Empty<string>();
}

public interface ITranslationClient
{
    Task<TranslationServiceConfig> GetConfigAsync(CancellationToken cancellationToken = default);

    Task<TranslationResult> TranslateAsync(
        string sourceLanguage,
        string targetLanguage,
        string text,
        CancellationToken cancellationToken = default);
}

/// <summary>Lumen DeepLX language sets.</summary>
public static class TranslationLanguages
{
    public static IReadOnlyDictionary<string, string> Source { get; } = new Dictionary<string, string>
    {
        ["auto"] = "Auto detect",
        ["ZH"] = "Chinese",
        ["EN"] = "English",
        ["JA"] = "Japanese",
        ["KO"] = "Korean",
    };

    public static IReadOnlyDictionary<string, string> Target { get; } = new Dictionary<string, string>
    {
        ["ZH"] = "Chinese",
        ["EN"] = "English",
        ["JA"] = "Japanese",
        ["KO"] = "Korean",
    };

    // Backward-compatible alias used by older UI bindings.
    public static IReadOnlyDictionary<string, string> All => Source;
}
