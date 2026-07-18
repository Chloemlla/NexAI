using System.Diagnostics;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
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
using WinRT.Interop;

namespace NexAI.WinUI3;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        // Capture hard failures that bypass XAML UnhandledException.
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            LogStartup("AppDomain.UnhandledException " + e.ExceptionObject);
        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            LogStartup("TaskScheduler.UnobservedTaskException " + e.Exception);
            e.SetObserved();
        };

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

            // Always surface a window before any heavy init. Startup log shows the
            // previous build reached "DI ready" then vanished, so first paint must
            // not depend on MainWindow XAML succeeding.
            _window = CreateBootstrapWindow("NexAI is starting…");
            ShowAndActivate(_window);
            LogStartup("bootstrap window activated");

            Services = BuildServices();
            LogStartup("DI ready");

            ThemeService themeService;
            try
            {
                themeService = Services.GetRequiredService<ThemeService>();
                LogStartup("ThemeService resolved");
            }
            catch (Exception ex)
            {
                LogStartup("ThemeService resolve failed: " + ex);
                ShowFatal(_window, "Theme service failed:\n" + ex.Message);
                return;
            }

            try
            {
                if (_window.Content is FrameworkElement bootstrapRoot)
                {
                    themeService.Attach(bootstrapRoot);
                }

                themeService.Apply(AppThemeMode.System);
                LogStartup("theme default applied");
            }
            catch (Exception ex)
            {
                LogStartup("theme default apply failed: " + ex);
            }

            MainWindow? mainWindow = null;
            try
            {
                LogStartup("MainWindow ctor begin");
                mainWindow = new MainWindow();
                LogStartup("MainWindow constructed");
            }
            catch (Exception ex)
            {
                LogStartup("MainWindow ctor failed: " + ex);
                ShowFatal(_window, "Main window failed to create:\n" + ex.Message);
                return;
            }

            // Prefer activating the real shell as its own top-level window. Keep the
            // bootstrap window only as a fallback surface if that fails.
            try
            {
                if (mainWindow.Content is FrameworkElement shellRoot)
                {
                    themeService.Attach(shellRoot);
                }

                ShowAndActivate(mainWindow);
                LogStartup("MainWindow activated");

                var bootstrap = _window;
                _window = mainWindow;
                try
                {
                    bootstrap?.Close();
                    LogStartup("bootstrap window closed");
                }
                catch (Exception closeEx)
                {
                    LogStartup("bootstrap close failed: " + closeEx);
                }
            }
            catch (Exception ex)
            {
                LogStartup("MainWindow activate failed: " + ex);
                ShowFatal(_window!, "Main window failed to activate:\n" + ex.Message);
                return;
            }

            // Load local state after the first frame is visible.
            // Fire-and-forget on the UI dispatcher so a hung store load cannot
            // stall the visible shell indefinitely.
            var dispatcher = _window.DispatcherQueue;
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
            try
            {
                if (_window is null)
                {
                    _window = CreateBootstrapWindow("NexAI failed to start:\n" + ex.Message);
                    ShowAndActivate(_window);
                }
                else
                {
                    ShowFatal(_window, "NexAI failed to start:\n" + ex.Message);
                }
            }
            catch (Exception fallbackEx)
            {
                LogStartup("fallback window failed: " + fallbackEx);
                try
                {
                    NativeMethods.MessageBox(
                        IntPtr.Zero,
                        "NexAI failed to start:\n" + ex.Message,
                        "NexAI",
                        NativeMethods.MbOk | NativeMethods.MbIconError);
                }
                catch
                {
                    // ignore
                }
            }
        }
    }

    private static Window CreateBootstrapWindow(string message)
    {
        return new Window
        {
            Title = "NexAI",
            Content = new TextBlock
            {
                Text = message,
                Margin = new Thickness(24),
                TextWrapping = TextWrapping.WrapWholeWords,
            },
        };
    }

    private static void ShowFatal(Window window, string message)
    {
        try
        {
            window.Title = "NexAI";
            window.Content = new TextBlock
            {
                Text = message,
                Margin = new Thickness(24),
                TextWrapping = TextWrapping.WrapWholeWords,
            };
            ShowAndActivate(window);
        }
        catch (Exception ex)
        {
            LogStartup("ShowFatal failed: " + ex);
            try
            {
                NativeMethods.MessageBox(
                    IntPtr.Zero,
                    message,
                    "NexAI",
                    NativeMethods.MbOk | NativeMethods.MbIconError);
            }
            catch
            {
                // ignore
            }
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

        try
        {
            var hwnd = WindowNative.GetWindowHandle(window);
            if (hwnd != IntPtr.Zero)
            {
                NativeMethods.ShowWindow(hwnd, NativeMethods.SwRestore);
                NativeMethods.SetForegroundWindow(hwnd);
            }
        }
        catch (Exception ex)
        {
            LogStartup("BringToForeground failed: " + ex);
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
