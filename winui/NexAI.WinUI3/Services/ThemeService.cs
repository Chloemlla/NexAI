using Microsoft.UI.Xaml;
using NexAI.Core.Settings;

namespace NexAI.WinUI3.Services;

public sealed class ThemeService
{
    private FrameworkElement? _root;
    private AppThemeMode _mode = AppThemeMode.System;

    public AppThemeMode CurrentMode => _mode;

    public void Attach(FrameworkElement root)
    {
        _root = root;
        Apply(_mode);
    }

    public void Apply(AppThemeMode mode)
    {
        _mode = mode;
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
