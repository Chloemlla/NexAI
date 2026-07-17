namespace NexAI.Core.Chat;

public static class ChatRoles
{
    public const string User = "user";
    public const string Assistant = "assistant";
    public const string System = "system";
}

public sealed class ChatMessage
{
    public string Role { get; set; } = ChatRoles.User;
    public string Content { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public bool IsError { get; set; }

    public ChatMessage Clone() => new()
    {
        Role = Role,
        Content = Content,
        Timestamp = Timestamp,
        IsError = IsError,
    };
}

public sealed class Conversation
{
    public string Id { get; set; } = Guid.NewGuid().ToString("D");
    public string Title { get; set; } = "New chat";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public List<ChatMessage> Messages { get; set; } = [];

    public string Preview
    {
        get
        {
            var last = Messages.LastOrDefault(m => !string.IsNullOrWhiteSpace(m.Content));
            if (last is null)
            {
                return "No messages yet";
            }

            var text = last.Content.ReplaceLineEndings(" ").Trim();
            return text.Length <= 96 ? text : text[..96] + "…";
        }
    }

    public Conversation Clone() => new()
    {
        Id = Id,
        Title = Title,
        CreatedAt = CreatedAt,
        UpdatedAt = UpdatedAt,
        Messages = Messages.Select(m => m.Clone()).ToList(),
    };
}

public interface IConversationStore
{
    IReadOnlyList<Conversation> Conversations { get; }
    string? CurrentConversationId { get; }
    Conversation? CurrentConversation { get; }
    event EventHandler? Changed;

    Task LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(CancellationToken cancellationToken = default);
    Task<Conversation> CreateAsync(CancellationToken cancellationToken = default);
    Task SelectAsync(string conversationId, CancellationToken cancellationToken = default);
    Task DeleteAsync(string conversationId, CancellationToken cancellationToken = default);
    Task RenameAsync(string conversationId, string title, CancellationToken cancellationToken = default);
    Task AppendMessageAsync(
        string conversationId,
        ChatMessage message,
        CancellationToken cancellationToken = default);
}
