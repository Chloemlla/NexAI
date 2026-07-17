namespace NexAI.Core.Chat;

public static class ChatRoles
{
    public const string User = "user";
    public const string Assistant = "assistant";
    public const string System = "system";
}

public sealed class ChatMessage
{
    public string Id { get; set; } = Guid.NewGuid().ToString("D");
    public string Role { get; set; } = ChatRoles.User;
    public string Content { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public bool IsError { get; set; }

    public ChatMessage Clone() => new()
    {
        Id = string.IsNullOrWhiteSpace(Id) ? Guid.NewGuid().ToString("D") : Id,
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
            if (last is null) return "No messages yet";
            var text = last.Content.ReplaceLineEndings(" ").Trim();
            return text.Length <= 96 ? text : text[..96] + "…";
        }
    }

    public Conversation Clone() => new()
    {
        Id = string.IsNullOrWhiteSpace(Id) ? Guid.NewGuid().ToString("D") : Id,
        Title = string.IsNullOrWhiteSpace(Title) ? "New chat" : Title,
        CreatedAt = CreatedAt == default ? DateTime.UtcNow : CreatedAt,
        UpdatedAt = UpdatedAt == default ? DateTime.UtcNow : UpdatedAt,
        Messages = (Messages ?? []).Select(m => m.Clone()).ToList(),
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
    Task ReplaceAllAsync(
        IEnumerable<Conversation> conversations,
        string? currentConversationId = null,
        CancellationToken cancellationToken = default);
    Task<ChatMessage> AppendMessageAsync(
        string conversationId,
        ChatMessage message,
        bool persist = true,
        CancellationToken cancellationToken = default);
    Task UpdateMessageAsync(
        string conversationId,
        string messageId,
        string content,
        bool isError = false,
        bool persist = true,
        CancellationToken cancellationToken = default);
}

public sealed class ChatCompletionRequest
{
    public required string BaseUrl { get; init; }
    public required string ApiKey { get; init; }
    public required string Model { get; init; }
    public required double Temperature { get; init; }
    public required int MaxTokens { get; init; }
    public string SystemPrompt { get; init; } = string.Empty;
    public required IReadOnlyList<ChatMessage> Messages { get; init; }
}

public interface IChatStreamingClient
{
    IAsyncEnumerable<string> StreamAsync(
        ChatCompletionRequest request,
        CancellationToken cancellationToken = default);
}
