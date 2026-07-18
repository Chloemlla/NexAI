using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Notes;
using NexAI.Core.Settings;
using NexAI.WinUI3.Services;

namespace NexAI.WinUI3.Views;

public sealed partial class NotesPage : Page
{
    private readonly INotesStore _notesStore;
    private readonly ISettingsStore _settingsStore;
    private readonly ILocalizationService _localization;
    private string? _selectedId;
    private string _query = string.Empty;
    private bool _isDirty;
    private bool _suppressDirty;
    private bool _isLeavingEditor;

    public NotesPage()
    {
        InitializeComponent();
        _notesStore = App.Current.Services.GetRequiredService<INotesStore>();
        _settingsStore = App.Current.Services.GetRequiredService<ISettingsStore>();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => DispatcherQueue.TryEnqueue(() =>
        {
            ApplyStaticLocalization();
            RefreshList(loadEditor: !_isDirty);
        });
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _notesStore.Changed += OnChanged;
        ApplyStaticLocalization();
        RefreshList(loadEditor: true);
    }

    protected override async void OnNavigatedFrom(NavigationEventArgs e)
    {
        _notesStore.Changed -= OnChanged;
        if (_isDirty && _settingsStore.Current.NotesAutoSave)
        {
            try
            {
                await SaveCurrentAsync(showStatus: false);
            }
            catch
            {
                // Leaving page; store error surfaces next visit.
            }
        }

        base.OnNavigatedFrom(e);
    }

    private void OnChanged(object? sender, EventArgs e)
        => DispatcherQueue.TryEnqueue(() => RefreshList(loadEditor: !_isDirty));

    private void ApplyStaticLocalization()
    {
        NotesTitleText.Text = _localization.GetString("Notes.Title");
        NewNoteButton.Content = _localization.GetString("Common.New");
        SearchBox.PlaceholderText = _localization.GetString("Notes.SearchPlaceholder");
        TitleBox.PlaceholderText = _localization.GetString("Notes.Untitled");
        DeleteButton.Content = _localization.GetString("Common.Delete");
        ContentBox.PlaceholderText = _localization.GetString("Notes.EditorPlaceholder");
        SaveButton.Content = _localization.GetString("Common.Save");
    }

    private void RefreshList(bool loadEditor)
    {
        var notes = _notesStore.Notes
            .Where(n =>
                string.IsNullOrWhiteSpace(_query) ||
                n.Title.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                n.Content.Contains(_query, StringComparison.OrdinalIgnoreCase))
            .ToList();
        NotesList.ItemsSource = notes;
        NotesCountText.Text = _notesStore.Notes.Count == 1
            ? _localization.GetString("Notes.Count", _notesStore.Notes.Count)
            : _localization.GetString("Notes.CountPlural", _notesStore.Notes.Count);

        // Never clobber an in-progress editor from list/store refresh.
        if (!loadEditor && _isDirty)
        {
            NotesList.SelectedItem = notes.FirstOrDefault(n => n.Id == _selectedId);
            var starred = _notesStore.Notes.FirstOrDefault(n => n.Id == _selectedId);
            if (starred is not null)
            {
                StarButton.Content = starred.IsStarred
                    ? _localization.GetString("Common.Unstar")
                    : _localization.GetString("Common.Star");
            }

            return;
        }

        var selected = notes.FirstOrDefault(n => n.Id == _selectedId) ?? notes.FirstOrDefault();
        if (selected is null)
        {
            _selectedId = null;
            SetEditorText(string.Empty, string.Empty, clearDirty: true);
            NotesList.SelectedItem = null;
            StatusText.Text = _localization.GetString("Notes.CreateToStart");
            return;
        }

        _selectedId = selected.Id;
        NotesList.SelectedItem = selected;
        SetEditorText(selected.Title, selected.Content, clearDirty: true);
        StarButton.Content = selected.IsStarred
            ? _localization.GetString("Common.Unstar")
            : _localization.GetString("Common.Star");
        var tags = selected.Tags;
        StatusText.Text = tags.Count == 0
            ? _localization.GetString("Notes.Updated", selected.UpdatedAt.ToLocalTime().ToString("g"))
            : _localization.GetString(
                "Notes.TagsUpdated",
                string.Join(", ", tags),
                selected.UpdatedAt.ToLocalTime().ToString("g"));
    }

    private void SetEditorText(string title, string content, bool clearDirty)
    {
        _suppressDirty = true;
        TitleBox.Text = title;
        ContentBox.Text = content;
        _suppressDirty = false;
        if (clearDirty)
        {
            _isDirty = false;
        }
    }

    private void TitleBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (!_suppressDirty)
        {
            _isDirty = true;
        }
    }

    private void ContentBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (!_suppressDirty)
        {
            _isDirty = true;
        }
    }

    private async Task<bool> EnsureCanLeaveEditorAsync()
    {
        if (!_isDirty || _isLeavingEditor)
        {
            return true;
        }

        _isLeavingEditor = true;
        try
        {
            if (_settingsStore.Current.NotesAutoSave)
            {
                await SaveCurrentAsync(showStatus: true);
                return true;
            }

            var dialog = new ContentDialog
            {
                Title = _localization.GetString("Notes.UnsavedTitle"),
                Content = _localization.GetString("Notes.UnsavedBody"),
                PrimaryButtonText = _localization.GetString("Common.Save"),
                SecondaryButtonText = _localization.GetString("Notes.Discard"),
                CloseButtonText = _localization.GetString("Common.Cancel"),
                DefaultButton = ContentDialogButton.Primary,
                XamlRoot = XamlRoot,
            };

            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
            {
                await SaveCurrentAsync(showStatus: true);
                return true;
            }

            if (result == ContentDialogResult.Secondary)
            {
                _isDirty = false;
                return true;
            }

            return false;
        }
        finally
        {
            _isLeavingEditor = false;
        }
    }

    private async Task SaveCurrentAsync(bool showStatus)
    {
        if (_selectedId is null)
        {
            var created = await _notesStore.CreateAsync(TitleBox.Text, ContentBox.Text);
            _selectedId = created.Id;
            _isDirty = false;
            if (showStatus)
            {
                StatusText.Text = _localization.GetString("Notes.Created");
            }

            return;
        }

        var note = _notesStore.Notes.FirstOrDefault(n => n.Id == _selectedId);
        if (note is null)
        {
            return;
        }

        note.Title = string.IsNullOrWhiteSpace(TitleBox.Text)
            ? _localization.GetString("Notes.Untitled")
            : TitleBox.Text.Trim();
        note.Content = ContentBox.Text ?? string.Empty;
        await _notesStore.UpdateAsync(note);
        _isDirty = false;
        if (showStatus)
        {
            StatusText.Text = _localization.GetString("Notes.Saved");
        }
    }

    private async void NewNoteButton_Click(object sender, RoutedEventArgs e)
    {
        if (!await EnsureCanLeaveEditorAsync())
        {
            return;
        }

        var note = await _notesStore.CreateAsync();
        _selectedId = note.Id;
        _isDirty = false;
        RefreshList(loadEditor: true);
    }

    private async void NotesList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not Note note)
        {
            return;
        }

        if (string.Equals(note.Id, _selectedId, StringComparison.Ordinal))
        {
            return;
        }

        if (!await EnsureCanLeaveEditorAsync())
        {
            // Restore selection to the note still being edited.
            if (NotesList.ItemsSource is IEnumerable<Note> items)
            {
                NotesList.SelectedItem = items.FirstOrDefault(n => n.Id == _selectedId);
            }

            return;
        }

        _selectedId = note.Id;
        RefreshList(loadEditor: true);
    }

    private async void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        var nextQuery = SearchBox.Text?.Trim() ?? string.Empty;
        var stillVisible = _selectedId is not null &&
            _notesStore.Notes.Any(n =>
                string.Equals(n.Id, _selectedId, StringComparison.Ordinal) &&
                (string.IsNullOrWhiteSpace(nextQuery) ||
                 n.Title.Contains(nextQuery, StringComparison.OrdinalIgnoreCase) ||
                 n.Content.Contains(nextQuery, StringComparison.OrdinalIgnoreCase)));

        if (_isDirty && !stillVisible)
        {
            if (!await EnsureCanLeaveEditorAsync())
            {
                // Revert query so the dirty editor stays visible.
                if (!string.Equals(SearchBox.Text, _query, StringComparison.Ordinal))
                {
                    SearchBox.Text = _query;
                }

                return;
            }
        }

        _query = nextQuery;
        RefreshList(loadEditor: !_isDirty || !stillVisible);
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        await SaveCurrentAsync(showStatus: true);
    }

    private async void DeleteButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedId is null)
        {
            return;
        }

        var dialog = new ContentDialog
        {
            Title = _localization.GetString("Notes.DeleteTitle"),
            Content = _localization.GetString("Notes.DeleteBody"),
            PrimaryButtonText = _localization.GetString("Common.Delete"),
            CloseButtonText = _localization.GetString("Common.Cancel"),
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
        {
            return;
        }

        await _notesStore.DeleteAsync(_selectedId);
        _selectedId = null;
        _isDirty = false;
    }

    private async void StarButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedId is null)
        {
            return;
        }

        if (_isDirty && _settingsStore.Current.NotesAutoSave)
        {
            await SaveCurrentAsync(showStatus: false);
        }

        await _notesStore.ToggleStarAsync(_selectedId);
    }
}
