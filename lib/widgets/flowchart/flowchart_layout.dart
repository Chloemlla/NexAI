import 'dart:math' as math;
import 'dart:ui';
import 'mermaid_parser.dart';

/// Computes positions for each node using a layered graph layout (Sugiyama-style).
class FlowchartLayout {
  final MermaidGraph graph;
  final double nodeWidth;
  final double nodeHeight;
  final double horizontalGap;
  final double verticalGap;

  late Map<String, Offset> positions;
  late double totalWidth;
  late double totalHeight;

  FlowchartLayout({
    required this.graph,
    this.nodeWidth = 140,
    this.nodeHeight = 48,
    this.horizontalGap = 40,
    this.verticalGap = 60,
  }) {
    _computeLayout();
  }

  void _computeLayout() {
    positions = {};
    if (graph.nodes.isEmpty) {
      totalWidth = 0;
      totalHeight = 0;
      return;
    }

    // Build adjacency
    final adj = <String, List<String>>{};
    final inDeg = <String, int>{};
    for (final n in graph.nodes) {
      adj[n.id] = [];
      inDeg[n.id] = 0;
    }
    for (final e in graph.edges) {
      adj[e.fromId]?.add(e.toId);
      inDeg[e.toId] = (inDeg[e.toId] ?? 0) + 1;
    }

    // Topological layering via BFS (Kahn's algorithm)
    final layers = <List<String>>[];
    final queue = <String>[];
    final layerOf = <String, int>{};

    for (final n in graph.nodes) {
      if ((inDeg[n.id] ?? 0) == 0) queue.add(n.id);
    }

    // Handle cycles: if no root found, pick first node
    if (queue.isEmpty && graph.nodes.isNotEmpty) {
      queue.add(graph.nodes.first.id);
    }

    while (queue.isNotEmpty) {
      final current = List<String>.from(queue);
      queue.clear();
      final layer = <String>[];

      for (final id in current) {
        if (layerOf.containsKey(id)) continue;
        layerOf[id] = layers.length;
        layer.add(id);
      }

      if (layer.isEmpty) break;
      layers.add(layer);

      for (final id in layer) {
        for (final next in (adj[id] ?? [])) {
          inDeg[next] = (inDeg[next] ?? 1) - 1;
          if ((inDeg[next] ?? 0) <= 0 && !layerOf.containsKey(next)) {
            queue.add(next);
          }
        }
      }
    }

    // Add any unplaced nodes to last layer
    for (final n in graph.nodes) {
      if (!layerOf.containsKey(n.id)) {
        if (layers.isEmpty) layers.add([]);
        layers.last.add(n.id);
        layerOf[n.id] = layers.length - 1;
      }
    }

    final isHorizontal = graph.direction == MermaidDirection.leftRight ||
        graph.direction == MermaidDirection.rightLeft;

    // Compute positions
    double maxPrimary = 0;
    double maxSecondary = 0;

    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      for (int j = 0; j < layer.length; j++) {
        final id = layer[j];
        double primary = i * (isHorizontal ? (nodeWidth + horizontalGap) : (nodeHeight + verticalGap));
        double secondary = j * (isHorizontal ? (nodeHeight + verticalGap) : (nodeWidth + horizontalGap));

        // Center layers
        final layerSize = layer.length;
        final totalSecondary = layerSize * (isHorizontal ? (nodeHeight + verticalGap) : (nodeWidth + horizontalGap)) - (isHorizontal ? verticalGap : horizontalGap);
        final offset = -totalSecondary / 2 + j * (isHorizontal ? (nodeHeight + verticalGap) : (nodeWidth + horizontalGap));

        if (isHorizontal) {
          positions[id] = Offset(primary, offset + 300); // 300 as center offset
        } else {
          positions[id] = Offset(offset + 400, primary); // 400 as center offset
        }

        maxPrimary = math.max(maxPrimary, primary + (isHorizontal ? nodeWidth : nodeHeight));
        maxSecondary = math.max(maxSecondary, (offset + 300).abs() + (isHorizontal ? nodeHeight : nodeWidth));
      }
    }

    // Normalize positions to start from padding
    const padding = 30.0;
    double minX = double.infinity, minY = double.infinity;
    for (final pos in positions.values) {
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
    }
    final normalized = <String, Offset>{};
    double maxX = 0, maxY = 0;
    for (final entry in positions.entries) {
      final np = Offset(entry.value.dx - minX + padding, entry.value.dy - minY + padding);
      normalized[entry.key] = np;
      maxX = math.max(maxX, np.dx + nodeWidth);
      maxY = math.max(maxY, np.dy + nodeHeight);
    }
    positions = normalized;
    totalWidth = maxX + padding;
    totalHeight = maxY + padding;
  }
}
