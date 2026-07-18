using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Notes;
using NexAI.WinUI3.Services;

namespace NexAI.WinUI3.Views;

public sealed partial class NotesPage : Page
{
    private readonly INotesStore _notesStore;
    private readonly ILocalizationService _localization;
    private string? _selectedId;
    private string _query = string.Empty;

    public NotesPage()
    {
        InitializeComponent();
        _notesStore = App.Current.Services.GetRequiredService<INotesStore>();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => DispatcherQueue.TryEnqueue(RefreshList);
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _notesStore.Changed += OnChanged;
        ApplyStaticLocalization();
        RefreshList();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _notesStore.Changed -= OnChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshList);

    private void RefreshList()
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
        var selected = notes.FirstOrDefault(n => n.Id == _selectedId) ?? notes.FirstOrDefault();
        if (selected is null)
        {
            _selectedId = null;
            TitleBox.Text = string.Empty;
            ContentBox.Text = string.Empty;
            StatusText.Text = _localization.GetString("Notes.CreateToStart");
            return;
        }

        _selectedId = selected.Id;
        NotesList.SelectedItem = selected;
        TitleBox.Text = selected.Title;
        ContentBox.Text = selected.Content;
        StarButton.Content = selected.IsStarred ? _localization.GetString("Common.Unstar") : _localization.GetString("Common.Star");
        var tags = selected.Tags;
        StatusText.Text = tags.Count == 0
            ? _localization.GetString("Notes.Updated", selected.UpdatedAt.ToLocalTime().ToString("g"))
            : _localization.GetString("Notes.TagsUpdated", string.Join(", ", tags), selected.UpdatedAt.ToLocalTime().ToString("g"));
    }

    private async void NewNoteButton_Click(object sender, RoutedEventArgs e)
    {
        var note = await _notesStore.CreateAsync();
        _selectedId = note.Id;
        RefreshList();
    }

    private void NotesList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Note note)
        {
            _selectedId = note.Id;
            RefreshList();
        }
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _query = SearchBox.Text?.Trim() ?? string.Empty;
        RefreshList();
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedId is null)
        {
            var created = await _notesStore.CreateAsync(TitleBox.Text, ContentBox.Text);
            _selectedId = created.Id;
            StatusText.Text = _localization.GetString("Notes.Created");
            return;
        }

        var note = _notesStore.Notes.FirstOrDefault(n => n.Id == _selectedId);
        if (note is null) return;
        note.Title = string.IsNullOrWhiteSpace(TitleBox.Text) ? _localization.GetString("Notes.Untitled") : TitleBox.Text.Trim();
        note.Content = ContentBox.Text ?? string.Empty;
        await _notesStore.UpdateAsync(note);
        StatusText.Text = _localization.GetString("Notes.Saved");
    }

    private async void DeleteButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedId is null) return;
        var dialog = new ContentDialog
        {
            Title = _localization.GetString("Notes.DeleteTitle"),
            Content = _localization.GetString("Notes.DeleteBody"),
            PrimaryButtonText = _localization.GetString("Common.Delete"),
            CloseButtonText = _localization.GetString("Common.Cancel"),
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        await _notesStore.DeleteAsync(_selectedId);
        _selectedId = null;
    }

    private async void StarButton_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedId is null) return;
        await _notesStore.ToggleStarAsync(_selectedId);
    }
}
