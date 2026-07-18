using System.Globalization;
using NexAI.Core.Settings;
using Windows.ApplicationModel.Resources;
using Windows.Globalization;

namespace NexAI.WinUI3.Services;

public interface ILocalizationService
{
    AppLanguage Current { get; }
    string CurrentLanguageTag { get; }
    event EventHandler? LanguageChanged;
    void Apply(AppLanguage language);
    string GetString(string key);
    string GetString(string key, params object[] args);
}

public sealed class LocalizationService : ILocalizationService
{
    private ResourceLoader? _loader;

    public AppLanguage Current { get; private set; } = AppLanguage.System;
    public string CurrentLanguageTag { get; private set; } = "en-US";
    public event EventHandler? LanguageChanged;

    public void Apply(AppLanguage language)
    {
        Current = language;
        CurrentLanguageTag = ResolveLanguageTag(language);

        // PrimaryLanguageOverride drives subsequent resource lookups.
        ApplicationLanguages.PrimaryLanguageOverride = CurrentLanguageTag;

        var culture = new CultureInfo(CurrentLanguageTag);
        CultureInfo.CurrentCulture = culture;
        CultureInfo.CurrentUICulture = culture;
        CultureInfo.DefaultThreadCurrentCulture = culture;
        CultureInfo.DefaultThreadCurrentUICulture = culture;

        // Recreate loader so it picks up the override.
        _loader = ResourceLoader.GetForViewIndependentUse();
        LanguageChanged?.Invoke(this, EventArgs.Empty);
    }

    public string GetString(string key)
    {
        _loader ??= ResourceLoader.GetForViewIndependentUse();
        try
        {
            var value = _loader.GetString(key);
            return string.IsNullOrEmpty(value) ? key : value;
        }
        catch
        {
            return key;
        }
    }

    public string GetString(string key, params object[] args)
    {
        var format = GetString(key);
        try
        {
            return string.Format(CultureInfo.CurrentCulture, format, args);
        }
        catch
        {
            return format;
        }
    }

    public static string ResolveLanguageTag(AppLanguage language) => language switch
    {
        AppLanguage.English => "en-US",
        AppLanguage.ChineseSimplified => "zh-CN",
        _ => ResolveSystemLanguageTag(),
    };

    private static string ResolveSystemLanguageTag()
    {
        var tag = CultureInfo.CurrentUICulture.Name;
        if (tag.StartsWith("zh", StringComparison.OrdinalIgnoreCase))
        {
            return "zh-CN";
        }

        return "en-US";
    }
}
