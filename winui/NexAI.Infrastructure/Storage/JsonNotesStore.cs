using System.Text.Json;
using System.Text.Json.Serialization;
using NexAI.Core;
using NexAI.Core.Notes;

namespace NexAI.Infrastructure.Storage;

public sealed class JsonNotesStore : INotesStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly object _gate = new();
    private List<Note> _notes = [];

    public IReadOnlyList<Note> Notes
    {
        get { lock (_gate) { return _notes.Select(n => n.Clone()).ToList(); } }
    }

    public event EventHandler? Changed;

    public async Task LoadAsync(CancellationToken cancellationToken = default)
    {
        AppPaths.EnsureRoot();
        if (!File.Exists(AppPaths.NotesFilePath))
        {
            lock (_gate) { _notes = []; }
            Changed?.Invoke(this, EventArgs.Empty);
            return;
        }

        await using var stream = File.OpenRead(AppPaths.NotesFilePath);
        var loaded = await JsonSerializer.DeserializeAsync<List<Note>>(stream, Options, cancellationToken)
            .ConfigureAwait(false);
        lock (_gate)
        {
            _notes = (loaded ?? []).Select(n => n.Clone()).OrderByDescending(n => n.UpdatedAt).ToList();
        }
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task SaveAsync(CancellationToken cancellationToken = default)
    {
        List<Note> snapshot;
        lock (_gate) { snapshot = _notes.Select(n => n.Clone()).ToList(); }
        AppPaths.EnsureRoot();
        var temp = AppPaths.NotesFilePath + ".tmp";
        await using (var stream = File.Create(temp))
        {
            await JsonSerializer.SerializeAsync(stream, snapshot, Options, cancellationToken).ConfigureAwait(false);
        }
        File.Copy(temp, AppPaths.NotesFilePath, true);
        File.Delete(temp);
    }

    public async Task<Note> CreateAsync(string? title = null, string? content = null, CancellationToken cancellationToken = default)
    {
        var note = new Note
        {
            Title = string.IsNullOrWhiteSpace(title) ? "Untitled Note" : title.Trim(),
            Content = content ?? string.Empty,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        lock (_gate) { _notes.Insert(0, note); }
        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
        return note.Clone();
    }

    public async Task UpdateAsync(Note note, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(note);
        lock (_gate)
        {
            var idx = _notes.FindIndex(n => n.Id == note.Id);
            if (idx < 0) throw new InvalidOperationException("Note not found.");
            note.UpdatedAt = DateTime.UtcNow;
            _notes[idx] = note.Clone();
            _notes = _notes.OrderByDescending(n => n.UpdatedAt).ToList();
        }
        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task DeleteAsync(string noteId, CancellationToken cancellationToken = default)
    {
        lock (_gate) { _notes.RemoveAll(n => n.Id == noteId); }
        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ToggleStarAsync(string noteId, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            var note = _notes.FirstOrDefault(n => n.Id == noteId)
                ?? throw new InvalidOperationException("Note not found.");
            note.IsStarred = !note.IsStarred;
            note.UpdatedAt = DateTime.UtcNow;
        }
        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public async Task ReplaceAllAsync(IEnumerable<Note> notes, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            _notes = notes.Select(n => n.Clone()).OrderByDescending(n => n.UpdatedAt).ToList();
        }
        await SaveAsync(cancellationToken).ConfigureAwait(false);
        Changed?.Invoke(this, EventArgs.Empty);
    }
}
