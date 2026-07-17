using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace NexAI.Core.Notes;

public sealed class Note
{
    public string Id { get; set; } = Guid.NewGuid().ToString("D");
    public string Title { get; set; } = "Untitled Note";
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastViewedAt { get; set; }
    public bool IsStarred { get; set; }

    [JsonIgnore]
    public string Preview
    {
        get
        {
            var text = BodyContent.ReplaceLineEndings(" ").Trim();
            return text.Length <= 120 ? text : text[..120] + "…";
        }
    }

    [JsonIgnore]
    public IReadOnlyList<string> Tags => NoteMarkup.ExtractTags(Content);

    [JsonIgnore]
    public string BodyContent => NoteMarkup.StripFrontmatter(Content);

    public Note Clone() => new()
    {
        Id = Id,
        Title = Title,
        Content = Content,
        CreatedAt = CreatedAt,
        UpdatedAt = UpdatedAt,
        LastViewedAt = LastViewedAt,
        IsStarred = IsStarred,
    };

    public Dictionary<string, object?> ToJsonMap() => new()
    {
        ["id"] = Id,
        ["title"] = Title,
        ["content"] = Content,
        ["createdAt"] = CreatedAt.ToString("O"),
        ["updatedAt"] = UpdatedAt.ToString("O"),
        ["lastViewedAt"] = LastViewedAt?.ToString("O"),
        ["isStarred"] = IsStarred,
    };

    public static Note FromJsonMap(Dictionary<string, object?> map)
    {
        static string S(object? v) => v?.ToString() ?? string.Empty;
        static DateTime D(object? v) => DateTime.TryParse(v?.ToString(), out var dt) ? dt.ToUniversalTime() : DateTime.UtcNow;
        static bool B(object? v) => v is bool b ? b : bool.TryParse(v?.ToString(), out var parsed) && parsed;

        return new Note
        {
            Id = string.IsNullOrWhiteSpace(S(map.GetValueOrDefault("id"))) ? Guid.NewGuid().ToString("D") : S(map.GetValueOrDefault("id")),
            Title = string.IsNullOrWhiteSpace(S(map.GetValueOrDefault("title"))) ? "Untitled Note" : S(map.GetValueOrDefault("title")),
            Content = S(map.GetValueOrDefault("content")),
            CreatedAt = D(map.GetValueOrDefault("createdAt")),
            UpdatedAt = D(map.GetValueOrDefault("updatedAt")),
            LastViewedAt = map.TryGetValue("lastViewedAt", out var lv) && lv is not null ? D(lv) : null,
            IsStarred = B(map.GetValueOrDefault("isStarred")),
        };
    }
}

public static partial class NoteMarkup
{
    [GeneratedRegex(@"(?<!\w)#([\w\u4e00-\u9fff][\w\u4e00-\u9fff/]*)(?!\w)")]
    private static partial Regex TagRegex();

    [GeneratedRegex(@"\[\[([^\]]+)\]\]")]
    private static partial Regex WikiRegex();

    [GeneratedRegex(@"^---\s*\n([\s\S]*?)\n---", RegexOptions.Multiline)]
    private static partial Regex FrontmatterRegex();

    public static string StripFrontmatter(string content)
    {
        var match = FrontmatterRegex().Match(content ?? string.Empty);
        return match.Success ? content![match.Length..].TrimStart() : content ?? string.Empty;
    }

    public static IReadOnlyList<string> ExtractTags(string content)
    {
        var body = StripFrontmatter(content ?? string.Empty);
        var noCode = Regex.Replace(body, "```[\\s\\S]*?```", string.Empty);
        return TagRegex().Matches(noCode)
            .Select(m => m.Groups[1].Value)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public static IReadOnlyList<string> ExtractWikiTargets(string content)
    {
        var body = StripFrontmatter(content ?? string.Empty);
        var noCode = Regex.Replace(body, "```[\\s\\S]*?```", string.Empty);
        return WikiRegex().Matches(noCode)
            .Select(m =>
            {
                var raw = m.Groups[1].Value;
                var pipe = raw.IndexOf('|');
                if (pipe >= 0) raw = raw[..pipe];
                var hash = raw.IndexOf('#');
                if (hash >= 0) raw = raw[..hash];
                return raw.Trim();
            })
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}

public interface INotesStore
{
    IReadOnlyList<Note> Notes { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(CancellationToken cancellationToken = default);
    Task<Note> CreateAsync(string? title = null, string? content = null, CancellationToken cancellationToken = default);
    Task UpdateAsync(Note note, CancellationToken cancellationToken = default);
    Task DeleteAsync(string noteId, CancellationToken cancellationToken = default);
    Task ToggleStarAsync(string noteId, CancellationToken cancellationToken = default);
    Task ReplaceAllAsync(IEnumerable<Note> notes, CancellationToken cancellationToken = default);
}
