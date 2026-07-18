using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Settings;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed partial class TranslationToolPage : Page
{
    private readonly ISettingsStore _settingsStore;
    private readonly ITranslationClient _translationClient;
    private readonly ITranslationHistoryStore _historyStore;

    public TranslationToolPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _translationClient = App.Current.Services.GetRequiredService<ITranslationClient>();
        _historyStore = App.Current.Services.GetRequiredService<ITranslationHistoryStore>();

        foreach (var pair in TranslationLanguages.All)
        {
            SourceLanguageBox.Items.Add(new ComboBoxItem { Content = pair.Value, Tag = pair.Key });
            TargetLanguageBox.Items.Add(new ComboBoxItem { Content = pair.Value, Tag = pair.Key });
        }

        SourceLanguageBox.SelectedIndex = 0;
        TargetLanguageBox.SelectedIndex = 1;
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _historyStore.Changed += OnHistoryChanged;
        RefreshKeyState();
        RefreshHistory();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _historyStore.Changed -= OnHistoryChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnHistoryChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshHistory);

    private void RefreshHistory() => HistoryList.ItemsSource = _historyStore.History;

    private void RefreshKeyState()
    {
        var hasKey = !string.IsNullOrWhiteSpace(_settingsStore.Current.VertexApiKey);
        KeyWarningBar.IsOpen = !hasKey;
        TranslateButton.IsEnabled = hasKey;
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (Frame?.CanGoBack == true) Frame.GoBack();
    }

    private async void TranslateButton_Click(object sender, RoutedEventArgs e)
    {
        var text = SourceBox.Text?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(text))
        {
            StatusText.Text = "Enter source text.";
            return;
        }

        if (text.Length > ToolInputLimits.MaxTranslationInputChars)
        {
            StatusText.Text = $"Text is too long. Keep it under {ToolInputLimits.MaxTranslationInputChars} characters.";
            return;
        }

        var source = ReadLanguage(SourceLanguageBox) ?? "en";
        var target = ReadLanguage(TargetLanguageBox) ?? "zh-CN";
        TranslateButton.IsEnabled = false;
        StatusText.Text = "Translating…";
        try
        {
            var result = await _translationClient.TranslateAsync(
                _settingsStore.Current.VertexApiKey,
                source,
                target,
                text);
            ResultBox.Text = result;
            await _historyStore.AddAsync(new TranslationRecord
            {
                SourceLanguage = source,
                TargetLanguage = target,
                SourceText = text,
                TranslatedText = result,
                CreatedAt = DateTime.UtcNow,
            });
            StatusText.Text = "Done.";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
        finally
        {
            RefreshKeyState();
        }
    }

    private async void PasteButton_Click(object sender, RoutedEventArgs e)
    {
        var view = Clipboard.GetContent();
        if (!view.Contains(StandardDataFormats.Text))
        {
            StatusText.Text = "Clipboard is empty.";
            return;
        }

        SourceBox.Text = await view.GetTextAsync();
    }

    private void SwapButton_Click(object sender, RoutedEventArgs e)
    {
        var sourceIndex = SourceLanguageBox.SelectedIndex;
        SourceLanguageBox.SelectedIndex = TargetLanguageBox.SelectedIndex;
        TargetLanguageBox.SelectedIndex = sourceIndex;

        var sourceText = SourceBox.Text;
        SourceBox.Text = ResultBox.Text;
        ResultBox.Text = sourceText;
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(ResultBox.Text)) return;
        var data = new DataPackage();
        data.SetText(ResultBox.Text);
        Clipboard.SetContent(data);
        StatusText.Text = "Translation copied.";
    }

    private async void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        await _historyStore.ClearAsync();
        StatusText.Text = "History cleared.";
    }

    private static string? ReadLanguage(ComboBox box)
        => (box.SelectedItem as ComboBoxItem)?.Tag?.ToString();
}
