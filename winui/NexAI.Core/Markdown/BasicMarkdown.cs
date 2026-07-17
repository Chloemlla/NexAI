using System.Text;
using System.Text.RegularExpressions;

namespace NexAI.Core.Markdown;

public enum MarkdownBlockKind
{
    Paragraph,
    Heading,
    Code,
    List,
    Quote,
}

public sealed class MarkdownBlock
{
    public MarkdownBlockKind Kind { get; init; }
    public int HeadingLevel { get; init; }
    public string Text { get; init; } = string.Empty;
    public string? Language { get; init; }
    public IReadOnlyList<string>? ListItems { get; init; }
}

public static partial class BasicMarkdown
{
    [GeneratedRegex(@"^(#{1,6})\s+(.*)$")]
    private static partial Regex HeadingRegex();

    [GeneratedRegex(@"^\s*([-*+]|\d+\.)\s+(.*)$")]
    private static partial Regex ListItemRegex();

    [GeneratedRegex(@"`{3,}([^\n`]*)\n([\s\S]*?)`{3,}", RegexOptions.Multiline)]
    private static partial Regex FencedCodeRegex();

    public static IReadOnlyList<MarkdownBlock> Parse(string? markdown)
    {
        if (string.IsNullOrWhiteSpace(markdown))
        {
            return [new MarkdownBlock { Kind = MarkdownBlockKind.Paragraph, Text = string.Empty }];
        }

        var normalized = markdown.Replace("\r\n", "\n").Replace('\r', '\n');
        var blocks = new List<MarkdownBlock>();
        var index = 0;

        while (index < normalized.Length)
        {
            // Fenced code blocks
            if (normalized.AsSpan(index).StartsWith("```"))
            {
                var fenceEnd = normalized.IndexOf('\n', index);
                if (fenceEnd < 0)
                {
                    blocks.Add(new MarkdownBlock
                    {
                        Kind = MarkdownBlockKind.Code,
                        Text = normalized[index..],
                    });
                    break;
                }

                var language = normalized[(index + 3)..fenceEnd].Trim();
                var bodyStart = fenceEnd + 1;
                var close = normalized.IndexOf("\n```", bodyStart, StringComparison.Ordinal);
                if (close < 0)
                {
                    blocks.Add(new MarkdownBlock
                    {
                        Kind = MarkdownBlockKind.Code,
                        Language = string.IsNullOrWhiteSpace(language) ? null : language,
                        Text = normalized[bodyStart..].TrimEnd('\n'),
                    });
                    break;
                }

                blocks.Add(new MarkdownBlock
                {
                    Kind = MarkdownBlockKind.Code,
                    Language = string.IsNullOrWhiteSpace(language) ? null : language,
                    Text = normalized[bodyStart..close].TrimEnd('\n'),
                });

                index = close + 4;
                if (index < normalized.Length && normalized[index] == '\n')
                {
                    index++;
                }

                continue;
            }

            var lineEnd = normalized.IndexOf('\n', index);
            if (lineEnd < 0)
            {
                lineEnd = normalized.Length;
            }

            var line = normalized[index..lineEnd];
            if (string.IsNullOrWhiteSpace(line))
            {
                index = lineEnd + 1;
                continue;
            }

            var heading = HeadingRegex().Match(line);
            if (heading.Success)
            {
                blocks.Add(new MarkdownBlock
                {
                    Kind = MarkdownBlockKind.Heading,
                    HeadingLevel = heading.Groups[1].Value.Length,
                    Text = heading.Groups[2].Value.Trim(),
                });
                index = lineEnd + 1;
                continue;
            }

            if (line.StartsWith('>'))
            {
                var quoteLines = new List<string>();
                while (index < normalized.Length)
                {
                    var qEnd = normalized.IndexOf('\n', index);
                    if (qEnd < 0)
                    {
                        qEnd = normalized.Length;
                    }

                    var qLine = normalized[index..qEnd];
                    if (!qLine.StartsWith('>'))
                    {
                        break;
                    }

                    quoteLines.Add(qLine.TrimStart('>', ' ', '\t'));
                    index = qEnd + 1;
                    if (qEnd == normalized.Length)
                    {
                        break;
                    }
                }

                blocks.Add(new MarkdownBlock
                {
                    Kind = MarkdownBlockKind.Quote,
                    Text = string.Join("\n", quoteLines),
                });
                continue;
            }

            var listMatch = ListItemRegex().Match(line);
            if (listMatch.Success)
            {
                var items = new List<string>();
                while (index < normalized.Length)
                {
                    var lEnd = normalized.IndexOf('\n', index);
                    if (lEnd < 0)
                    {
                        lEnd = normalized.Length;
                    }

                    var lLine = normalized[index..lEnd];
                    var itemMatch = ListItemRegex().Match(lLine);
                    if (!itemMatch.Success)
                    {
                        break;
                    }

                    items.Add(itemMatch.Groups[2].Value.Trim());
                    index = lEnd + 1;
                    if (lEnd == normalized.Length)
                    {
                        break;
                    }
                }

                blocks.Add(new MarkdownBlock
                {
                    Kind = MarkdownBlockKind.List,
                    ListItems = items,
                    Text = string.Join("\n", items),
                });
                continue;
            }

            // Paragraph: consume until blank line or special block start.
            var paragraph = new StringBuilder();
            while (index < normalized.Length)
            {
                var pEnd = normalized.IndexOf('\n', index);
                if (pEnd < 0)
                {
                    pEnd = normalized.Length;
                }

                var pLine = normalized[index..pEnd];
                if (string.IsNullOrWhiteSpace(pLine) ||
                    pLine.StartsWith("```", StringComparison.Ordinal) ||
                    HeadingRegex().IsMatch(pLine) ||
                    ListItemRegex().IsMatch(pLine) ||
                    pLine.StartsWith('>'))
                {
                    break;
                }

                if (paragraph.Length > 0)
                {
                    paragraph.Append('\n');
                }

                paragraph.Append(pLine);
                index = pEnd + 1;
                if (pEnd == normalized.Length)
                {
                    break;
                }
            }

            blocks.Add(new MarkdownBlock
            {
                Kind = MarkdownBlockKind.Paragraph,
                Text = paragraph.ToString(),
            });
        }

        return blocks.Count == 0
            ? [new MarkdownBlock { Kind = MarkdownBlockKind.Paragraph, Text = normalized }]
            : blocks;
    }

    /// <summary>
    /// Tokenize inline markdown into plain text segments with simple styles.
    /// Supported: **bold**, *italic*, `code`, [label](url)
    /// </summary>
    public static IReadOnlyList<InlineSpan> ParseInlines(string? text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return [new InlineSpan(string.Empty, InlineStyle.Plain)];
        }

        var spans = new List<InlineSpan>();
        var i = 0;
        while (i < text.Length)
        {
            if (text[i] == '`' )
            {
                var close = text.IndexOf('`', i + 1);
                if (close > i)
                {
                    spans.Add(new InlineSpan(text[(i + 1)..close], InlineStyle.Code));
                    i = close + 1;
                    continue;
                }
            }

            if (i + 1 < text.Length && text[i] == '*' && text[i + 1] == '*')
            {
                var close = text.IndexOf("**", i + 2, StringComparison.Ordinal);
                if (close > i)
                {
                    spans.Add(new InlineSpan(text[(i + 2)..close], InlineStyle.Bold));
                    i = close + 2;
                    continue;
                }
            }

            if (text[i] == '*')
            {
                var close = text.IndexOf('*', i + 1);
                if (close > i)
                {
                    spans.Add(new InlineSpan(text[(i + 1)..close], InlineStyle.Italic));
                    i = close + 1;
                    continue;
                }
            }

            if (text[i] == '[')
            {
                var labelEnd = text.IndexOf(']', i + 1);
                if (labelEnd > i &&
                    labelEnd + 1 < text.Length &&
                    text[labelEnd + 1] == '(')
                {
                    var urlEnd = text.IndexOf(')', labelEnd + 2);
                    if (urlEnd > labelEnd)
                    {
                        var label = text[(i + 1)..labelEnd];
                        var url = text[(labelEnd + 2)..urlEnd];
                        spans.Add(new InlineSpan(label, InlineStyle.Link, url));
                        i = urlEnd + 1;
                        continue;
                    }
                }
            }

            var next = IndexOfAnyStyleStart(text, i + 1);
            spans.Add(new InlineSpan(text[i..next], InlineStyle.Plain));
            i = next;
        }

        return spans;
    }

    private static int IndexOfAnyStyleStart(string text, int start)
    {
        for (var i = start; i < text.Length; i++)
        {
            var c = text[i];
            if (c is '`' or '*' or '[')
            {
                return i;
            }
        }

        return text.Length;
    }
}

public enum InlineStyle
{
    Plain,
    Bold,
    Italic,
    Code,
    Link,
}

public readonly record struct InlineSpan(string Text, InlineStyle Style, string? Url = null);
