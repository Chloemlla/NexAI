using Microsoft.UI.Xaml;
using NexAI.Core.Settings;

namespace NexAI.WinUI3.Services;

public sealed class ThemeService
{
    public void Apply(AppThemeMode mode)
    {
        if (Application.Current is not App app)
        {
            return;
        }

        // Application.RequestedTheme is honored best before the first window activates.
        app.RequestedTheme = mode switch
        {
            AppThemeMode.Light => ApplicationTheme.Light,
            AppThemeMode.Dark => ApplicationTheme.Dark,
            _ => ApplicationTheme.Light,
        };
    }
}
