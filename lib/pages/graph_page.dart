import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notes_provider.dart';
import 'note_detail_page.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage>
    with SingleTickerProviderStateMixin {
  String? _tagFilter;
  bool _starredOnly = false;

  String? _highlightedNodeId;
  String _colorBy = 'links'; // links, starred, tags

  // Transform for pan/zoom
  final TransformationController _transformController =
      TransformationController();

  // Force-directed layout state
  late GraphData _graphData;
  bool _layoutDone = false;

  @override
  void initState() {
    super.initState();
    _graphData = GraphData(nodes: [], edges: []);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _runLayout(Size size) {
    if (_graphData.nodes.isEmpty) return;
    final rng = math.Random(42);
    final nodes = _graphData.nodes;
    final edges = _graphData.edges;

    // Initialize random positions
    for (final n in nodes) {
      n.x = rng.nextDouble() * size.width * 0.6 + size.width * 0.2;
      n.y = rng.nextDouble() * size.height * 0.6 + size.height * 0.2;
    }

    // Build adjacency for quick lookup
    final adj = <String, Set<String>>{};
    for (final n in nodes) {
      adj[n.id] = {};
    }
    for (final e in edges) {
      adj[e.sourceId]?.add(e.targetId);
      adj[e.targetId]?.add(e.sourceId);
    }

    // Simple force-directed layout (100 iterations)
    const iterations = 120;
    const repulsion = 8000.0;
    const attraction = 0.005;
    const damping = 0.9;
    final velocities = {for (final n in nodes) n.id: Offset.zero};

    for (int iter = 0; iter < iterations; iter++) {
      final temp = 1.0 - iter / iterations;

      // Repulsion between all pairs
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          var dx = a.x - b.x;
          var dy = a.y - b.y;
          final dist = math.sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
          final force = repulsion / (dist * dist);
          dx = dx / dist * force * temp;
          dy = dy / dist * force * temp;
          velocities[a.id] = velocities[a.id]! + Offset(dx, dy);
          velocities[b.id] = velocities[b.id]! - Offset(dx, dy);
        }
      }

      // Attraction along edges
      for (final e in edges) {
        final a = nodes.firstWhere((n) => n.id == e.sourceId);
        final b = nodes.firstWhere((n) => n.id == e.targetId);
        var dx = b.x - a.x;
        var dy = b.y - a.y;

        dx = dx * attraction * temp;
        dy = dy * attraction * temp;
        velocities[a.id] = velocities[a.id]! + Offset(dx, dy);
        velocities[b.id] = velocities[b.id]! - Offset(dx, dy);
      }

      // Apply velocities
      for (final n in nodes) {
        final v = velocities[n.id]! * damping;
        n.x += v.dx;
        n.y += v.dy;
        velocities[n.id] = v;
      }
    }

    // Center the graph
    if (nodes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final n in nodes) {
        if (n.x < minX) minX = n.x;
        if (n.y < minY) minY = n.y;
        if (n.x > maxX) maxX = n.x;
        if (n.y > maxY) maxY = n.y;
      }
      final cx = (minX + maxX) / 2;
      final cy = (minY + maxY) / 2;
      final targetCx = size.width / 2;
      final targetCy = size.height / 2;
      for (final n in nodes) {
        n.x += targetCx - cx;
        n.y += targetCy - cy;
      }
    }

    _layoutDone = true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<NotesProvider>();
    _graphData = provider.getGraphData(
      tagFilter: _tagFilter,
      starredOnly: _starredOnly ? true : null,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: cs.surfaceTint,
        title: Row(
          children: [
            Icon(Icons.hub_rounded, size: 22, color: cs.primary),
            const SizedBox(width: 10),
            const Text(
              '知识图谱',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const Spacer(),
            Text(
              '${_graphData.nodes.length} 个节点 · ${_graphData.edges.length} 条链接',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ],
        ),
        actions: [
          // Search
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => _showSearchDialog(cs, provider),
            tooltip: '搜索节点',
          ),
          // Filter
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onSelected: (v) {
              if (v == 'clear') {
                setState(() {
                  _tagFilter = null;
                  _starredOnly = false;
                });
              } else if (v == 'starred') {
                setState(() => _starredOnly = !_starredOnly);
              } else if (v.startsWith('tag:')) {
                setState(() => _tagFilter = v.substring(4));
              } else if (v.startsWith('color:')) {
                setState(() => _colorBy = v.substring(6));
              }
            },
            itemBuilder: (_) {
              final tags = provider.allTags.take(10).toList();
              return [
                const PopupMenuItem(value: 'clear', child: Text('清除筛选')),
                PopupMenuItem(
                  value: 'starred',
                  child: Row(
                    children: [
                      Icon(
                        _starredOnly
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text('仅显示星标'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(enabled: false, child: Text('按以下方式着色')),
                PopupMenuItem(
                  value: 'color:links',
                  child: Text(_colorBy == 'links' ? '● 链接数' : '○ 链接数'),
                ),
                PopupMenuItem(
                  value: 'color:starred',
                  child: Text(_colorBy == 'starred' ? '● 星标' : '○ 星标'),
                ),
                PopupMenuItem(
                  value: 'color:tags',
                  child: Text(_colorBy == 'tags' ? '● 标签' : '○ 标签'),
                ),
                if (tags.isNotEmpty) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(enabled: false, child: Text('按标签筛选')),
                  ...tags.map(
                    (t) => PopupMenuItem(
                      value: 'tag:${t.name}',
                      child: Text(
                        '#${t.name}${_tagFilter == t.name ? ' ✓' : ''}',
                      ),
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
      body: _graphData.nodes.isEmpty
          ? _buildEmptyState(cs)
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  math.max(constraints.maxWidth, 800),
                  math.max(constraints.maxHeight, 600),
                );
                if (!_layoutDone) _runLayout(size);
                return InteractiveViewer(
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.1,
                  maxScale: 4.0,
                  child: SizedBox(
                    width: size.width * 2,
                    height: size.height * 2,
                    child: CustomPaint(
                      painter: _GraphPainter(
                        graphData: _graphData,
                        highlightedNodeId: _highlightedNodeId,
                        colorBy: _colorBy,
                        colorScheme: cs,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _graphData.nodes.map((node) {
                          final radius = _nodeRadius(node);
                          final isHighlighted = _highlightedNodeId == node.id;
                          final labelWidth = math.max((radius + 20) * 2, 80.0);
                          return Positioned(
                            left: node.x - labelWidth / 2,
                            top: node.y + radius + 4,
                            child: GestureDetector(
                              onTap: () => _onNodeTap(node),
                              onLongPress: () => setState(() {
                                _highlightedNodeId =
                                    _highlightedNodeId == node.id
                                    ? null
                                    : node.id;
                              }),
                              child: SizedBox(
                                width: labelWidth,
                                child: Text(
                                  node.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isHighlighted ? 12 : 10,
                                    fontWeight: isHighlighted
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isHighlighted
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  double _nodeRadius(GraphNode node) {
    return (8.0 + node.linkCount * 3.0).clamp(8.0, 28.0);
  }

  void _onNodeTap(GraphNode node) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: node.id)));
  }

  void _showSearchDialog(ColorScheme cs, NotesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final matches = query.isEmpty
                ? <GraphNode>[]
                : _graphData.nodes
                      .where(
                        (n) =>
                            n.title.toLowerCase().contains(query.toLowerCase()),
                      )
                      .take(10)
                      .toList();
            return AlertDialog(
              title: const Text('搜索节点'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setDialogState(() => query = v),
                      decoration: InputDecoration(
                        hintText: '笔记标题...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (matches.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          itemBuilder: (_, idx) {
                            final n = matches[idx];
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              title: Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${n.linkCount} 条链接',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.outline,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                setState(() => _highlightedNodeId = n.id);
                                // Pan to node
                                _transformController.value =
                                    Matrix4.translationValues(
                                      -n.x + 200,
                                      -n.y + 300,
                                      0,
                                    );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '还没有连接',
            style: TextStyle(
              color: cs.outline,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在笔记中使用 [[笔记名称]] 来创建链接',
            style: TextStyle(color: cs.outlineVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final GraphData graphData;
  final String? highlightedNodeId;
  final String colorBy;
  final ColorScheme colorScheme;

  _GraphPainter({
    required this.graphData,
    required this.highlightedNodeId,
    required this.colorBy,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in graphData.nodes) n.id: n};

    // Find connected nodes for highlighting
    final connectedIds = <String>{};
    if (highlightedNodeId != null) {
      connectedIds.add(highlightedNodeId!);
      for (final e in graphData.edges) {
        if (e.sourceId == highlightedNodeId) connectedIds.add(e.targetId);
        if (e.targetId == highlightedNodeId) connectedIds.add(e.sourceId);
      }
    }

    // Draw edges
    for (final edge in graphData.edges) {
      final source = nodeMap[edge.sourceId];
      final target = nodeMap[edge.targetId];
      if (source == null || target == null) continue;

      final isConnected =
          highlightedNodeId == null ||
          connectedIds.contains(edge.sourceId) &&
              connectedIds.contains(edge.targetId);

      final paint = Paint()
        ..color = isConnected
            ? colorScheme.primary.withAlpha(
                highlightedNodeId != null ? 180 : 80,
              )
            : colorScheme.outlineVariant.withAlpha(30)
        ..strokeWidth = isConnected && highlightedNodeId != null ? 2.0 : 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(source.x, source.y),
        Offset(target.x, target.y),
        paint,
      );

      // Draw arrow
      if (isConnected) {
        _drawArrow(canvas, source, target, paint);
      }
    }

    // Draw nodes
    for (final node in graphData.nodes) {
      final radius = (8.0 + node.linkCount * 3.0).clamp(8.0, 28.0);
      final isHighlighted = node.id == highlightedNodeId;
      final isConnected =
          highlightedNodeId == null || connectedIds.contains(node.id);
      final alpha = isConnected ? 255 : 60;

      Color nodeColor;
      switch (colorBy) {
        case 'starred':
          nodeColor = node.isStarred ? Colors.amber : colorScheme.primary;
          break;
        case 'tags':
          nodeColor = node.tags.isEmpty
              ? colorScheme.outline
              : HSLColor.fromAHSL(
                  1.0,
                  (node.tags.first.hashCode % 360).toDouble(),
                  0.6,
                  0.5,
                ).toColor();
          break;
        default: // links
          final hue = (node.linkCount * 30.0).clamp(0.0, 270.0);
          nodeColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
      }

      // Glow for highlighted
      if (isHighlighted) {
        canvas.drawCircle(
          Offset(node.x, node.y),
          radius + 6,
          Paint()..color = nodeColor.withAlpha(60),
        );
      }

      // Node circle
      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        Paint()..color = nodeColor.withAlpha(alpha),
      );

      // Border
      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        Paint()
          ..color = isHighlighted
              ? colorScheme.primary
              : nodeColor.withAlpha((alpha * 0.6).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 3.0 : 1.5,
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    GraphNode source,
    GraphNode target,
    Paint paint,
  ) {
    final dx = target.x - source.x;
    final dy = target.y - source.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final targetRadius = (8.0 + target.linkCount * 3.0).clamp(8.0, 28.0);
    final ux = dx / dist;
    final uy = dy / dist;
    final tipX = target.x - ux * (targetRadius + 4);
    final tipY = target.y - uy * (targetRadius + 4);
    const arrowSize = 8.0;
    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(
        tipX - arrowSize * ux + arrowSize * 0.4 * uy,
        tipY - arrowSize * uy - arrowSize * 0.4 * ux,
      )
      ..lineTo(
        tipX - arrowSize * ux - arrowSize * 0.4 * uy,
        tipY - arrowSize * uy + arrowSize * 0.4 * ux,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.highlightedNodeId != highlightedNodeId ||
      oldDelegate.colorBy != colorBy ||
      oldDelegate.graphData != graphData;
}
