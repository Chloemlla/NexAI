namespace NexAI.Core.Auth;

public sealed class AuthSession
{
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public string? Username { get; set; }
    public string? Email { get; set; }
    public string? DisplayName { get; set; }
    public DateTime? ExpiresAt { get; set; }

    public bool IsAuthenticated => !string.IsNullOrWhiteSpace(AccessToken);

    public AuthSession Clone() => new()
    {
        AccessToken = AccessToken,
        RefreshToken = RefreshToken,
        Username = Username,
        Email = Email,
        DisplayName = DisplayName,
        ExpiresAt = ExpiresAt,
    };
}

public interface IAuthSessionStore
{
    AuthSession Current { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(AuthSession session, CancellationToken cancellationToken = default);
    Task ClearAsync(CancellationToken cancellationToken = default);
}

public interface IAuthClient
{
    Task<AuthSession> LoginAsync(string backendBaseUrl, string identifier, string password, CancellationToken cancellationToken = default);
    Task LogoutAsync(string backendBaseUrl, string accessToken, CancellationToken cancellationToken = default);
}
