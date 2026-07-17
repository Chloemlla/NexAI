using System.Text.RegularExpressions;
using NexAI.Core.Markdown;

namespace NexAI.Core.Markdown;

public enum AdvancedBlockKind
{
    Latex,
    Mermaid,
}

public sealed class AdvancedBlock
{
    public AdvancedBlockKind Kind { get; init; }
    public string Content { get; init; } = string.Empty;
}

public static partial class AdvancedMarkdown
{
    [GeneratedRegex(@"\$\$([\s\S]+?)\$\$", RegexOptions.Multiline)]
    private static partial Regex BlockLatexRegex();

    [GeneratedRegex(@"(?<!\$)\$(?!\$)([^$\n]+?)\$(?!\$)")]
    private static partial Regex InlineLatexRegex();

    [GeneratedRegex(@"```mermaid\s*([\s\S]*?)```", RegexOptions.IgnoreCase)]
    private static partial Regex MermaidRegex();

    public static bool ContainsLatex(string? text)
        => !string.IsNullOrWhiteSpace(text) &&
           (BlockLatexRegex().IsMatch(text!) || InlineLatexRegex().IsMatch(text!));

    public static bool ContainsMermaid(string? text)
        => !string.IsNullOrWhiteSpace(text) && MermaidRegex().IsMatch(text!);

    public static IReadOnlyList<AdvancedBlock> Extract(string? text)
    {
        var source = text ?? string.Empty;
        var blocks = new List<AdvancedBlock>();

        foreach (Match match in MermaidRegex().Matches(source))
        {
            blocks.Add(new AdvancedBlock
            {
                Kind = AdvancedBlockKind.Mermaid,
                Content = match.Groups[1].Value.Trim(),
            });
        }

        foreach (Match match in BlockLatexRegex().Matches(source))
        {
            blocks.Add(new AdvancedBlock
            {
                Kind = AdvancedBlockKind.Latex,
                Content = match.Groups[1].Value.Trim(),
            });
        }

        foreach (Match match in InlineLatexRegex().Matches(source))
        {
            blocks.Add(new AdvancedBlock
            {
                Kind = AdvancedBlockKind.Latex,
                Content = match.Groups[1].Value.Trim(),
            });
        }

        return blocks;
    }

    public static string StripAdvanced(string? text)
    {
        var source = text ?? string.Empty;
        source = MermaidRegex().Replace(source, string.Empty);
        source = BlockLatexRegex().Replace(source, string.Empty);
        return source;
    }
}
