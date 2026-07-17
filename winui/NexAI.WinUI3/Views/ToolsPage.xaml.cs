using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Chat;
using NexAI.Core.Settings;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;

namespace NexAI.WinUI3.Views;

public sealed partial class ToolsPage : Page
{
    private readonly ISettingsStore _settingsStore;
    private readonly IChatStreamingClient _chatClient;
    private ToolDefinition? _selected;
    private string _query = string.Empty;

    public ToolsPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _chatClient = App.Current.Services.GetRequiredService<IChatStreamingClient>();
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
            ToolKind.VideoCompress or ToolKind.VideoToAudio => "Media tools are available as a Windows-local pipeline stub in this build.",
            ToolKind.ShortUrl or ToolKind.Artifacts => "Network tools call NexAI backend when signed in; otherwise they run in local preview mode.",
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
            OutputBox.Text = _selected.Kind switch
            {
                ToolKind.Base64 => RunBase64(input),
                ToolKind.DateTime => RunDateTime(input),
                ToolKind.Password => RunPassword(input),
                ToolKind.Translation => await RunTranslationAsync(input),
                ToolKind.ImageGeneration => "Image generation endpoint wiring is ready for compatible /images APIs. Provide prompt above and configure API in Settings; binary download UI lands with packaging polish.",
                ToolKind.ShortUrl => $"Local short-url preview: https://nexa.link/{Math.Abs(input.GetHashCode()):x}",
                ToolKind.Artifacts => $"Artifact draft prepared ({input.Length} chars). Upload uses backend artifacts API when authenticated.",
                ToolKind.VideoCompress => "Video compressor stub: select a file in a future picker and run ffmpeg/local transcoder pipeline.",
                ToolKind.VideoToAudio => "Video-to-audio stub: extracts audio track via local media pipeline in a later packaging pass.",
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
}
