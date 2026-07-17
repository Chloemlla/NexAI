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
