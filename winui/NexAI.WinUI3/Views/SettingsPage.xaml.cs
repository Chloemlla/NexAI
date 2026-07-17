using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Settings;
using NexAI.WinUI3.Services;
using Windows.UI;

namespace NexAI.WinUI3.Views;

public sealed partial class SettingsPage : Page
{
    private readonly ISettingsStore _settingsStore;
    private readonly ThemeService _themeService;
    private bool _suppressThemeEvent;

    public SettingsPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _themeService = App.Current.Services.GetRequiredService<ThemeService>();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        LoadFromStore();
    }

    private void LoadFromStore()
    {
        var current = _settingsStore.Current;
        BaseUrlBox.Text = current.BaseUrl;
        ApiKeyBox.Password = current.ApiKey;
        ModelBox.Text = current.SelectedModel;
        TemperatureBox.Value = current.Temperature;
        MaxTokensBox.Value = current.MaxTokens;

        _suppressThemeEvent = true;
        ThemeBox.SelectedIndex = current.ThemeMode switch
        {
            AppThemeMode.Light => 1,
            AppThemeMode.Dark => 2,
            _ => 0,
        };
        _suppressThemeEvent = false;

        SetStatus("Loaded from local store.", isError: false);
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        SaveButton.IsEnabled = false;
        try
        {
            var draft = BuildDraftFromUi();
            var normalized = AppSettingsValidator.Normalize(draft);
            var error = AppSettingsValidator.Validate(normalized);
            if (error is not null)
            {
                SetStatus(error, isError: true);
                return;
            }

            await _settingsStore.SaveAsync(normalized);
            _themeService.Apply(normalized.ThemeMode);
            LoadFromStore();
            SetStatus("Settings saved.", isError: false);
        }
        catch (Exception ex)
        {
            SetStatus(ex.Message, isError: true);
        }
        finally
        {
            SaveButton.IsEnabled = true;
        }
    }

    private void ThemeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressThemeEvent)
        {
            return;
        }

        var mode = ReadThemeMode();
        _themeService.Apply(mode);
        SetStatus($"Theme preview: {mode}. Save to persist.", isError: false);
    }

    private AppSettings BuildDraftFromUi()
    {
        var temperature = double.IsNaN(TemperatureBox.Value) ? 0.7 : TemperatureBox.Value;
        var maxTokens = double.IsNaN(MaxTokensBox.Value)
            ? 2048
            : (int)Math.Clamp(Math.Round(MaxTokensBox.Value), 1, 128_000);

        return new AppSettings
        {
            BaseUrl = BaseUrlBox.Text ?? string.Empty,
            ApiKey = ApiKeyBox.Password ?? string.Empty,
            SelectedModel = ModelBox.Text ?? string.Empty,
            Temperature = temperature,
            MaxTokens = maxTokens,
            ThemeMode = ReadThemeMode(),
        };
    }

    private AppThemeMode ReadThemeMode()
    {
        if (ThemeBox.SelectedItem is ComboBoxItem item &&
            Enum.TryParse<AppThemeMode>(item.Tag?.ToString(), ignoreCase: true, out var mode))
        {
            return mode;
        }

        return AppThemeMode.System;
    }

    private void SetStatus(string message, bool isError)
    {
        StatusText.Text = message;
        var brushKey = isError
            ? "SystemFillColorCriticalBrush"
            : "TextFillColorSecondaryBrush";

        if (Application.Current.Resources.TryGetValue(brushKey, out var resource) &&
            resource is Brush brush)
        {
            StatusText.Foreground = brush;
            return;
        }

        StatusText.Foreground = new SolidColorBrush(
            isError ? Color.FromArgb(255, 196, 43, 28) : Color.FromArgb(255, 96, 96, 96));
    }
}
