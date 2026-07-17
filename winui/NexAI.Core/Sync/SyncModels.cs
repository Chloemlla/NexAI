namespace NexAI.Core.Sync;

public enum SyncStatus
{
    Idle,
    Uploading,
    Downloading,
    Success,
    Error,
}

public sealed class SyncState
{
    public SyncStatus Status { get; set; } = SyncStatus.Idle;
    public string? ErrorMessage { get; set; }
    public DateTime? LastSyncedAt { get; set; }
    public string? RecoveryKeyHint { get; set; }
}

public interface ISyncService
{
    SyncState State { get; }
    event EventHandler? Changed;
    Task LoadAsync(CancellationToken cancellationToken = default);
    Task<string> ExportRecoveryKeyAsync(CancellationToken cancellationToken = default);
    Task ImportRecoveryKeyAsync(string encoded, CancellationToken cancellationToken = default);
    Task<bool> UploadAsync(CancellationToken cancellationToken = default);
    Task<bool> DownloadAsync(CancellationToken cancellationToken = default);
}

public interface ISyncCrypto
{
    Task<string> ExportRecoveryKeyAsync(CancellationToken cancellationToken = default);
    Task ImportRecoveryKeyAsync(string encoded, CancellationToken cancellationToken = default);
    Task<Dictionary<string, object?>> EncryptRecordAsync(
        string id,
        string category,
        string updatedAt,
        Dictionary<string, object?> payload,
        CancellationToken cancellationToken = default);
    Task<Dictionary<string, object?>?> DecryptRecordAsync(
        Dictionary<string, object?> record,
        CancellationToken cancellationToken = default);
}
