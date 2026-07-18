using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Auth;
using NexAI.Infrastructure.Security;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonAuthSessionStore : IAuthSessionStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private AuthSession _current = new();

    public AuthSession Current
    {
        get { lock (_gate) { return _current.Clone(); } }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(AppPaths.AuthFilePath))
        {
            lock (_gate) { _current = new AuthSession(); }
            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        await using var stream = File.OpenRead(AppPaths.AuthFilePath);
        var loaded = await JsonSerializer.DeserializeAsync<AuthSession>(stream, Options, cancellationToken)
            .ConfigureAwait(false);
        lock (_gate) { _current = Unprotect(loaded?.Clone() ?? new AuthSession()); }
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task SaveAsync(AuthSession session, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(session);
        var snapshot = Unprotect(session.Clone());
        AppPaths.EnsureRoot();
        var temp = AppPaths.AuthFilePath + ".tmp";
        await using (var stream = File.Create(temp))
        {
            await JsonSerializer.SerializeAsync(stream, Protect(snapshot), Options, cancellationToken).ConfigureAwait(false);
        }
        File.Copy(temp, AppPaths.AuthFilePath, true);
        File.Delete(temp);
        lock (_gate) { _current = snapshot; }
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ClearAsync(CancellationToken cancellationToken = default)
    {
        await SaveAsync(new AuthSession(), cancellationToken).ConfigureAwait(false);
    }

    private static AuthSession Protect(AuthSession session)
    {
        var copy = session.Clone();
        copy.AccessToken = EmptyToNull(SecretProtector.Protect(copy.AccessToken));
        copy.RefreshToken = EmptyToNull(SecretProtector.Protect(copy.RefreshToken));
        return copy;
    }

    private static AuthSession Unprotect(AuthSession session)
    {
        var copy = session.Clone();
        copy.AccessToken = EmptyToNull(SecretProtector.Unprotect(copy.AccessToken));
        copy.RefreshToken = EmptyToNull(SecretProtector.Unprotect(copy.RefreshToken));
        return copy;
    }

    private static string? EmptyToNull(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value;
}
