using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;
using Windows.System;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed partial class ShortUrlToolPage : Page
{
    private readonly IShortUrlClient _shortUrlClient;
    private readonly IShortUrlHistoryStore _historyStore;
    private string? _resultUrl;

    public ShortUrlToolPage()
    {
        InitializeComponent();
        _shortUrlClient = App.Current.Services.GetRequiredService<IShortUrlClient>();
        _historyStore = App.Current.Services.GetRequiredService<IShortUrlHistoryStore>();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _historyStore.Changed += OnHistoryChanged;
        RefreshHistory();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _historyStore.Changed -= OnHistoryChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnHistoryChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshHistory);

    private void RefreshHistory()
    {
        HistoryList.ItemsSource = _historyStore.History;
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (Frame?.CanGoBack == true) Frame.GoBack();
    }

    private async void CreateButton_Click(object sender, RoutedEventArgs e)
    {
        var target = UrlBox.Text?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(target))
        {
            StatusText.Text = "Enter a target URL.";
            return;
        }

        CreateButton.IsEnabled = false;
        StatusText.Text = "Creating short link…";
        try
        {
            var result = await _shortUrlClient.CreateAsync(target);
            _resultUrl = result.ShortUrl;
            ResultBox.Text = result.ShortUrl;
            OpenButton.IsEnabled = !string.IsNullOrWhiteSpace(_resultUrl);
            await _historyStore.AddAsync(new ShortUrlRecord
            {
                OriginalUrl = result.OriginalUrl,
                ShortUrl = result.ShortUrl,
                CreatedAt = DateTime.UtcNow,
            });
            StatusText.Text = "Short link created.";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
        finally
        {
            CreateButton.IsEnabled = true;
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

        UrlBox.Text = await view.GetTextAsync();
    }

    private void ClearButton_Click(object sender, RoutedEventArgs e)
    {
        UrlBox.Text = string.Empty;
        ResultBox.Text = string.Empty;
        _resultUrl = null;
        OpenButton.IsEnabled = false;
        StatusText.Text = string.Empty;
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(ResultBox.Text)) return;
        var data = new DataPackage();
        data.SetText(ResultBox.Text);
        Clipboard.SetContent(data);
        StatusText.Text = "Short URL copied.";
    }

    private async void OpenButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_resultUrl) ||
            !Uri.TryCreate(_resultUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            StatusText.Text = "Only http(s) results can be opened.";
            return;
        }

        await Launcher.LaunchUriAsync(uri);
    }

    private async void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        await _historyStore.ClearAsync();
        StatusText.Text = "History cleared.";
    }
}
