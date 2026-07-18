using System.Diagnostics;
using System.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NexAI.Core.Navigation;
using Microsoft.Extensions.DependencyInjection;
using NexAI.Core;
using NexAI.WinUI3.Services;
using NexAI.Infrastructure.Security;
using Windows.Graphics;
using WinRT.Interop;

namespace NexAI.WinUI3.Views;

public sealed partial class MainWindow : Window
{
    private readonly ILocalizationService? _localization;
    private Microsoft.UI.Dispatching.DispatcherQueueTimer? _softSigHideTimer;

    public MainWindow()
    {
        // Keep constructor extremely thin. Previous builds died after DI ready
        // and before "MainWindow constructed", which points at XAML/chrome setup.
        Log("ctor begin");
        try
        {
            InitializeComponent();
            Log("InitializeComponent ok");
        }
        catch (Exception ex)
        {
            Log("InitializeComponent failed: " + ex);
            throw;
        }

        Title = "NexAI";

        try
        {
            AppWindow.Resize(new SizeInt32(1180, 780));
            Log("AppWindow.Resize ok");
        }
        catch (Exception ex)
        {
            Log("AppWindow.Resize failed: " + ex);
        }

        try
        {
            _localization = App.Current.Services.GetService<ILocalizationService>();
            if (_localization is not null)
            {
                _localization.LanguageChanged += (_, _) => ApplyLocalization();
            }
            Log("localization wired");
        }
        catch (Exception ex)
        {
            Log("localization resolve failed: " + ex);
        }

        try
        {
            NexaiSoftSigNotice.Raised += OnSoftSigNoticeRaised;
            Log("soft-sig wired");
        }
        catch (Exception ex)
        {
            Log("soft-sig subscribe failed: " + ex);
        }

        Log("ctor complete");
    }

    public void BringToForeground()
    {
        try
        {
            AppWindow.Show();
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] AppWindow.Show failed: " + ex);
        }

        try
        {
            Activate();
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] Activate failed: " + ex);
        }

        try
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            if (hwnd == IntPtr.Zero)
            {
                return;
            }

            // Restore if minimized and force Z-order for unpackaged launches where
            // Activate alone can leave a live process without a visible frame.
            NativeMethods.ShowWindow(hwnd, NativeMethods.SwRestore);
            NativeMethods.SetForegroundWindow(hwnd);
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] BringToForeground Win32 failed: " + ex);
        }
    }

    private void RootNavigation_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            ApplyLocalization();
            // Defer first navigation one tick so the shell finishes first layout.
            DispatcherQueue.TryEnqueue(() =>
            {
                try
                {
                    NavigateTo(AppPage.Chat);
                    if (RootNavigation.MenuItems.FirstOrDefault() is NavigationViewItem first)
                    {
                        RootNavigation.SelectedItem = first;
                    }
                }
                catch (Exception navEx)
                {
                    Log("deferred first navigation failed: " + navEx);
                    if (ContentFrame.Content is null)
                    {
                        ContentFrame.Content = new TextBlock
                        {
                            Margin = new Thickness(24),
                            TextWrapping = TextWrapping.WrapWholeWords,
                            Text = "NexAI shell loaded, but navigation failed:\n" + navEx.Message,
                        };
                    }
                }
            });
        }
        catch (Exception ex)
        {
            Log("RootNavigation_Loaded failed: " + ex);
            // Last resort content so the shell is never empty.
            if (ContentFrame.Content is null)
            {
                ContentFrame.Content = new TextBlock
                {
                    Margin = new Thickness(24),
                    TextWrapping = TextWrapping.WrapWholeWords,
                    Text = "NexAI shell loaded, but navigation failed:\n" + ex.Message,
                };
            }
        }
    }

    private void ApplyLocalization()
    {
        if (_localization is null)
        {
            Title = "NexAI";
            return;
        }

        try
        {
            Title = _localization.GetString("App.Name");
            foreach (var item in RootNavigation.MenuItems.OfType<NavigationViewItem>())
            {
                var nav = NavigationCatalog.FindByTag(item.Tag?.ToString());
                if (nav is null) continue;
                item.Content = _localization.GetString(nav.TitleKey);
            }
            SoftSigInfoBar.Title = _localization.GetString("SoftSig.Title");
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] ApplyLocalization failed: " + ex);
            Title = "NexAI";
        }
    }

    private void OnSoftSigNoticeRaised(object? sender, NexaiSoftSigNoticeEventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            SoftSigInfoBar.Title = _localization?.GetString("SoftSig.Title") ?? "Signature notice";
            SoftSigInfoBar.Message = e.Message;
            SoftSigInfoBar.IsOpen = true;

            _softSigHideTimer ??= DispatcherQueue.CreateTimer();
            _softSigHideTimer.Interval = TimeSpan.FromSeconds(5);
            _softSigHideTimer.IsRepeating = false;
            _softSigHideTimer.Tick -= SoftSigHideTimer_Tick;
            _softSigHideTimer.Tick += SoftSigHideTimer_Tick;
            _softSigHideTimer.Start();
        });
    }

    private void SoftSigHideTimer_Tick(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args)
    {
        SoftSigInfoBar.IsOpen = false;
    }

    private void RootNavigation_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;
        var destination = NavigationCatalog.FindByTag(item.Tag?.ToString())?.Page ?? AppPage.Chat;
        NavigateTo(destination);
    }

    private void NavigateTo(AppPage page)
    {
        try
        {
            var targetType = page switch
            {
                AppPage.Notes => typeof(NotesPage),
                AppPage.Tools => typeof(ToolsPage),
                AppPage.Settings => typeof(SettingsPage),
                _ => typeof(ChatPage),
            };

            if (ContentFrame.CurrentSourcePageType == targetType) return;
            ContentFrame.Navigate(targetType);
        }
        catch (Exception ex)
        {
            Log("NavigateTo(" + page + ") failed: " + ex);
            ContentFrame.Content = new TextBlock
            {
                Margin = new Thickness(24),
                TextWrapping = TextWrapping.WrapWholeWords,
                Text = "Failed to open page " + page + ":\n" + ex.Message,
            };
        }
    }

    private static void Log(string message)
    {
        try
        {
            AppPaths.EnsureRoot();
            var line = DateTimeOffset.Now.ToString("O") + " [MainWindow] " + message + Environment.NewLine;
            File.AppendAllText(Path.Combine(AppPaths.RootDirectory, "startup.log"), line, Encoding.UTF8);
            Debug.WriteLine("[NexAI][MainWindow] " + message);
        }
        catch
        {
            // ignore
        }
    }
}
