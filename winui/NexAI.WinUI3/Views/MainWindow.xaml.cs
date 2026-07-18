using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NexAI.Core.Navigation;
using Microsoft.Extensions.DependencyInjection;
using NexAI.WinUI3.Services;
using NexAI.Infrastructure.Security;
using Windows.Graphics;

namespace NexAI.WinUI3.Views;

public sealed partial class MainWindow : Window
{
    private readonly ILocalizationService _localization;
    private Microsoft.UI.Dispatching.DispatcherQueueTimer? _softSigHideTimer;

    public MainWindow()
    {
        InitializeComponent();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => ApplyLocalization();
        NexaiSoftSigNotice.Raised += OnSoftSigNoticeRaised;
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        AppWindow.Resize(new SizeInt32(1280, 840));
        AppWindow.SetIcon("Assets/icon.ico");
        ApplyLocalization();
    }

    private void RootNavigation_Loaded(object sender, RoutedEventArgs e)
    {
        ApplyLocalization();
        NavigateTo(AppPage.Chat);
        if (RootNavigation.MenuItems.FirstOrDefault() is NavigationViewItem first)
        {
            RootNavigation.SelectedItem = first;
        }
    }

    private void ApplyLocalization()
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

    private void OnSoftSigNoticeRaised(object? sender, NexaiSoftSigNoticeEventArgs e)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            SoftSigInfoBar.Title = _localization.GetString("SoftSig.Title");
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
}
