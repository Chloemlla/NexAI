using Microsoft.UI.Xaml;
using NexAI.Core.Settings;

namespace NexAI.WinUI3.Services;

public sealed class ThemeService
{
    private FrameworkElement? _root;

    public void Attach(FrameworkElement root)
    {
        _root = root;
        // Ensure newly attached trees inherit the last requested mode.
    }

    public void Apply(AppThemeMode mode)
    {
        if (_root is null)
        {
            return;
        }

        _root.RequestedTheme = mode switch
        {
            AppThemeMode.Light => ElementTheme.Light,
            AppThemeMode.Dark => ElementTheme.Dark,
            _ => ElementTheme.Default,
        };
    }
}
