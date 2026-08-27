using System.Globalization;
using System.Diagnostics;
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
    // Every page re-applies dozens of static strings on navigation, language change and
    // (for chat) each refresh; each miss is a cross-ABI MRT lookup. The cache is cleared
    // in Apply, which is the only place the resolved language / loader can change.
    private readonly Dictionary<string, string> _stringCache = new(StringComparer.Ordinal);
    private ResourceLoader? _loader;
    private bool _loaderFailed;

    public AppLanguage Current { get; private set; } = AppLanguage.System;
    public string CurrentLanguageTag { get; private set; } = "en-US";
    public event EventHandler? LanguageChanged;

public void Apply(AppLanguage language)
{
    Current = language;
    CurrentLanguageTag = ResolveLanguageTag(language);
    _stringCache.Clear();

    try
    {
        // PrimaryLanguageOverride drives subsequent resource lookups.
        ApplicationLanguages.PrimaryLanguageOverride = CurrentLanguageTag;
    }
    catch (Exception ex)
    {
        Debug.WriteLine("[NexAI] PrimaryLanguageOverride failed: " + ex.Message);
    }

    try
    {
        var culture = new CultureInfo(CurrentLanguageTag);
        CultureInfo.CurrentCulture = culture;
        CultureInfo.CurrentUICulture = culture;
        CultureInfo.DefaultThreadCurrentCulture = culture;
        CultureInfo.DefaultThreadCurrentUICulture = culture;
    }
    catch (Exception ex)
    {
        Debug.WriteLine("[NexAI] culture apply failed: " + ex.Message);
    }

    // Recreate loader so it picks up the override. Never crash startup if
    // unpackaged resources are incomplete on a user machine.
    try
    {
        _loader = ResourceLoader.GetForViewIndependentUse();
        _loaderFailed = false;
    }
    catch (Exception ex)
    {
        _loader = null;
        _loaderFailed = true;
        Debug.WriteLine("[NexAI] ResourceLoader init failed: " + ex.Message);
    }

        try
        {
            LanguageChanged?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            Debug.WriteLine("[NexAI] LanguageChanged handlers failed: " + ex.Message);
        }
}

    public string GetString(string key)
    {
        if (_loaderFailed)
        {
            return key;
        }

        if (_stringCache.TryGetValue(key, out var cached))
        {
            return cached;
        }

        try
        {
            _loader ??= ResourceLoader.GetForViewIndependentUse();
            var value = _loader.GetString(key);
            var resolved = string.IsNullOrEmpty(value) ? key : value;
            _stringCache[key] = resolved;
            return resolved;
        }
        catch
        {
            _loaderFailed = true;
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
