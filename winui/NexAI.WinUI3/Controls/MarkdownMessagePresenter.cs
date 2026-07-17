using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Microsoft.UI.Xaml.Media;
using NexAI.Core.Chat;
using NexAI.Core.Markdown;
using Windows.UI;

namespace NexAI.WinUI3.Controls;

public sealed class MarkdownMessagePresenter : UserControl
{
    public static readonly DependencyProperty MessageProperty =
        DependencyProperty.Register(
            nameof(Message),
            typeof(ChatMessage),
            typeof(MarkdownMessagePresenter),
            new PropertyMetadata(null, OnMessageChanged));

    public ChatMessage? Message
    {
        get => (ChatMessage?)GetValue(MessageProperty);
        set => SetValue(MessageProperty, value);
    }

    private readonly StackPanel _root;

    public MarkdownMessagePresenter()
    {
        _root = new StackPanel { Spacing = 8 };
        Content = _root;
    }

    private static void OnMessageChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is MarkdownMessagePresenter presenter)
        {
            presenter.Render();
        }
    }

    private void Render()
    {
        _root.Children.Clear();
        var message = Message;
        if (message is null)
        {
            return;
        }

        var roleRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
        };
        roleRow.Children.Add(new TextBlock
        {
            Text = FormatRole(message.Role),
            FontSize = 12,
            Opacity = 0.72,
        });

        if (message.IsError)
        {
            roleRow.Children.Add(new TextBlock
            {
                Text = "error",
                Foreground = new SolidColorBrush(Color.FromArgb(255, 196, 43, 28)),
                FontSize = 12,
            });
        }

        _root.Children.Add(roleRow);

        foreach (var block in BasicMarkdown.Parse(message.Content))
        {
            switch (block.Kind)
            {
                case MarkdownBlockKind.Heading:
                    _root.Children.Add(CreateHeading(block));
                    break;
                case MarkdownBlockKind.Code:
                    _root.Children.Add(CreateCode(block));
                    break;
                case MarkdownBlockKind.List:
                    _root.Children.Add(CreateList(block));
                    break;
                case MarkdownBlockKind.Quote:
                    _root.Children.Add(CreateQuote(block));
                    break;
                default:
                    _root.Children.Add(CreateParagraph(block.Text));
                    break;
            }
        }
    }

    private static string FormatRole(string role)
    {
        if (string.Equals(role, ChatRoles.User, StringComparison.OrdinalIgnoreCase))
        {
            return "You";
        }

        if (string.Equals(role, ChatRoles.Assistant, StringComparison.OrdinalIgnoreCase))
        {
            return "Assistant";
        }

        return role;
    }

    private static TextBlock CreateHeading(MarkdownBlock block)
    {
        var size = block.HeadingLevel switch
        {
            1 => 24.0,
            2 => 20.0,
            3 => 18.0,
            _ => 16.0,
        };

        return new TextBlock
        {
            Text = block.Text,
            FontSize = size,
            FontWeight = FontWeights.SemiBold,
            TextWrapping = TextWrapping.WrapWholeWords,
            IsTextSelectionEnabled = true,
            Margin = new Thickness(0, 2, 0, 2),
        };
    }

    private static Border CreateCode(MarkdownBlock block)
    {
        var panel = new StackPanel { Spacing = 6 };
        if (!string.IsNullOrWhiteSpace(block.Language))
        {
            panel.Children.Add(new TextBlock
            {
                Text = block.Language,
                Opacity = 0.72,
                FontSize = 12,
            });
        }

        panel.Children.Add(new TextBlock
        {
            Text = block.Text,
            FontFamily = new FontFamily("Cascadia Mono, Consolas, Courier New"),
            FontSize = 12.5,
            TextWrapping = TextWrapping.Wrap,
            IsTextSelectionEnabled = true,
        });

        return new Border
        {
            Background = ResolveBrush("CardBackgroundFillColorDefaultBrush", Color.FromArgb(255, 245, 245, 245)),
            BorderBrush = ResolveBrush("CardStrokeColorDefaultBrush", Color.FromArgb(255, 220, 220, 220)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(6),
            Padding = new Thickness(12),
            Child = panel,
        };
    }

    private static StackPanel CreateList(MarkdownBlock block)
    {
        var panel = new StackPanel { Spacing = 4 };
        foreach (var item in block.ListItems ?? [])
        {
            var row = new Grid();
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var bullet = new TextBlock
            {
                Text = "•",
                Margin = new Thickness(0, 0, 8, 0),
                Opacity = 0.8,
            };
            Grid.SetColumn(bullet, 0);
            row.Children.Add(bullet);

            var content = CreateParagraph(item);
            Grid.SetColumn(content, 1);
            row.Children.Add(content);
            panel.Children.Add(row);
        }

        return panel;
    }

    private static Border CreateQuote(MarkdownBlock block)
    {
        return new Border
        {
            BorderBrush = ResolveBrush("AccentFillColorDefaultBrush", Color.FromArgb(255, 0, 120, 212)),
            BorderThickness = new Thickness(3, 0, 0, 0),
            Padding = new Thickness(12, 4, 4, 4),
            Child = CreateParagraph(block.Text),
        };
    }

    private static RichTextBlock CreateParagraph(string text)
    {
        var rtb = new RichTextBlock
        {
            TextWrapping = TextWrapping.WrapWholeWords,
            IsTextSelectionEnabled = true,
        };

        var paragraph = new Paragraph();
        foreach (var span in BasicMarkdown.ParseInlines(text))
        {
            paragraph.Inlines.Add(CreateInline(span));
        }

        rtb.Blocks.Add(paragraph);
        return rtb;
    }

    private static Inline CreateInline(InlineSpan span)
    {
        return span.Style switch
        {
            InlineStyle.Bold => new Run
            {
                Text = span.Text,
                FontWeight = FontWeights.SemiBold,
            },
            InlineStyle.Italic => new Run
            {
                Text = span.Text,
                FontStyle = Windows.UI.Text.FontStyle.Italic,
            },
            InlineStyle.Code => new Run
            {
                Text = span.Text,
                FontFamily = new FontFamily("Cascadia Mono, Consolas, Courier New"),
            },
            InlineStyle.Link => CreateHyperlink(span),
            _ => new Run { Text = span.Text },
        };
    }

    private static Inline CreateHyperlink(InlineSpan span)
    {
        if (Uri.TryCreate(span.Url, UriKind.Absolute, out var uri) &&
            (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps))
        {
            var link = new Hyperlink { NavigateUri = uri };
            link.Inlines.Add(new Run { Text = span.Text });
            return link;
        }

        return new Run { Text = span.Text };
    }

    private static Brush ResolveBrush(string key, Color fallback)
    {
        if (Application.Current.Resources.TryGetValue(key, out var resource) &&
            resource is Brush brush)
        {
            return brush;
        }

        return new SolidColorBrush(fallback);
    }
}
