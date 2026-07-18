using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Chat;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed partial class TranslationToolPage : Page
{
    private readonly ITranslationClient _translationClient;
    private readonly ITranslationHistoryStore _historyStore;
    private TranslationServiceConfig? _config;
    private bool _busy;

    public TranslationToolPage()
    {
        InitializeComponent();
        _translationClient = App.Current.Services.GetRequiredService<ITranslationClient>();
        _historyStore = App.Current.Services.GetRequiredService<ITranslationHistoryStore>();

        foreach (var pair in TranslationLanguages.Source)
        {
            SourceLanguageBox.Items.Add(new ComboBoxItem { Content = pair.Value, Tag = pair.Key });
        }
        foreach (var pair in TranslationLanguages.Target)
        {
            TargetLanguageBox.Items.Add(new ComboBoxItem { Content = pair.Value, Tag = pair.Key });
        }

        SourceLanguageBox.SelectedIndex = 0; // auto
        TargetLanguageBox.SelectedIndex = 0; // ZH
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _historyStore.Changed += OnHistoryChanged;
        RefreshHistory();
        await RefreshConfigAsync();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _historyStore.Changed -= OnHistoryChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnHistoryChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshHistory);

    private void RefreshHistory() => HistoryList.ItemsSource = _historyStore.History;

    private async Task RefreshConfigAsync()
    {
        StatusText.Text = "Checking translation service…";
        try
        {
            _config = await _translationClient.GetConfigAsync();
            var enabled = _config.Enabled;
            ServiceWarningBar.IsOpen = !enabled;
            ServiceWarningBar.Title = enabled ? "Service ready" : "Service unavailable";
            ServiceWarningBar.Message = enabled
                ? "DeepLX public translation is available."
                : "Translation service is disabled or not configured.";
            TranslateButton.IsEnabled = enabled && !_busy;
            StatusText.Text = enabled ? "Service ready." : "Service unavailable.";
        }
        catch (Exception ex)
        {
            _config = null;
            ServiceWarningBar.IsOpen = true;
            ServiceWarningBar.Title = "Service check failed";
            ServiceWarningBar.Message = ex.Message;
            TranslateButton.IsEnabled = false;
            StatusText.Text = ex.Message;
        }
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

        if (_config?.Enabled == false)
        {
            StatusText.Text = "Translation service is unavailable.";
            return;
        }

        var source = ReadLanguage(SourceLanguageBox) ?? "auto";
        var target = ReadLanguage(TargetLanguageBox) ?? "ZH";
        _busy = true;
        TranslateButton.IsEnabled = false;
        StatusText.Text = "Translating…";
        try
        {
            var result = await _translationClient.TranslateAsync(source, target, text);
            ResultBox.Text = result.TranslatedText;
            AlternativesBox.Text = result.Alternatives.Count == 0
                ? string.Empty
                : string.Join(Environment.NewLine, result.Alternatives.Select((a, i) => $"{i + 1}. {a}"));
            await _historyStore.AddAsync(new TranslationRecord
            {
                SourceLanguage = result.SourceLang,
                TargetLanguage = result.TargetLang,
                SourceText = text,
                TranslatedText = result.TranslatedText,
                CreatedAt = DateTime.UtcNow,
            });
            StatusText.Text = $"{result.SourceLang} → {result.TargetLang}";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
        finally
        {
            _busy = false;
            TranslateButton.IsEnabled = _config?.Enabled != false;
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
        // Lumen target set does not include auto; map auto -> EN when swapping into target.
        var sourceCode = ReadLanguage(SourceLanguageBox) ?? "auto";
        var targetCode = ReadLanguage(TargetLanguageBox) ?? "ZH";
        SelectByTag(SourceLanguageBox, targetCode == "auto" ? "EN" : targetCode);
        SelectByTag(TargetLanguageBox, sourceCode == "auto" ? "EN" : sourceCode);

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

    private async void RefreshService_Click(object sender, RoutedEventArgs e)
        => await RefreshConfigAsync();

    private async void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        await _historyStore.ClearAsync();
        StatusText.Text = "History cleared.";
    }

    private static string? ReadLanguage(ComboBox box)
        => (box.SelectedItem as ComboBoxItem)?.Tag?.ToString();

    private static void SelectByTag(ComboBox box, string tag)
    {
        for (var i = 0; i < box.Items.Count; i++)
        {
            if (box.Items[i] is ComboBoxItem item &&
                string.Equals(item.Tag?.ToString(), tag, StringComparison.OrdinalIgnoreCase))
            {
                box.SelectedIndex = i;
                return;
            }
        }
    }
}
