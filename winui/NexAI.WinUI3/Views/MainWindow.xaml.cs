using System.Diagnostics;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using NexAI.Core.Navigation;
using Microsoft.Extensions.DependencyInjection;
using NexAI.WinUI3.Services;
using NexAI.Infrastructure.Security;
using Windows.Graphics;
using WinRT.Interop;

namespace NexAI.WinUI3.Views;

public sealed partial class MainWindow : Window
{
    private const int SwRestore = 9;

    private readonly ILocalizationService? _localization;
    private Microsoft.UI.Dispatching.DispatcherQueueTimer? _softSigHideTimer;

    public MainWindow()
    {
        InitializeComponent();

        try
        {
            _localization = App.Current.Services.GetService<ILocalizationService>();
            if (_localization is not null)
            {
                _localization.LanguageChanged += (_, _) => ApplyLocalization();
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] MainWindow localization resolve failed: " + ex);
        }

        try
        {
            NexaiSoftSigNotice.Raised += OnSoftSigNoticeRaised;
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] soft-sig subscribe failed: " + ex);
        }

        try
        {
            ExtendsContentIntoTitleBar = true;
            SetTitleBar(AppTitleBar);
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] title bar setup failed: " + ex);
        }

        try
        {
            AppWindow.Resize(new SizeInt32(1280, 840));
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] AppWindow.Resize failed: " + ex);
        }

        try
        {
            AppWindow.SetIcon("Assets/icon.ico");
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] set icon failed: " + ex);
        }

        try
        {
            // Optional: unpackaged / remote desktop environments can reject Mica.
            SystemBackdrop = new MicaBackdrop { Kind = MicaKind.Base };
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] Mica backdrop failed: " + ex);
        }

        try
        {
            ApplyLocalization();
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] ApplyLocalization in ctor failed: " + ex);
            Title = "NexAI";
        }
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
            ShowWindow(hwnd, SwRestore);
            SetForegroundWindow(hwnd);
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
            NavigateTo(AppPage.Chat);
            if (RootNavigation.MenuItems.FirstOrDefault() is NavigationViewItem first)
            {
                RootNavigation.SelectedItem = first;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] RootNavigation_Loaded failed: " + ex);
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

    [System.Runtime.InteropServices.LibraryImport("user32.dll")]
    [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
    private static partial bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [System.Runtime.InteropServices.LibraryImport("user32.dll")]
    [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
    private static partial bool SetForegroundWindow(IntPtr hWnd);
}
