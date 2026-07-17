using System.Text;
using NexAI.Core.Chat;
using NexAI.Core.Settings;

namespace NexAI.WinUI3.Services;

public sealed class ChatSessionService
{
    private readonly IConversationStore _conversationStore;
    private readonly ISettingsStore _settingsStore;
    private readonly IChatStreamingClient _chatClient;
    private CancellationTokenSource? _streamCts;
    private int _streamPersistCounter;

    public ChatSessionService(
        IConversationStore conversationStore,
        ISettingsStore settingsStore,
        IChatStreamingClient chatClient)
    {
        _conversationStore = conversationStore;
        _settingsStore = settingsStore;
        _chatClient = chatClient;
    }

    public bool IsStreaming => _streamCts is not null;

    public event EventHandler? StateChanged;

    public void Stop()
    {
        _streamCts?.Cancel();
    }

    public async Task SendAsync(string content, CancellationToken cancellationToken = default)
    {
        if (IsStreaming)
        {
            throw new InvalidOperationException("A response is already streaming.");
        }

        var text = content?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(text))
        {
            throw new InvalidOperationException("Message is empty.");
        }

        var settings = AppSettingsValidator.Normalize(_settingsStore.Current);
        var settingsError = AppSettingsValidator.Validate(settings);
        if (settingsError is not null)
        {
            throw new InvalidOperationException(settingsError);
        }

        if (string.IsNullOrWhiteSpace(settings.ApiKey))
        {
            throw new InvalidOperationException("API key is required in Settings.");
        }

        var conversation = _conversationStore.CurrentConversation;
        if (conversation is null)
        {
            conversation = await _conversationStore.CreateAsync(cancellationToken).ConfigureAwait(false);
        }

        await _conversationStore.AppendMessageAsync(
            conversation.Id,
            new ChatMessage
            {
                Role = ChatRoles.User,
                Content = text,
                Timestamp = DateTime.UtcNow,
            },
            persist: true,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var assistant = await _conversationStore.AppendMessageAsync(
            conversation.Id,
            new ChatMessage
            {
                Role = ChatRoles.Assistant,
                Content = string.Empty,
                Timestamp = DateTime.UtcNow,
            },
            persist: true,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _streamCts = linkedCts;
        _streamPersistCounter = 0;
        RaiseStateChanged();

        var buffer = new StringBuilder();
        try
        {
            var latest = _conversationStore.Conversations.First(c => c.Id == conversation.Id);
            var request = new ChatCompletionRequest
            {
                BaseUrl = settings.BaseUrl,
                ApiKey = settings.ApiKey,
                Model = settings.SelectedModel,
                Temperature = settings.Temperature,
                MaxTokens = settings.MaxTokens,
                SystemPrompt = settings.SystemPrompt,
                Messages = latest.Messages
                    .Where(m => m.Id != assistant.Id && !m.IsError)
                    .Select(m => m.Clone())
                    .ToList(),
            };

            await foreach (var delta in _chatClient.StreamAsync(request, linkedCts.Token).ConfigureAwait(false))
            {
                buffer.Append(delta);
                _streamPersistCounter++;
                var shouldPersist = _streamPersistCounter % 12 == 0;
                await _conversationStore.UpdateMessageAsync(
                    conversation.Id,
                    assistant.Id,
                    buffer.ToString(),
                    isError: false,
                    persist: shouldPersist,
                    cancellationToken: linkedCts.Token).ConfigureAwait(false);
            }

            var finalContent = buffer.ToString();
            if (string.IsNullOrWhiteSpace(finalContent))
            {
                await _conversationStore.UpdateMessageAsync(
                    conversation.Id,
                    assistant.Id,
                    "Error: Empty response from API",
                    isError: true,
                    persist: true,
                    cancellationToken: CancellationToken.None).ConfigureAwait(false);
            }
            else
            {
                await _conversationStore.UpdateMessageAsync(
                    conversation.Id,
                    assistant.Id,
                    finalContent,
                    isError: false,
                    persist: true,
                    cancellationToken: CancellationToken.None).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException) when (linkedCts.IsCancellationRequested)
        {
            var partial = buffer.ToString();
            if (string.IsNullOrWhiteSpace(partial))
            {
                partial = "Generation stopped.";
            }
            else if (!partial.EndsWith("[stopped]", StringComparison.Ordinal))
            {
                partial += "\n\n[stopped]";
            }

            await _conversationStore.UpdateMessageAsync(
                conversation.Id,
                assistant.Id,
                partial,
                isError: false,
                persist: true,
                cancellationToken: CancellationToken.None).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            var message = string.IsNullOrWhiteSpace(buffer.ToString())
                ? $"Error: {ex.Message}"
                : $"{buffer}\n\nError: {ex.Message}";

            await _conversationStore.UpdateMessageAsync(
                conversation.Id,
                assistant.Id,
                message,
                isError: true,
                persist: true,
                cancellationToken: CancellationToken.None).ConfigureAwait(false);
        }
        finally
        {
            _streamCts = null;
            RaiseStateChanged();
        }
    }

    private void RaiseStateChanged() => StateChanged?.Invoke(this, EventArgs.Empty);
}

