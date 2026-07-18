using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Chat;
using NexAI.Core.Settings;
using NexAI.WinUI3.Controls;
using NexAI.WinUI3.Services;
using Windows.System;

namespace NexAI.WinUI3.Views;

public sealed partial class ChatPage : Page
{
    private readonly IConversationStore _conversationStore;
    private readonly ChatSessionService _chatSession;
    private readonly ISettingsStore _settingsStore;
    private readonly ILocalizationService _localization;
    private string _searchQuery = string.Empty;
    private bool _isBusy;
    private bool _advancedRenderingEnabled = true;

    public ChatPage()
    {
        InitializeComponent();
        _conversationStore = App.Current.Services.GetRequiredService<IConversationStore>();
        _chatSession = App.Current.Services.GetRequiredService<ChatSessionService>();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => DispatcherQueue.TryEnqueue(RefreshUi);
        _advancedRenderingEnabled = _settingsStore.Current.AdvancedRenderingEnabled;
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _conversationStore.Changed += OnConversationStoreChanged;
        _chatSession.StateChanged += OnChatSessionStateChanged;
        _settingsStore.Changed += OnSettingsChanged;
        _advancedRenderingEnabled = _settingsStore.Current.AdvancedRenderingEnabled;
        ApplyStaticLocalization();
        RefreshUi();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _conversationStore.Changed -= OnConversationStoreChanged;
        _chatSession.StateChanged -= OnChatSessionStateChanged;
        _settingsStore.Changed -= OnSettingsChanged;
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

    private void OnSettingsChanged(object? sender, EventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            var next = _settingsStore.Current.AdvancedRenderingEnabled;
            if (next == _advancedRenderingEnabled)
            {
                return;
            }

            _advancedRenderingEnabled = next;
            // Force rebind so MarkdownMessagePresenter picks up EnableAdvanced.
            var current = _conversationStore.CurrentConversation;
            MessageList.ItemsSource = null;
            MessageList.ItemsSource = current?.Messages ?? [];
        });
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
            await ShowInfoAsync(_localization.GetString("Chat.CreateFailedTitle"), ex.Message);
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
            await ShowInfoAsync(_localization.GetString("Chat.StreamingTitle"), _localization.GetString("Chat.StreamingSwitchBody"));
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
            await ShowInfoAsync(_localization.GetString("Chat.OpenFailedTitle"), ex.Message);
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
            await ShowInfoAsync(_localization.GetString("Chat.StreamingTitle"), _localization.GetString("Chat.StreamingDeleteBody"));
            return;
        }

        var dialog = new ContentDialog
        {
            Title = _localization.GetString("Chat.DeleteDialogTitle"),
            Content = _localization.GetString("Chat.DeleteDialogBody"),
            PrimaryButtonText = _localization.GetString("Common.Delete"),
            CloseButtonText = _localization.GetString("Common.Cancel"),
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
            await ShowInfoAsync(_localization.GetString("Chat.DeleteFailedTitle"), ex.Message);
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
        await TrySendAsync();
    }

    private async void ComposerBox_PreviewKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key != VirtualKey.Enter)
        {
            return;
        }

        var shiftDown = (Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift)
            & Windows.UI.Core.CoreVirtualKeyStates.Down) == Windows.UI.Core.CoreVirtualKeyStates.Down;
        if (shiftDown)
        {
            // Shift+Enter inserts a newline (TextBox default with AcceptsReturn).
            return;
        }

        // Enter sends; mark handled so AcceptsReturn does not insert a newline.
        e.Handled = true;
        await TrySendAsync();
    }

    private void MessageList_ContainerContentChanging(ListViewBase sender, ContainerContentChangingEventArgs args)
    {
        if (args.InRecycleQueue)
        {
            return;
        }

        ApplyAdvancedRendering(args.ItemContainer?.ContentTemplateRoot);
        if (args.ItemContainer?.ContentTemplateRoot is null)
        {
            args.RegisterUpdateCallback((_, e) =>
            {
                ApplyAdvancedRendering(e.ItemContainer?.ContentTemplateRoot);
            });
        }
    }

    private void ApplyAdvancedRendering(DependencyObject? root)
    {
        switch (root)
        {
            case MarkdownMessagePresenter presenter:
                presenter.EnableAdvanced = _advancedRenderingEnabled;
                break;
            case Border border when border.Child is MarkdownMessagePresenter nested:
                nested.EnableAdvanced = _advancedRenderingEnabled;
                break;
        }
    }

    private async Task TrySendAsync()
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

        // Clear only after the session accepts the message (streaming starts).
        // Early validation failures throw before StateChanged / IsStreaming.
        var draft = ComposerBox.Text ?? string.Empty;
        var cleared = false;

        void OnStateChanged(object? sender, EventArgs e)
        {
            if (cleared || !_chatSession.IsStreaming)
            {
                return;
            }

            cleared = true;
            DispatcherQueue.TryEnqueue(() =>
            {
                if (string.Equals(ComposerBox.Text, draft, StringComparison.Ordinal) ||
                    string.Equals(ComposerBox.Text?.Trim(), content, StringComparison.Ordinal))
                {
                    ComposerBox.Text = string.Empty;
                    UpdateComposerState();
                }
            });
        }

        _chatSession.StateChanged += OnStateChanged;
        try
        {
            await _chatSession.SendAsync(content);
            if (!cleared)
            {
                ComposerBox.Text = string.Empty;
                UpdateComposerState();
            }
        }
        catch (Exception ex)
        {
            if (!cleared)
            {
                // Validation / accept failed — keep (or restore) the draft.
                ComposerBox.Text = draft;
                UpdateComposerState();
            }

            await ShowInfoAsync(_localization.GetString("Chat.SendFailedTitle"), ex.Message);
        }
        finally
        {
            _chatSession.StateChanged -= OnStateChanged;
            RefreshUi();
        }
    }

    private void StopButton_Click(object sender, RoutedEventArgs e)
    {
        _chatSession.Stop();
        UpdateComposerState();
    }


    private void ApplyStaticLocalization()
    {
        ConversationsTitleText.Text = _localization.GetString("Chat.Conversations");
        NewChatButton.Content = _localization.GetString("Common.New");
        SearchBox.PlaceholderText = _localization.GetString("Chat.SearchPlaceholder");
        ConversationEmptyTitleText.Text = _localization.GetString("Chat.EmptyTitle");
        ConversationEmptySubtitleText.Text = _localization.GetString("Chat.EmptySubtitle");
        DeleteCurrentButton.Content = _localization.GetString("Common.Delete");
        MessageEmptyTitleText.Text = _localization.GetString("Chat.NoMessagesTitle");
        MessageEmptySubtitleText.Text = _localization.GetString("Chat.NoMessagesSubtitle");
        ComposerBox.PlaceholderText = _localization.GetString("Chat.ComposerPlaceholder");
        SendButton.Content = _localization.GetString("Common.Send");
        StopButton.Content = _localization.GetString("Common.Stop");
    }

    private void RefreshUi()
    {
        ApplyStaticLocalization();
        var all = _conversationStore.Conversations;
        var filtered = FilterConversations(all).ToList();
        var current = _conversationStore.CurrentConversation;

        ConversationList.ItemsSource = filtered;
        ConversationCountText.Text = all.Count == 1
            ? _localization.GetString("Chat.Count", all.Count)
            : _localization.GetString("Chat.CountPlural", all.Count);
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

        CurrentTitleText.Text = current?.Title ?? _localization.GetString("Chat.TitleFallback");
        CurrentMetaText.Text = current is null
            ? _localization.GetString("Chat.SelectOrCreate")
            : _chatSession.IsStreaming
                ? _localization.GetString("Chat.MetaStreaming", current.Messages.Count)
                : current.Messages.Count == 1
                    ? _localization.GetString("Chat.MetaLocal", current.Messages.Count)
                    : _localization.GetString("Chat.MetaLocalPlural", current.Messages.Count);
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
            ? _localization.GetString("Chat.HintStreaming")
            : hasText
                ? _localization.GetString("Chat.HintEnterToSend")
                : _localization.GetString("Chat.HintReady");
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
            CloseButtonText = _localization.GetString("Common.OK"),
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}
