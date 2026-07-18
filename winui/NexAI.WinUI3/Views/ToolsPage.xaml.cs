using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.WinUI3.Views.Tools;

namespace NexAI.WinUI3.Views;

public sealed partial class ToolsPage : Page
{
    public ToolsPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (ToolsFrame.Content is null)
        {
            ToolsFrame.Navigate(typeof(ToolsHubPage));
        }
    }
}
