using System.Diagnostics;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using NexAI.Core;
using NexAI.Core.Auth;
using NexAI.Core.Chat;
using NexAI.Core.Notes;
using NexAI.Core.Settings;
using NexAI.Core.Sync;
using NexAI.Core.Tools;
using NexAI.Infrastructure;
using NexAI.WinUI3.Services;
using NexAI.WinUI3.Views;

namespace NexAI.WinUI3;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
        UnhandledException += OnUnhandledException;
        LogStartup("App ctor complete");
    }

    public static new App Current => (App)Application.Current;
    public IServiceProvider Services { get; private set; } = null!;
    public Window MainWindow => _window ?? throw new InvalidOperationException("Main window is not ready.");

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Critical: show the window first. Awaiting storage loads before Activate()
        // can leave a live process with no UI if any startup I/O hangs or throws.
        try
        {
            LogStartup("OnLaunched begin");
            Services = BuildServices();
            LogStartup("DI ready");

            var themeService = Services.GetRequiredService<ThemeService>();

            // Create the shell outside DI resolve so a transient service fault
            // cannot leave a live process with no window.
            var mainWindow = CreateMainWindow();
            _window = mainWindow;
            LogStartup("MainWindow constructed");

            if (mainWindow.Content is FrameworkElement root)
            {
                try
                {
                    themeService.Attach(root);
                }
                catch (Exception ex)
                {
                    LogStartup("theme attach failed: " + ex);
                }
            }

            // Safe defaults until stores finish loading.
            try
            {
                themeService.Apply(AppThemeMode.System);
            }
            catch (Exception ex)
            {
                LogStartup("theme default apply failed: " + ex);
            }

            ShowAndActivate(mainWindow);
            LogStartup("MainWindow activated");

            // Load local state after the first frame is visible.
            // Fire-and-forget on the UI dispatcher so a hung store load cannot
            // stall the visible shell indefinitely.
            var dispatcher = mainWindow.DispatcherQueue;
            _ = dispatcher.TryEnqueue(async () =>
            {
                try
                {
                    var settingsStore = Services.GetRequiredService<ISettingsStore>();
                    var localization = Services.GetRequiredService<ILocalizationService>();
                    await LoadStartupStateAsync(settingsStore, themeService, localization).ConfigureAwait(true);
                    LogStartup("startup load complete");
                }
                catch (Exception ex)
                {
                    LogStartup("deferred startup load failed: " + ex);
                }
            });
        }
        catch (Exception ex)
        {
            LogStartup("OnLaunched fatal: " + ex);
            // Last-chance visible window so users are not left with a headless process.
            try
            {
                if (_window is null)
                {
                    _window = new Window
                    {
                        Title = "NexAI",
                        Content = new Microsoft.UI.Xaml.Controls.TextBlock
                        {
                            Text = "NexAI failed to start:\n" + ex.Message,
                            Margin = new Thickness(24),
                            TextWrapping = TextWrapping.WrapWholeWords,
                        },
                    };
                    ShowAndActivate(_window);
                }
                else
                {
                    ShowAndActivate(_window);
                }
            }
            catch (Exception fallbackEx)
            {
                LogStartup("fallback window failed: " + fallbackEx);
            }
        }
    }

    private MainWindow CreateMainWindow()
    {
        try
        {
            return new MainWindow();
        }
        catch (Exception ex)
        {
            LogStartup("MainWindow ctor failed: " + ex);
            throw;
        }
    }

    private static void ShowAndActivate(Window window)
    {
        try
        {
            window.AppWindow.Show();
        }
        catch (Exception ex)
        {
            LogStartup("AppWindow.Show failed: " + ex);
        }

        try
        {
            window.Activate();
        }
        catch (Exception ex)
        {
            LogStartup("Window.Activate failed: " + ex);
        }

        if (window is MainWindow mainWindow)
        {
            try
            {
                mainWindow.BringToForeground();
            }
            catch (Exception ex)
            {
                LogStartup("BringToForeground failed: " + ex);
            }
        }
    }

    private async Task LoadStartupStateAsync(
        ISettingsStore settingsStore,
        ThemeService themeService,
        ILocalizationService localization)
    {
        try
        {
            await Task.WhenAll(
                SafeLoadAsync("settings", () => settingsStore.LoadAsync()),
                SafeLoadAsync("conversations", () => Services.GetRequiredService<IConversationStore>().LoadAsync()),
                SafeLoadAsync("notes", () => Services.GetRequiredService<INotesStore>().LoadAsync()),
                SafeLoadAsync("auth", () => Services.GetRequiredService<IAuthSessionStore>().LoadAsync()),
                SafeLoadAsync("sync", () => Services.GetRequiredService<ISyncService>().LoadAsync()),
                SafeLoadAsync("translation-history", () => Services.GetRequiredService<ITranslationHistoryStore>().LoadAsync()),
                SafeLoadAsync("shorturl-history", () => Services.GetRequiredService<IShortUrlHistoryStore>().LoadAsync()),
                SafeLoadAsync("password-vault", () => Services.GetRequiredService<IPasswordVaultStore>().LoadAsync()))
                .ConfigureAwait(true);

            var settings = settingsStore.Current;
            try
            {
                localization.Apply(settings.Language);
            }
            catch (Exception ex)
            {
                LogStartup("localization apply failed: " + ex);
            }

            try
            {
                themeService.Apply(settings.ThemeMode);
            }
            catch (Exception ex)
            {
                LogStartup("theme apply failed: " + ex);
            }

            settingsStore.Changed += (_, _) =>
            {
                try { themeService.Apply(settingsStore.Current.ThemeMode); }
                catch (Exception ex) { LogStartup("theme changed failed: " + ex); }
            };
            settingsStore.Changed += (_, _) =>
            {
                try { localization.Apply(settingsStore.Current.Language); }
                catch (Exception ex) { LogStartup("language changed failed: " + ex); }
            };
        }
        catch (Exception ex)
        {
            LogStartup("LoadStartupStateAsync failed: " + ex);
        }
    }

    private static async Task SafeLoadAsync(string name, Func<Task> load)
    {
        try
        {
            await load().ConfigureAwait(false);
            LogStartup(name + " loaded");
        }
        catch (Exception ex)
        {
            LogStartup(name + " load failed: " + ex);
        }
    }

    private static ServiceProvider BuildServices()
    {
        var services = new ServiceCollection();
        services.AddNexAIInfrastructure();
        services.AddSingleton<ThemeService>();
        services.AddSingleton<ILocalizationService, LocalizationService>();
        services.AddSingleton<ChatSessionService>();
        return services.BuildServiceProvider();
    }

    private static void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        LogStartup("UnhandledException " + e.Exception);
        // Keep the process alive only for non-fatal UI exceptions; still log everything.
        e.Handled = true;
    }

    private static void LogStartup(string message)
    {
        try
        {
            AppPaths.EnsureRoot();
            var line = DateTimeOffset.Now.ToString("O") + " " + message + Environment.NewLine;
            File.AppendAllText(Path.Combine(AppPaths.RootDirectory, "startup.log"), line, Encoding.UTF8);
            Debug.WriteLine("[NexAI] " + message);
        }
        catch
        {
            // ignore logging failures
        }
    }
}
