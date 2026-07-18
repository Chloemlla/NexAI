using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Tools;
using NexAI.WinUI3.Services;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed class ToolListItem
{
    public required ToolDefinition Definition { get; init; }
    public required string Title { get; init; }
    public required string Description { get; init; }
    public required string Category { get; init; }
    public string Glyph => Definition.Glyph;
    public ToolKind Kind => Definition.Kind;
}

public sealed partial class ToolsHubPage : Page
{
    private readonly ILocalizationService _localization;
    private string _query = string.Empty;

    public ToolsHubPage()
    {
        InitializeComponent();
        _localization = App.Current.Services.GetRequiredService<ILocalizationService>();
        _localization.LanguageChanged += (_, _) => DispatcherQueue.TryEnqueue(Refresh);
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        Refresh();
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _query = SearchBox.Text?.Trim() ?? string.Empty;
        Refresh();
    }

    private void Refresh()
    {
        var items = ToolCatalog.All
            .Select(t => new ToolListItem
            {
                Definition = t,
                Title = _localization.GetString(t.TitleKey),
                Description = _localization.GetString(t.DescriptionKey),
                Category = _localization.GetString(t.CategoryKey),
            })
            .Where(t =>
                string.IsNullOrWhiteSpace(_query) ||
                t.Title.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                t.Description.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                t.Category.Contains(_query, StringComparison.OrdinalIgnoreCase) ||
                t.Kind.ToString().Contains(_query, StringComparison.OrdinalIgnoreCase))
            .ToList();
        ToolsGrid.ItemsSource = items;
    }

    private void ToolsGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ToolListItem item)
        {
            return;
        }

        var target = item.Kind switch
        {
            ToolKind.Base64 => typeof(Base64ToolPage),
            ToolKind.Password => typeof(PasswordToolPage),
            ToolKind.Translation => typeof(TranslationToolPage),
            ToolKind.ShortUrl => typeof(ShortUrlToolPage),
            _ => typeof(GenericToolHostPage),
        };

        Frame?.Navigate(target, item.Definition);
    }
}
