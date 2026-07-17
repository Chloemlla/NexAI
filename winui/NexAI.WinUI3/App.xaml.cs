using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using NexAI.Core.Chat;
using NexAI.Core.Settings;
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
    }

    public static new App Current => (App)Application.Current;

    public IServiceProvider Services { get; private set; } = null!;

    public Window MainWindow =>
        _window ?? throw new InvalidOperationException("Main window is not ready.");

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        Services = BuildServices();

        var settingsStore = Services.GetRequiredService<ISettingsStore>();
        var conversationStore = Services.GetRequiredService<IConversationStore>();
        await Task.WhenAll(
            settingsStore.LoadAsync(),
            conversationStore.LoadAsync());

        var themeService = Services.GetRequiredService<ThemeService>();
        _window = Services.GetRequiredService<MainWindow>();

        if (_window.Content is FrameworkElement root)
        {
            themeService.Attach(root);
        }

        themeService.Apply(settingsStore.Current.ThemeMode);
        settingsStore.Changed += (_, _) =>
        {
            themeService.Apply(settingsStore.Current.ThemeMode);
        };

        _window.Activate();
    }

    private static ServiceProvider BuildServices()
    {
        var services = new ServiceCollection();
        services.AddNexAIInfrastructure();
        services.AddSingleton<ThemeService>();
        services.AddSingleton<ChatSessionService>();
        services.AddSingleton<MainWindow>();
        return services.BuildServiceProvider();
    }

    private static void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        System.Diagnostics.Debug.WriteLine(
            $"UnhandledException {e.Exception.GetType().Name}: {e.Exception.Message}\n{e.Exception.StackTrace}");
        e.Handled = true;
    }
}
