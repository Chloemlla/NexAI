using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Auth;
using NexAI.Core.Settings;
using NexAI.Core.Sync;
using NexAI.WinUI3.Services;
using Windows.UI;

namespace NexAI.WinUI3.Views;

public sealed partial class SettingsPage : Page
{
    private readonly ISettingsStore _settingsStore;
    private readonly ThemeService _themeService;
    private readonly IAuthSessionStore _authStore;
    private readonly IAuthClient _authClient;
    private readonly ISyncService _syncService;
    private readonly ILocalizationService _localization;
    private bool _suppressThemeEvent;
    private bool _suppressLanguageEvent;

    public SettingsPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _themeService = App.Current.Services.GetRequiredService<ThemeService>();
        _authStore = App.Current.Services.GetRequiredService<IAuthSessionStore>();
        _authClient = App.Current.Services.GetRequiredService<IAuthClient>();
        _syncService = App.Current.Services.GetRequiredService<ISyncService>();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => DispatcherQueue.TryEnqueue(ApplyLocalization);
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _authStore.Changed += OnAuthChanged;
        _syncService.Changed += OnSyncChanged;
        ApplyLocalization();
        LoadFromStore();
        RefreshAccount();
        RefreshSync();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _authStore.Changed -= OnAuthChanged;
        _syncService.Changed -= OnSyncChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnAuthChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshAccount);
    private void OnSyncChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshSync);

    private void LoadFromStore()
    {
        var current = _settingsStore.Current;
        BaseUrlBox.Text = current.BaseUrl;
        ApiKeyBox.Password = current.ApiKey;
        ModelBox.Text = current.SelectedModel;
        SystemPromptBox.Text = current.SystemPrompt;
        TemperatureBox.Value = current.Temperature;
        MaxTokensBox.Value = current.MaxTokens;
        BackendBaseUrlBox.Text = current.BackendBaseUrl;
        VertexApiKeyBox.Password = current.VertexApiKey;
        SyncEnabledToggle.IsOn = current.SyncEnabled;
        AdvancedRenderingToggle.IsOn = current.AdvancedRenderingEnabled;
        WebDavServerBox.Text = current.WebDavServer;
        WebDavUserBox.Text = current.WebDavUser;
        WebDavPasswordBox.Password = current.WebDavPassword;
        UpstashUrlBox.Text = current.UpstashUrl;
        UpstashTokenBox.Password = current.UpstashToken;

        SyncMethodBox.SelectedIndex = current.SyncMethod switch
        {
            SyncBackendKind.WebDAV => 1,
            SyncBackendKind.UpStash => 2,
            _ => 0,
        };

        _suppressThemeEvent = true;
        ThemeBox.SelectedIndex = current.ThemeMode switch
        {
            AppThemeMode.Light => 1,
            AppThemeMode.Dark => 2,
            _ => 0,
        };
        _suppressThemeEvent = false;

        _suppressLanguageEvent = true;
        LanguageBox.SelectedIndex = current.Language switch
        {
            AppLanguage.English => 1,
            AppLanguage.ChineseSimplified => 2,
            _ => 0,
        };
        _suppressLanguageEvent = false;

        SetStatus(_localization.GetString("Settings.Loaded"), false);
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var draft = BuildDraft();
            await _settingsStore.SaveAsync(draft);
            _themeService.Apply(draft.ThemeMode);
            _localization.Apply(draft.Language);
            LoadFromStore();
            SetStatus(_localization.GetString("Settings.Saved"), false);
        }
        catch (Exception ex)
        {
            SetStatus(ex.Message, true);
        }
    }

    private void ThemeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressThemeEvent) return;
        _themeService.Apply(ReadThemeMode());
        SetStatus(_localization.GetString("Settings.ThemePreview", ReadThemeMode()), false);
    }

    private void LanguageBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressLanguageEvent) return;
        var language = ReadLanguage();
        _localization.Apply(language);
        SetStatus(_localization.GetString("Language.Changed", _localization.GetString(LanguageKey(language))), false);
    }

    private async void SignInButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var backend = BackendBaseUrlBox.Text?.Trim() ?? string.Empty;
            var session = await _authClient.LoginAsync(
                backend,
                LoginIdentifierBox.Text?.Trim() ?? string.Empty,
                LoginPasswordBox.Password ?? string.Empty);
            await _authStore.SaveAsync(session);
            LoginPasswordBox.Password = string.Empty;
            RefreshAccount();
        }
        catch (Exception ex)
        {
            AccountStatusText.Text = ex.Message;
        }
    }

    private async void SignOutButton_Click(object sender, RoutedEventArgs e)
    {
        var session = _authStore.Current;
        if (!string.IsNullOrWhiteSpace(session.AccessToken))
        {
            await _authClient.LogoutAsync(BackendBaseUrlBox.Text?.Trim() ?? string.Empty, session.AccessToken!);
        }
        await _authStore.ClearAsync();
        RefreshAccount();
    }

    private async void UploadSyncButton_Click(object sender, RoutedEventArgs e)
    {
        await SaveSilentAsync();
        await _syncService.UploadAsync();
        RefreshSync();
    }

    private async void DownloadSyncButton_Click(object sender, RoutedEventArgs e)
    {
        await SaveSilentAsync();
        await _syncService.DownloadAsync();
        RefreshSync();
    }

    private async void ExportKeyButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            RecoveryKeyBox.Text = await _syncService.ExportRecoveryKeyAsync();
            SyncStatusText.Text = _localization.GetString("Settings.Sync.KeyExported");
        }
        catch (Exception ex)
        {
            SyncStatusText.Text = ex.Message;
        }
    }

    private async void ImportKeyButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await _syncService.ImportRecoveryKeyAsync(RecoveryKeyBox.Text ?? string.Empty);
            SyncStatusText.Text = _localization.GetString("Settings.Sync.KeyImported");
            RefreshSync();
        }
        catch (Exception ex)
        {
            SyncStatusText.Text = ex.Message;
        }
    }


    private async Task SaveSilentAsync()
    {
        try
        {
            await _settingsStore.SaveAsync(BuildDraft());
        }
        catch
        {
            // Keep current values if validation fails; sync methods will report.
        }
    }

    private AppSettings BuildDraft()
    {
        return new AppSettings
        {
            BaseUrl = BaseUrlBox.Text ?? string.Empty,
            ApiKey = ApiKeyBox.Password ?? string.Empty,
            SelectedModel = ModelBox.Text ?? string.Empty,
            SystemPrompt = SystemPromptBox.Text ?? string.Empty,
            Temperature = double.IsNaN(TemperatureBox.Value) ? 0.7 : TemperatureBox.Value,
            MaxTokens = double.IsNaN(MaxTokensBox.Value) ? 2048 : (int)Math.Clamp(Math.Round(MaxTokensBox.Value), 1, 128_000),
            ThemeMode = ReadThemeMode(),
            Language = ReadLanguage(),
            BackendBaseUrl = BackendBaseUrlBox.Text ?? string.Empty,
            VertexApiKey = VertexApiKeyBox.Password ?? string.Empty,
            SyncEnabled = SyncEnabledToggle.IsOn,
            SyncMethod = ReadSyncMethod(),
            WebDavServer = WebDavServerBox.Text ?? string.Empty,
            WebDavUser = WebDavUserBox.Text ?? string.Empty,
            WebDavPassword = WebDavPasswordBox.Password ?? string.Empty,
            UpstashUrl = UpstashUrlBox.Text ?? string.Empty,
            UpstashToken = UpstashTokenBox.Password ?? string.Empty,
            AdvancedRenderingEnabled = AdvancedRenderingToggle.IsOn,
            NotesAutoSave = true,
        };
    }

    private AppThemeMode ReadThemeMode()
    {
        if (ThemeBox.SelectedItem is ComboBoxItem item &&
            Enum.TryParse<AppThemeMode>(item.Tag?.ToString(), true, out var mode))
        {
            return mode;
        }
        return AppThemeMode.System;
    }

    private AppLanguage ReadLanguage()
    {
        if (LanguageBox.SelectedItem is ComboBoxItem item &&
            Enum.TryParse<AppLanguage>(item.Tag?.ToString(), true, out var language))
        {
            return language;
        }

        return AppLanguage.System;
    }

    private static string LanguageKey(AppLanguage language) => language switch
    {
        AppLanguage.English => "Language.English",
        AppLanguage.ChineseSimplified => "Language.ChineseSimplified",
        _ => "Language.System",
    };

    private void ApplyLocalization()
    {
        SettingsTitleText.Text = _localization.GetString("Settings.Title");
        SettingsSubtitleText.Text = _localization.GetString("Settings.Subtitle");
        SaveButton.Content = _localization.GetString("Common.Save");

        ApiSectionTitle.Text = _localization.GetString("Settings.Section.Api");
        BaseUrlBox.Header = _localization.GetString("Settings.BaseUrl");
        ApiKeyBox.Header = _localization.GetString("Settings.ApiKey");
        ModelBox.Header = _localization.GetString("Settings.Model");
        SystemPromptBox.Header = _localization.GetString("Settings.SystemPrompt");
        TemperatureBox.Header = _localization.GetString("Settings.Temperature");
        MaxTokensBox.Header = _localization.GetString("Settings.MaxTokens");
        VertexApiKeyBox.Header = "Vertex AI API Key (AI Translation)";

        AppearanceSectionTitle.Text = _localization.GetString("Settings.Section.Appearance");
        LanguageBox.Header = _localization.GetString("Language.Header");
        ThemeBox.Header = _localization.GetString("Settings.Theme");
        AdvancedRenderingToggle.Header = _localization.GetString("Settings.AdvancedRendering");

        if (LanguageBox.Items[0] is ComboBoxItem langSystem) langSystem.Content = _localization.GetString("Language.System");
        if (LanguageBox.Items[1] is ComboBoxItem langEn) langEn.Content = _localization.GetString("Language.English");
        if (LanguageBox.Items[2] is ComboBoxItem langZh) langZh.Content = _localization.GetString("Language.ChineseSimplified");

        if (ThemeBox.Items[0] is ComboBoxItem themeSystem) themeSystem.Content = _localization.GetString("Settings.Theme.System");
        if (ThemeBox.Items[1] is ComboBoxItem themeLight) themeLight.Content = _localization.GetString("Settings.Theme.Light");
        if (ThemeBox.Items[2] is ComboBoxItem themeDark) themeDark.Content = _localization.GetString("Settings.Theme.Dark");

        AccountSectionTitle.Text = _localization.GetString("Settings.Section.Account");
        BackendBaseUrlBox.Header = _localization.GetString("Settings.BackendBaseUrl");
        LoginIdentifierBox.Header = _localization.GetString("Settings.EmailUsername");
        LoginPasswordBox.Header = _localization.GetString("Settings.Password");
        SignInButton.Content = _localization.GetString("Common.SignIn");
        SignOutButton.Content = _localization.GetString("Common.SignOut");

        SyncSectionTitle.Text = _localization.GetString("Settings.Section.Sync");
        SyncEnabledToggle.Header = _localization.GetString("Settings.EnableSync");
        SyncMethodBox.Header = _localization.GetString("Settings.SyncMethod");
        WebDavServerBox.Header = _localization.GetString("Settings.WebDavServer");
        WebDavUserBox.Header = _localization.GetString("Settings.WebDavUser");
        WebDavPasswordBox.Header = _localization.GetString("Settings.WebDavPassword");
        UpstashUrlBox.Header = _localization.GetString("Settings.UpstashUrl");
        UpstashTokenBox.Header = _localization.GetString("Settings.UpstashToken");
        ExportKeyButton.Content = _localization.GetString("Settings.ExportRecoveryKey");
        ImportKeyButton.Content = _localization.GetString("Settings.ImportRecoveryKey");
        RecoveryKeyBox.Header = _localization.GetString("Settings.ImportRecoveryKeyBox");
        UploadSyncButton.Content = _localization.GetString("Common.Upload");
        DownloadSyncButton.Content = _localization.GetString("Common.Download");
        if (SyncMethodBox.Items[0] is ComboBoxItem syncNexai) syncNexai.Content = _localization.GetString("Settings.Sync.NexAI");
        if (SyncMethodBox.Items[1] is ComboBoxItem syncWebdav) syncWebdav.Content = _localization.GetString("Settings.Sync.WebDAV");
        if (SyncMethodBox.Items[2] is ComboBoxItem syncUpstash) syncUpstash.Content = _localization.GetString("Settings.Sync.UpStash");
    }

    private SyncBackendKind ReadSyncMethod()
    {
        if (SyncMethodBox.SelectedItem is ComboBoxItem item &&
            Enum.TryParse<SyncBackendKind>(item.Tag?.ToString(), true, out var method))
        {
            return method;
        }
        return SyncBackendKind.NexAI;
    }

    private void RefreshAccount()
    {
        var session = _authStore.Current;
        AccountStatusText.Text = session.IsAuthenticated
            ? _localization.GetString("Settings.SignedInAs", session.DisplayName ?? session.Username ?? session.Email ?? "user")
            : _localization.GetString("Settings.NotSignedIn");
    }

    private void RefreshSync()
    {
        var state = _syncService.State;
        SyncStatusText.Text = state.Status switch
        {
            SyncStatus.Uploading => _localization.GetString("Settings.Sync.Uploading"),
            SyncStatus.Downloading => _localization.GetString("Settings.Sync.Downloading"),
            SyncStatus.Success => _localization.GetString(
                "Settings.Sync.Success",
                state.LastSyncedAt?.ToLocalTime().ToString("g") ?? "-",
                state.RecoveryKeyHint ?? _localization.GetString("Settings.Sync.KeyNone")),
            SyncStatus.Error => state.ErrorMessage ?? _localization.GetString("Settings.Sync.Error"),
            _ => _localization.GetString(
                "Settings.Sync.Idle",
                state.RecoveryKeyHint ?? _localization.GetString("Settings.Sync.KeyNone")),
        };
    }

    private void SetStatus(string message, bool isError)
    {
        StatusText.Text = message;
        StatusText.Foreground = new SolidColorBrush(
            isError ? Color.FromArgb(255, 196, 43, 28) : Color.FromArgb(255, 96, 96, 96));
    }
}
