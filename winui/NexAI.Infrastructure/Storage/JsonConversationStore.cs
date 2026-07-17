using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Chat;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonConversationStore : IConversationStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private List<Conversation> _conversations = [];
    private string? _currentConversationId;

    public IReadOnlyList<Conversation> Conversations
    {
        get
        {
            lock (_gate)
            {
                return _conversations.Select(c => c.Clone()).ToList();
            }
        }
    }

    public string? CurrentConversationId
    {
        get
        {
            lock (_gate)
            {
                return _currentConversationId;
            }
        }
    }

    public Conversation? CurrentConversation
    {
        get
        {
            lock (_gate)
            {
                return FindCurrentUnlocked()?.Clone();
            }
        }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        var path = AppPaths.ConversationsFilePath;
        if (!File.Exists(path))
        {
            lock (_gate)
            {
                _conversations = [];
                _currentConversationId = null;
            }

            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        await using var stream = File.OpenRead(path);
        var document = await JsonSerializer
            .DeserializeAsync<ConversationDocument>(stream, SerializerOptions, cancellationToken)
            .ConfigureAwait(false);

        lock (_gate)
        {
            _conversations = (document?.Conversations ?? [])
                .Select(Normalize)
                .OrderByDescending(c => c.UpdatedAt)
                .ToList();
            _currentConversationId = document?.CurrentConversationId;
            if (_currentConversationId is null ||
                _conversations.All(c => c.Id != _currentConversationId))
            {
                _currentConversationId = _conversations.FirstOrDefault()?.Id;
            }
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task SaveAsync(CancellationToken cancellationToken = default)
    {
        ConversationDocument snapshot;
        lock (_gate)
        {
            snapshot = new ConversationDocument
            {
                CurrentConversationId = _currentConversationId,
                Conversations = _conversations.Select(c => c.Clone()).ToList(),
            };
        }

        AppPaths.EnsureRoot();
        var path = AppPaths.ConversationsFilePath;
        var tempPath = path + ".tmp";

        await using (var stream = File.Create(tempPath))
        {
            await JsonSerializer
                .SerializeAsync(stream, snapshot, SerializerOptions, cancellationToken)
                .ConfigureAwait(false);
        }

        File.Copy(tempPath, path, overwrite: true);
        File.Delete(tempPath);
    }

    public async Task<Conversation> CreateAsync(CancellationToken cancellationToken = default)
    {
        var conversation = new Conversation
        {
            Id = Guid.NewGuid().ToString("D"),
            Title = "New chat",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Messages = [],
        };

        lock (_gate)
        {
            _conversations.Insert(0, conversation);
            _currentConversationId = conversation.Id;
        }

        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
        return conversation.Clone();
    }

    public async Task SelectAsync(string conversationId, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(conversationId);

        lock (_gate)
        {
            if (_conversations.All(c => c.Id != conversationId))
            {
                throw new InvalidOperationException("Conversation was not found.");
            }

            if (string.Equals(_currentConversationId, conversationId, StringComparison.Ordinal))
            {
                return;
            }

            _currentConversationId = conversationId;
        }

        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task DeleteAsync(string conversationId, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(conversationId);

        lock (_gate)
        {
            var index = _conversations.FindIndex(c => c.Id == conversationId);
            if (index < 0)
            {
                return;
            }

            _conversations.RemoveAt(index);
            if (string.Equals(_currentConversationId, conversationId, StringComparison.Ordinal))
            {
                _currentConversationId = _conversations.ElementAtOrDefault(Math.Min(index, _conversations.Count - 1))?.Id;
            }
        }

        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task RenameAsync(
        string conversationId,
        string title,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(conversationId);
        var cleanTitle = string.IsNullOrWhiteSpace(title) ? "New chat" : title.Trim();

        lock (_gate)
        {
            var conversation = _conversations.FirstOrDefault(c => c.Id == conversationId)
                ?? throw new InvalidOperationException("Conversation was not found.");
            conversation.Title = cleanTitle;
            conversation.UpdatedAt = DateTime.UtcNow;
            ResortUnlocked();
        }

        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task<ChatMessage> AppendMessageAsync(
        string conversationId,
        ChatMessage message,
        bool persist = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(conversationId);
        ArgumentNullException.ThrowIfNull(message);

        ChatMessage stored;
        lock (_gate)
        {
            var conversation = _conversations.FirstOrDefault(c => c.Id == conversationId)
                ?? throw new InvalidOperationException("Conversation was not found.");

            stored = message.Clone();
            if (string.IsNullOrWhiteSpace(stored.Id))
            {
                stored.Id = Guid.NewGuid().ToString("D");
            }

            conversation.Messages.Add(stored.Clone());
            conversation.UpdatedAt = DateTime.UtcNow;
            if (conversation.Title is "New chat" or "新对话" &&
                string.Equals(stored.Role, ChatRoles.User, StringComparison.OrdinalIgnoreCase) &&
                !string.IsNullOrWhiteSpace(stored.Content))
            {
                var title = stored.Content.ReplaceLineEndings(" ").Trim();
                conversation.Title = title.Length <= 32 ? title : title[..32] + "…";
            }

            ResortUnlocked();
        }

        if (persist)
        {
            await SaveAsync(cancellationToken).ConfigureAwait(false);
        }

        Changed?.Invoke(this, EventArgs.Empty);
        return stored.Clone();
    }

    public async Task UpdateMessageAsync(
        string conversationId,
        string messageId,
        string content,
        bool isError = false,
        bool persist = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(conversationId);
        ArgumentException.ThrowIfNullOrWhiteSpace(messageId);

        lock (_gate)
        {
            var conversation = _conversations.FirstOrDefault(c => c.Id == conversationId)
                ?? throw new InvalidOperationException("Conversation was not found.");
            var message = conversation.Messages.FirstOrDefault(m => m.Id == messageId)
                ?? throw new InvalidOperationException("Message was not found.");

            message.Content = content ?? string.Empty;
            message.IsError = isError;
            conversation.UpdatedAt = DateTime.UtcNow;
            ResortUnlocked();
        }

        if (persist)
        {
            await SaveAsync(cancellationToken).ConfigureAwait(false);
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    private Conversation? FindCurrentUnlocked()
    {
        if (_currentConversationId is null)
        {
            return null;
        }

        return _conversations.FirstOrDefault(c => c.Id == _currentConversationId);
    }

    private void ResortUnlocked()
    {
        _conversations = _conversations
            .OrderByDescending(c => c.UpdatedAt)
            .ToList();
    }

    private static Conversation Normalize(Conversation conversation)
    {
        var clone = conversation.Clone();
        if (string.IsNullOrWhiteSpace(clone.Id))
        {
            clone.Id = Guid.NewGuid().ToString("D");
        }

        if (string.IsNullOrWhiteSpace(clone.Title))
        {
            clone.Title = "New chat";
        }

        if (clone.CreatedAt == default)
        {
            clone.CreatedAt = DateTime.UtcNow;
        }

        if (clone.UpdatedAt == default)
        {
            clone.UpdatedAt = clone.CreatedAt;
        }

        clone.Messages ??= [];
        foreach (var message in clone.Messages)
        {
            if (string.IsNullOrWhiteSpace(message.Id))
            {
                message.Id = Guid.NewGuid().ToString("D");
            }
        }

        return clone;
    }

    private sealed class ConversationDocument
    {
        public string? CurrentConversationId { get; set; }
        public List<Conversation> Conversations { get; set; } = [];
    }
}
