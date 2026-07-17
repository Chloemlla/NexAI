using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NexAI.Core.Navigation;
using Windows.Graphics;

namespace NexAI.WinUI3.Views;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        AppWindow.Resize(new SizeInt32(1180, 780));
        AppWindow.SetIcon("Assets/icon.ico");
        Title = "NexAI";
    }

    private void RootNavigation_Loaded(object sender, RoutedEventArgs e)
    {
        NavigateTo(AppPage.Chat);
        if (RootNavigation.MenuItems.FirstOrDefault() is NavigationViewItem first)
        {
            RootNavigation.SelectedItem = first;
        }
    }

    private void RootNavigation_SelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item)
        {
            return;
        }

        var destination = NavigationCatalog.FindByTag(item.Tag?.ToString())?.Page
            ?? AppPage.Chat;
        NavigateTo(destination);
    }

    private void NavigateTo(AppPage page)
    {
        var targetType = page switch
        {
            AppPage.Settings => typeof(SettingsPage),
            _ => typeof(ChatPage),
        };

        if (ContentFrame.CurrentSourcePageType == targetType)
        {
            return;
        }

        ContentFrame.Navigate(targetType);
    }
}
