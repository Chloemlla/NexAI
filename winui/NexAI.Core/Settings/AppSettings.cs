namespace NexAI.Core.Settings;

public enum AppThemeMode
{
    System,
    Light,
    Dark,
}

public enum AppLanguage
{
    System,
    English,
    ChineseSimplified,
}

public enum SyncBackendKind
{
    NexAI,
    WebDAV,
    UpStash,
}

public sealed class AppSettings
{
    public string BaseUrl { get; set; } = "https://api.openai.com/v1";
    public string ApiKey { get; set; } = string.Empty;
    public string SelectedModel { get; set; } = "gpt-4o-mini";
    public double Temperature { get; set; } = 0.7;
    public int MaxTokens { get; set; } = 2048;
    public string SystemPrompt { get; set; } = "You are a helpful assistant.";
    public AppThemeMode ThemeMode { get; set; } = AppThemeMode.System;
    public AppLanguage Language { get; set; } = AppLanguage.System;

    public string BackendBaseUrl { get; set; } = "https://tts.chloemlla.com/api/nexai";
    public bool SyncEnabled { get; set; }
    public SyncBackendKind SyncMethod { get; set; } = SyncBackendKind.NexAI;
    public string WebDavServer { get; set; } = string.Empty;
    public string WebDavUser { get; set; } = string.Empty;
    public string WebDavPassword { get; set; } = string.Empty;
    public string UpstashUrl { get; set; } = string.Empty;
    public string UpstashToken { get; set; } = string.Empty;
    public bool NotesAutoSave { get; set; } = true;
    public bool AdvancedRenderingEnabled { get; set; } = true;

    public AppSettings Clone() => new()
    {
        BaseUrl = BaseUrl,
        ApiKey = ApiKey,
        SelectedModel = SelectedModel,
        Temperature = Temperature,
        MaxTokens = MaxTokens,
        SystemPrompt = SystemPrompt,
        ThemeMode = ThemeMode,
        Language = Language,
        BackendBaseUrl = BackendBaseUrl,
        SyncEnabled = SyncEnabled,
        SyncMethod = SyncMethod,
        WebDavServer = WebDavServer,
        WebDavUser = WebDavUser,
        WebDavPassword = WebDavPassword,
        UpstashUrl = UpstashUrl,
        UpstashToken = UpstashToken,
        NotesAutoSave = NotesAutoSave,
        AdvancedRenderingEnabled = AdvancedRenderingEnabled,
    };
}

public interface ISettingsStore
{
    AppSettings Current { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default);
}

public static class AppSettingsValidator
{
    public static string? Validate(AppSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);

        var baseUrl = settings.BaseUrl?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            return "Base URL is required.";
        }

        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            return "Base URL must be an absolute http(s) URL.";
        }

        if (string.IsNullOrWhiteSpace(settings.SelectedModel))
        {
            return "Model is required.";
        }

        if (double.IsNaN(settings.Temperature) || settings.Temperature < 0 || settings.Temperature > 2)
        {
            return "Temperature must be between 0 and 2.";
        }

        if (settings.MaxTokens < 1 || settings.MaxTokens > 128_000)
        {
            return "Max tokens must be between 1 and 128000.";
        }

        var backend = settings.BackendBaseUrl?.Trim() ?? string.Empty;
        if (!string.IsNullOrWhiteSpace(backend) &&
            (!Uri.TryCreate(backend, UriKind.Absolute, out var backendUri) ||
             (backendUri.Scheme != Uri.UriSchemeHttp && backendUri.Scheme != Uri.UriSchemeHttps)))
        {
            return "Backend base URL must be an absolute http(s) URL.";
        }

        return null;
    }

    public static AppSettings Normalize(AppSettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        var normalized = settings.Clone();
        normalized.BaseUrl = (normalized.BaseUrl ?? string.Empty).Trim().TrimEnd('/');
        normalized.ApiKey = (normalized.ApiKey ?? string.Empty).Trim();
        normalized.SelectedModel = (normalized.SelectedModel ?? string.Empty).Trim();
        normalized.SystemPrompt = (normalized.SystemPrompt ?? string.Empty).Trim();
        normalized.BackendBaseUrl = (normalized.BackendBaseUrl ?? string.Empty).Trim().TrimEnd('/');
        normalized.WebDavServer = (normalized.WebDavServer ?? string.Empty).Trim();
        normalized.WebDavUser = (normalized.WebDavUser ?? string.Empty).Trim();
        normalized.WebDavPassword = normalized.WebDavPassword ?? string.Empty;
        normalized.UpstashUrl = (normalized.UpstashUrl ?? string.Empty).Trim();
        normalized.UpstashToken = normalized.UpstashToken ?? string.Empty;
        normalized.Temperature = Math.Round(normalized.Temperature, 2, MidpointRounding.AwayFromZero);
        return normalized;
    }
}
