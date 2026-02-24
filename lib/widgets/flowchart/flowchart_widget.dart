import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Material, Colors as MColors;
import 'mermaid_parser.dart';
import 'flowchart_layout.dart';
import 'flowchart_painter.dart';

/// Renders a Mermaid flowchart as a native Flutter widget.
/// Supports pan & zoom via InteractiveViewer.
class FlowchartWidget extends StatefulWidget {
  final String mermaidSource;

  const FlowchartWidget({super.key, required this.mermaidSource});

  @override
  State<FlowchartWidget> createState() => _FlowchartWidgetState();
}

class _FlowchartWidgetState extends State<FlowchartWidget> {
  late MermaidGraph _graph;
  late FlowchartLayout _layout;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(FlowchartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidSource != widget.mermaidSource) {
      _parse();
    }
  }

  void _parse() {
    try {
      _graph = parseMermaid(widget.mermaidSource);
      _layout = FlowchartLayout(graph: _graph);
      _parseError = null;
    } catch (e) {
      _parseError = e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_parseError != null || _graph.nodes.isEmpty) {
      // Fallback: show source as code block
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FluentIcons.flow_chart, size: 14, color: theme.accentColor),
                const SizedBox(width: 6),
                Text('Flowchart', style: TextStyle(fontSize: 12, color: theme.accentColor, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              widget.mermaidSource,
              style: TextStyle(fontSize: 12, fontFamily: 'Consolas', color: theme.typography.body?.color),
            ),
          ],
        ),
      );
    }

    final nodeColor = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFFFFFFF);
    final nodeBorder = theme.accentColor;
    final textColor = theme.typography.body?.color ?? (isDark ? MColors.white : MColors.black);
    final edgeColor = isDark ? const Color(0xFF8899AA) : const Color(0xFF667788);
    final labelColor = isDark ? const Color(0xFFAABBCC) : const Color(0xFF556677);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2A) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF333355) : const Color(0xFFDDE0E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(FluentIcons.flow_chart, size: 14, color: theme.accentColor),
                const SizedBox(width: 6),
                Text('Flowchart', style: TextStyle(fontSize: 12, color: theme.accentColor, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${_graph.nodes.length} nodes · ${_graph.edges.length} edges',
                  style: TextStyle(fontSize: 10, color: theme.inactiveColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Chart area with pan/zoom
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: SizedBox(
              height: (_layout.totalHeight).clamp(200.0, 500.0),
              width: double.infinity,
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(60),
                minScale: 0.3,
                maxScale: 3.0,
                child: CustomPaint(
                  size: Size(_layout.totalWidth, _layout.totalHeight),
                  painter: FlowchartPainter(
                    graph: _graph,
                    layout: _layout,
                    nodeColor: nodeColor,
                    nodeBorderColor: nodeBorder,
                    textColor: textColor,
                    edgeColor: edgeColor,
                    labelColor: labelColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
