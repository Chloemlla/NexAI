using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Settings;

namespace NexAI.WinUI3.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);

        var settings = App.Current.Services.GetService(typeof(ISettingsStore)) as ISettingsStore;
        var current = settings?.Current ?? new AppSettings();
        BaseUrlBox.Text = current.BaseUrl;
        ModelBox.Text = current.SelectedModel;
        ThemeBox.Text = current.ThemeMode.ToString();
    }
}
