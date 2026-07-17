using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Chat;
using NexAI.WinUI3.Services;

namespace NexAI.WinUI3.Views;

public sealed partial class ChatPage : Page
{
    private readonly IConversationStore _conversationStore;
    private readonly ChatSessionService _chatSession;
    private string _searchQuery = string.Empty;
    private bool _isBusy;

    public ChatPage()
    {
        InitializeComponent();
        _conversationStore = App.Current.Services.GetRequiredService<IConversationStore>();
        _chatSession = App.Current.Services.GetRequiredService<ChatSessionService>();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _conversationStore.Changed += OnConversationStoreChanged;
        _chatSession.StateChanged += OnChatSessionStateChanged;
        RefreshUi();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _conversationStore.Changed -= OnConversationStoreChanged;
        _chatSession.StateChanged -= OnChatSessionStateChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnConversationStoreChanged(object? sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(RefreshUi);
    }

    private void OnChatSessionStateChanged(object? sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(RefreshUi);
    }

    private async void NewChatButton_Click(object sender, RoutedEventArgs e)
    {
        if (_isBusy || _chatSession.IsStreaming)
        {
            return;
        }

        _isBusy = true;
        NewChatButton.IsEnabled = false;
        try
        {
            await _conversationStore.CreateAsync();
            SearchBox.Text = string.Empty;
            _searchQuery = string.Empty;
        }
        catch (Exception ex)
        {
            await ShowInfoAsync("Could not create conversation", ex.Message);
        }
        finally
        {
            _isBusy = false;
            NewChatButton.IsEnabled = true;
            RefreshUi();
        }
    }

    private async void ConversationList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (_chatSession.IsStreaming)
        {
            await ShowInfoAsync("Streaming in progress", "Stop the current response before switching chats.");
            return;
        }

        if (e.ClickedItem is not Conversation conversation)
        {
            return;
        }

        try
        {
            await _conversationStore.SelectAsync(conversation.Id);
        }
        catch (Exception ex)
        {
            await ShowInfoAsync("Could not open conversation", ex.Message);
        }
    }

    private async void DeleteConversationButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string conversationId)
        {
            return;
        }

        await DeleteConversationAsync(conversationId);
    }

    private async void DeleteCurrentButton_Click(object sender, RoutedEventArgs e)
    {
        var currentId = _conversationStore.CurrentConversationId;
        if (currentId is null)
        {
            return;
        }

        await DeleteConversationAsync(currentId);
    }

    private async Task DeleteConversationAsync(string conversationId)
    {
        if (_chatSession.IsStreaming &&
            string.Equals(conversationId, _conversationStore.CurrentConversationId, StringComparison.Ordinal))
        {
            await ShowInfoAsync("Streaming in progress", "Stop the current response before deleting this chat.");
            return;
        }

        var dialog = new ContentDialog
        {
            Title = "Delete conversation",
            Content = "This removes the local conversation permanently.",
            PrimaryButtonText = "Delete",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };

        var result = await dialog.ShowAsync();
        if (result != ContentDialogResult.Primary)
        {
            return;
        }

        try
        {
            await _conversationStore.DeleteAsync(conversationId);
        }
        catch (Exception ex)
        {
            await ShowInfoAsync("Could not delete conversation", ex.Message);
        }
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _searchQuery = SearchBox.Text?.Trim() ?? string.Empty;
        RefreshUi();
    }

    private void ComposerBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        UpdateComposerState();
    }

    private async void SendButton_Click(object sender, RoutedEventArgs e)
    {
        if (_chatSession.IsStreaming)
        {
            return;
        }

        var content = ComposerBox.Text?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(content))
        {
            return;
        }

        ComposerBox.Text = string.Empty;
        UpdateComposerState();

        try
        {
            await _chatSession.SendAsync(content);
        }
        catch (Exception ex)
        {
            await ShowInfoAsync("Could not send message", ex.Message);
        }
        finally
        {
            RefreshUi();
        }
    }

    private void StopButton_Click(object sender, RoutedEventArgs e)
    {
        _chatSession.Stop();
        UpdateComposerState();
    }

    private void RefreshUi()
    {
        var all = _conversationStore.Conversations;
        var filtered = FilterConversations(all).ToList();
        var current = _conversationStore.CurrentConversation;

        ConversationList.ItemsSource = filtered;
        ConversationCountText.Text = $"{all.Count} chat{(all.Count == 1 ? string.Empty : "s")}";
        ConversationEmptyState.Visibility =
            filtered.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

        if (current is not null)
        {
            var match = filtered.FirstOrDefault(c => c.Id == current.Id);
            ConversationList.SelectedItem = match;
        }
        else
        {
            ConversationList.SelectedItem = null;
        }

        CurrentTitleText.Text = current?.Title ?? "Chat";
        CurrentMetaText.Text = current is null
            ? "Select or create a conversation."
            : _chatSession.IsStreaming
                ? $"{current.Messages.Count} messages · streaming"
                : $"{current.Messages.Count} message{(current.Messages.Count == 1 ? string.Empty : "s")} · local store";
        DeleteCurrentButton.IsEnabled = current is not null && !_chatSession.IsStreaming;

        var messages = current?.Messages ?? [];
        MessageList.ItemsSource = messages;
        MessageEmptyState.Visibility =
            current is null || messages.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

        if (messages.Count > 0)
        {
            MessageList.ScrollIntoView(messages[^1]);
        }

        UpdateComposerState();
    }

    private void UpdateComposerState()
    {
        var hasText = !string.IsNullOrWhiteSpace(ComposerBox.Text);
        var streaming = _chatSession.IsStreaming;

        SendButton.Visibility = streaming ? Visibility.Collapsed : Visibility.Visible;
        StopButton.Visibility = streaming ? Visibility.Visible : Visibility.Collapsed;
        SendButton.IsEnabled = !streaming && hasText;
        StopButton.IsEnabled = streaming;
        ComposerBox.IsEnabled = !streaming;
        NewChatButton.IsEnabled = !streaming && !_isBusy;

        ComposerHintText.Text = streaming
            ? "Streaming..."
            : hasText
                ? "Press Send"
                : "Ready";
    }

    private IEnumerable<Conversation> FilterConversations(IReadOnlyList<Conversation> source)
    {
        if (string.IsNullOrWhiteSpace(_searchQuery))
        {
            return source;
        }

        return source.Where(conversation =>
        {
            var haystack = $"{conversation.Title}\n{conversation.Preview}".ToLowerInvariant();
            return haystack.Contains(_searchQuery.ToLowerInvariant(), StringComparison.Ordinal);
        });
    }

    private async Task ShowInfoAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}
