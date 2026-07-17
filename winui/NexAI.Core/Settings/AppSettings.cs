namespace NexAI.Core.Settings;

public enum AppThemeMode
{
    System,
    Light,
    Dark,
}

public sealed class AppSettings
{
    public string BaseUrl { get; set; } = "https://api.openai.com/v1";
    public string ApiKey { get; set; } = string.Empty;
    public string SelectedModel { get; set; } = "gpt-4o-mini";
    public double Temperature { get; set; } = 0.7;
    public int MaxTokens { get; set; } = 2048;
    public AppThemeMode ThemeMode { get; set; } = AppThemeMode.System;

    public AppSettings Clone() => new()
    {
        BaseUrl = BaseUrl,
        ApiKey = ApiKey,
        SelectedModel = SelectedModel,
        Temperature = Temperature,
        MaxTokens = MaxTokens,
        ThemeMode = ThemeMode,
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

        if (double.IsNaN(settings.Temperature) ||
            settings.Temperature < 0 ||
            settings.Temperature > 2)
        {
            return "Temperature must be between 0 and 2.";
        }

        if (settings.MaxTokens < 1 || settings.MaxTokens > 128_000)
        {
            return "Max tokens must be between 1 and 128000.";
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
        normalized.Temperature = Math.Round(normalized.Temperature, 2, MidpointRounding.AwayFromZero);
        return normalized;
    }
}
