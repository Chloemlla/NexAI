using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Auth;
using NexAI.Core.Chat;
using NexAI.Core.Settings;
using NexAI.Core.Tools;
using Windows.Storage.Pickers;
using Windows.ApplicationModel.DataTransfer;
using WinRT.Interop;

namespace NexAI.WinUI3.Views;

public sealed partial class ToolsPage : Page
{
    private readonly ISettingsStore _settingsStore;
    private readonly IChatStreamingClient _chatClient;
    private readonly IShortUrlClient _shortUrlClient;
    private readonly IArtifactsClient _artifactsClient;
    private readonly IImageGenerationClient _imageGenerationClient;
    private readonly IMediaToolService _mediaToolService;
    private readonly IAuthSessionStore _authSessionStore;
    private ToolDefinition? _selected;
    private string _query = string.Empty;

    public ToolsPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _chatClient = App.Current.Services.GetRequiredService<IChatStreamingClient>();
        _shortUrlClient = App.Current.Services.GetRequiredService<IShortUrlClient>();
        _artifactsClient = App.Current.Services.GetRequiredService<IArtifactsClient>();
        _imageGenerationClient = App.Current.Services.GetRequiredService<IImageGenerationClient>();
        _mediaToolService = App.Current.Services.GetRequiredService<IMediaToolService>();
        _authSessionStore = App.Current.Services.GetRequiredService<IAuthSessionStore>();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        RefreshTools();
    }

    private void RefreshTools()
    {
        var tools = ToolCatalog.All
            .Where(t =>
                string.IsNullOrWhiteSpace(_query) ||
                t.Title.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                t.Description.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                t.Category.Contains(_query, StringComparison.OrdinalIgnoreCase))
            .ToList();
        ToolsList.ItemsSource = tools;
        if (_selected is null && tools.Count > 0)
        {
            ToolsList.SelectedItem = tools[0];
        }
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _query = SearchBox.Text?.Trim() ?? string.Empty;
        RefreshTools();
    }

    private void ToolsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ToolsList.SelectedItem is not ToolDefinition tool)
        {
            return;
        }

        _selected = tool;
        ToolTitle.Text = tool.Title;
        ToolDescription.Text = $"{tool.Category} · {tool.Description}";
        ToolStatus.Text = tool.Kind switch
        {
            ToolKind.VideoCompress or ToolKind.VideoToAudio => "Input a local media path, or leave empty and pick a file on Run. Requires ffmpeg on PATH or NEXAI_FFMPEG.",
            ToolKind.ShortUrl => "Input a long http(s) URL. Uses api.mmp.cc short-link service.",
            ToolKind.Artifacts => "Input artifact content. Requires NexAI sign-in in Settings. Title can be first line prefixed with title:.",
            ToolKind.ImageGeneration => "Input an image prompt. Uses OpenAI-compatible /images/generations with chat fallback.",
            _ => "Ready.",
        };
    }

    private async void RunButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selected is null)
        {
            return;
        }

        var input = InputBox.Text ?? string.Empty;
        try
        {
            ToolStatus.Text = "Running…";
            OutputBox.Text = _selected.Kind switch
            {
                ToolKind.Base64 => RunBase64(input),
                ToolKind.DateTime => RunDateTime(input),
                ToolKind.Password => RunPassword(input),
                ToolKind.Translation => await RunTranslationAsync(input),
                ToolKind.ImageGeneration => await RunImageGenerationAsync(input),
                ToolKind.ShortUrl => await RunShortUrlAsync(input),
                ToolKind.Artifacts => await RunArtifactsAsync(input),
                ToolKind.VideoCompress => await RunMediaAsync(input, compress: true),
                ToolKind.VideoToAudio => await RunMediaAsync(input, compress: false),
                _ => input,
            };
            ToolStatus.Text = "Done.";
        }
        catch (Exception ex)
        {
            ToolStatus.Text = ex.Message;
        }
    }

    private void CopyButton_Click(object sender, RoutedEventArgs e)
    {
        var data = new DataPackage();
        data.SetText(OutputBox.Text ?? string.Empty);
        Clipboard.SetContent(data);
        ToolStatus.Text = "Output copied.";
    }

    private static string RunBase64(string input)
    {
        if (input.Trim().StartsWith("decode:", StringComparison.OrdinalIgnoreCase))
        {
            var payload = input.Trim()["decode:".Length..].Trim();
            return Encoding.UTF8.GetString(Convert.FromBase64String(payload));
        }

        return Convert.ToBase64String(Encoding.UTF8.GetBytes(input));
    }

    private static string RunDateTime(string input)
    {
        if (long.TryParse(input.Trim(), out var epoch))
        {
            var dt = epoch > 10_000_000_000
                ? DateTimeOffset.FromUnixTimeMilliseconds(epoch)
                : DateTimeOffset.FromUnixTimeSeconds(epoch);
            return string.Join(Environment.NewLine,
            [
                $"UTC: {dt.UtcDateTime:O}",
                $"Local: {dt.LocalDateTime:O}",
                $"Unix seconds: {dt.ToUnixTimeSeconds()}",
                $"Unix ms: {dt.ToUnixTimeMilliseconds()}",
            ]);
        }

        if (DateTime.TryParse(input, out var parsed))
        {
            var dto = new DateTimeOffset(parsed.ToUniversalTime());
            return string.Join(Environment.NewLine,
            [
                $"UTC: {dto.UtcDateTime:O}",
                $"Local: {dto.ToLocalTime():O}",
                $"Unix seconds: {dto.ToUnixTimeSeconds()}",
                $"Unix ms: {dto.ToUnixTimeMilliseconds()}",
            ]);
        }

        var now = DateTimeOffset.Now;
        return string.Join(Environment.NewLine,
        [
            "Could not parse input; showing now:",
            $"UTC: {now.UtcDateTime:O}",
            $"Local: {now.LocalDateTime:O}",
            $"Unix seconds: {now.ToUnixTimeSeconds()}",
        ]);
    }

    private static string RunPassword(string input)
    {
        var length = 16;
        if (int.TryParse(input.Trim(), out var parsed))
        {
            length = Math.Clamp(parsed, 8, 128);
        }

        const string alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+";
        var bytes = RandomNumberGenerator.GetBytes(length);
        var chars = bytes.Select(b => alphabet[b % alphabet.Length]).ToArray();
        return new string(chars);
    }

    private async Task<string> RunTranslationAsync(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return string.Empty;
        }

        var settings = _settingsStore.Current;
        var request = new ChatCompletionRequest
        {
            BaseUrl = settings.BaseUrl,
            ApiKey = settings.ApiKey,
            Model = settings.SelectedModel,
            Temperature = 0.2,
            MaxTokens = Math.Min(settings.MaxTokens, 2048),
            SystemPrompt = "Translate the user text to Chinese. Return only the translation.",
            Messages =
            [
                new ChatMessage { Role = ChatRoles.User, Content = input, Timestamp = DateTime.UtcNow },
            ],
        };

        var sb = new StringBuilder();
        await foreach (var delta in _chatClient.StreamAsync(request))
        {
            sb.Append(delta);
        }

        return sb.ToString();
    }

    private async Task<string> RunShortUrlAsync(string input)
    {
        var result = await _shortUrlClient.CreateAsync(input.Trim());
        return $"{result.ShortUrl}\n\nOriginal: {result.OriginalUrl}";
    }

    private async Task<string> RunArtifactsAsync(string input)
    {
        var settings = _settingsStore.Current;
        var session = _authSessionStore.Current;
        var title = "NexAI Artifact";
        var content = input;
        if (input.StartsWith("title:", StringComparison.OrdinalIgnoreCase))
        {
            var split = input.Split('\n', 2);
            title = split[0]["title:".Length..].Trim();
            content = split.Length > 1 ? split[1] : string.Empty;
        }

        var result = await _artifactsClient.CreateAsync(
            settings.BackendBaseUrl,
            session.AccessToken ?? string.Empty,
            title,
            content);
        return $"Created artifact\nShortId: {result.ShortId}\nURL: {result.Url}";
    }

    private async Task<string> RunImageGenerationAsync(string input)
    {
        var settings = _settingsStore.Current;
        var result = await _imageGenerationClient.GenerateAsync(
            settings.BaseUrl,
            settings.ApiKey,
            settings.SelectedModel,
            input);
        return string.Join(Environment.NewLine, result.ImageUrls);
    }

    private async Task<string> RunMediaAsync(string input, bool compress)
    {
        var path = input.Trim().Trim('"');
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            path = await PickMediaFileAsync() ?? string.Empty;
        }

        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            throw new InvalidOperationException("No media file selected.");
        }

        var result = compress
            ? await _mediaToolService.CompressVideoAsync(path)
            : await _mediaToolService.ExtractAudioAsync(path);

        if (!result.Success)
        {
            throw new InvalidOperationException(
                $"ffmpeg failed ({result.ExitCode}).\n{result.StdErr}".Trim());
        }

        return $"Output: {result.OutputPath}\nCommand: {result.Command}";
    }

    private async Task<string?> PickMediaFileAsync()
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".mp4");
        picker.FileTypeFilter.Add(".mkv");
        picker.FileTypeFilter.Add(".mov");
        picker.FileTypeFilter.Add(".avi");
        picker.FileTypeFilter.Add(".webm");
        picker.FileTypeFilter.Add("*");

        var hwnd = WindowNative.GetWindowHandle(App.Current.MainWindow);
        InitializeWithWindow.Initialize(picker, hwnd);
        var file = await picker.PickSingleFileAsync();
        return file?.Path;
    }
}
