namespace NexAI.Core.Migration;

public sealed class FlutterMigrationResult
{
    public bool Attempted { get; init; }
    public bool Applied { get; init; }
    public string Message { get; init; } = string.Empty;
    public int ImportedConversations { get; init; }
    public int ImportedNotes { get; init; }
    public bool ImportedSettings { get; init; }
}

public interface IFlutterDataMigrator
{
    Task<FlutterMigrationResult> TryMigrateAsync(CancellationToken cancellationToken = default);
}
