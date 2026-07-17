using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Auth;
using NexAI.Core.Migration;
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
    private readonly IFlutterDataMigrator _migrator;
    private bool _suppressThemeEvent;

    public SettingsPage()
    {
        InitializeComponent();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _themeService = App.Current.Services.GetRequiredService<ThemeService>();
        _authStore = App.Current.Services.GetRequiredService<IAuthSessionStore>();
        _authClient = App.Current.Services.GetRequiredService<IAuthClient>();
        _syncService = App.Current.Services.GetRequiredService<ISyncService>();
        _migrator = App.Current.Services.GetRequiredService<IFlutterDataMigrator>();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _authStore.Changed += OnAuthChanged;
        _syncService.Changed += OnSyncChanged;
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
        SetStatus("Loaded from local store.", false);
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var draft = BuildDraft();
            await _settingsStore.SaveAsync(draft);
            _themeService.Apply(draft.ThemeMode);
            LoadFromStore();
            SetStatus("Settings saved.", false);
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
        SetStatus($"Theme preview: {ReadThemeMode()}. Save to persist.", false);
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
            SyncStatusText.Text = "Recovery key exported into the field above.";
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
            SyncStatusText.Text = "Recovery key imported.";
            RefreshSync();
        }
        catch (Exception ex)
        {
            SyncStatusText.Text = ex.Message;
        }
    }

    private async void MigrateButton_Click(object sender, RoutedEventArgs e)
    {
        var result = await _migrator.TryMigrateAsync();
        MigrationStatusText.Text = result.Message;
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
            BackendBaseUrl = BackendBaseUrlBox.Text ?? string.Empty,
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
            ? $"Signed in as {session.DisplayName ?? session.Username ?? session.Email ?? "user"}."
            : "Not signed in.";
    }

    private void RefreshSync()
    {
        var state = _syncService.State;
        SyncStatusText.Text = state.Status switch
        {
            SyncStatus.Uploading => "Uploading encrypted snapshot…",
            SyncStatus.Downloading => "Downloading encrypted snapshot…",
            SyncStatus.Success => $"Last sync success at {state.LastSyncedAt?.ToLocalTime():g}. Key {state.RecoveryKeyHint}",
            SyncStatus.Error => state.ErrorMessage ?? "Sync error",
            _ => $"Idle. Key {state.RecoveryKeyHint ?? "(none)"}",
        };
    }

    private void SetStatus(string message, bool isError)
    {
        StatusText.Text = message;
        StatusText.Foreground = new SolidColorBrush(
            isError ? Color.FromArgb(255, 196, 43, 28) : Color.FromArgb(255, 96, 96, 96));
    }
}
