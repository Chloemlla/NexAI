import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/lumen_tokens.dart';
import 'package:provider/provider.dart';

import '../providers/notes_provider.dart';
import 'note_detail_page.dart';
import '../widgets/lumen/lumen.dart';

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
  String _layoutSignature = '';
  int _layoutVersion = 0;
  GraphData? _signedGraphData;
  final Map<String, Offset> _nodePositions = {};

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

    // Preserve previous positions for known nodes (title/content edits keep signature
    // unchanged but getGraphData returns fresh GraphNode instances at 0,0).
    for (final n in nodes) {
      final prev = _nodePositions[n.id];
      if (prev != null) {
        n.x = prev.dx;
        n.y = prev.dy;
      } else {
        n.x = rng.nextDouble() * size.width * 0.6 + size.width * 0.2;
        n.y = rng.nextDouble() * size.height * 0.6 + size.height * 0.2;
      }
    }

    // Only re-run force layout when topology changed (_layoutDone is false).
    // When signature is unchanged we already restored positions above.
    if (_layoutDone) {
      _storeNodePositions(nodes);
      return;
    }

    // Simple force-directed layout, capped at `iterations` but stopped as soon
    // as the graph settles.
    const iterations = 120;
    const repulsion = 8000.0;
    const attraction = 0.005;
    const damping = 0.9;
    const settledStep = 0.05;

    final count = nodes.length;
    final vx = List<double>.filled(count, 0);
    final vy = List<double>.filled(count, 0);

    // Resolve edge endpoints to indices once instead of scanning `nodes` for
    // every edge on every iteration.
    final indexOf = <String, int>{};
    for (int i = 0; i < count; i++) {
      indexOf[nodes[i].id] = i;
    }
    final edgeA = <int>[];
    final edgeB = <int>[];
    for (final e in edges) {
      final a = indexOf[e.sourceId];
      final b = indexOf[e.targetId];
      if (a != null && b != null) {
        edgeA.add(a);
        edgeB.add(b);
      }
    }

    for (int iter = 0; iter < iterations; iter++) {
      final temp = 1.0 - iter / iterations;

      // Repulsion between all pairs
      for (int i = 0; i < count; i++) {
        final a = nodes[i];
        for (int j = i + 1; j < count; j++) {
          final b = nodes[j];
          var dx = a.x - b.x;
          var dy = a.y - b.y;
          final dist = math.sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
          final force = repulsion / (dist * dist);
          dx = dx / dist * force * temp;
          dy = dy / dist * force * temp;
          vx[i] += dx;
          vy[i] += dy;
          vx[j] -= dx;
          vy[j] -= dy;
        }
      }

      // Attraction along edges
      for (int k = 0; k < edgeA.length; k++) {
        final i = edgeA[k];
        final j = edgeB[k];
        final dx = (nodes[j].x - nodes[i].x) * attraction * temp;
        final dy = (nodes[j].y - nodes[i].y) * attraction * temp;
        vx[i] += dx;
        vy[i] += dy;
        vx[j] -= dx;
        vy[j] -= dy;
      }

      // Apply velocities
      var maxStep = 0.0;
      for (int i = 0; i < count; i++) {
        final dx = vx[i] * damping;
        final dy = vy[i] * damping;
        nodes[i].x += dx;
        nodes[i].y += dy;
        vx[i] = dx;
        vy[i] = dy;
        final step = dx.abs() + dy.abs();
        if (step > maxStep) maxStep = step;
      }

      // Converged: further iterations would only burn CPU/battery.
      if (maxStep < settledStep) break;
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
    _storeNodePositions(nodes);
  }

  void _storeNodePositions(List<GraphNode> nodes) {
    _layoutVersion++;
    _nodePositions
      ..clear()
      ..addEntries(nodes.map((n) => MapEntry(n.id, Offset(n.x, n.y))));
  }

  String _computeLayoutSignature(GraphData graphData) {
    final nodeIds = graphData.nodes.map((node) => node.id).toList()..sort();
    final edges =
        graphData.edges
            .map((edge) => '${edge.sourceId}->${edge.targetId}')
            .toList()
          ..sort();
    return '${nodeIds.join('|')}::${edges.join('|')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<NotesProvider>();
    _graphData = provider.getGraphData(
      tagFilter: _tagFilter,
      starredOnly: _starredOnly ? true : null,
    );
    // getGraphData memoizes per filter, so an unchanged instance means the
    // topology is unchanged: skip re-sorting/joining the signature strings.
    final layoutSignature = identical(_signedGraphData, _graphData)
        ? _layoutSignature
        : _computeLayoutSignature(_graphData);
    _signedGraphData = _graphData;
    if (layoutSignature != _layoutSignature) {
      _layoutSignature = layoutSignature;
      _layoutDone = false;
      // Drop positions for removed nodes; keep survivors for warm start.
      final liveIds = _graphData.nodes.map((n) => n.id).toSet();
      _nodePositions.removeWhere((id, _) => !liveIds.contains(id));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _transformController.value = Matrix4.identity();
      });
      if (_highlightedNodeId != null &&
          !_graphData.nodes.any((node) => node.id == _highlightedNodeId)) {
        _highlightedNodeId = null;
      }
    } else {
      // Topology unchanged: restore coordinates onto fresh GraphNode instances.
      for (final n in _graphData.nodes) {
        final prev = _nodePositions[n.id];
        if (prev != null) {
          n.x = prev.dx;
          n.y = prev.dy;
        }
      }
      if (_nodePositions.isNotEmpty) {
        _layoutDone = true;
      }
    }

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
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
                        '#${t.name}${_tagFilter == t.name ? ' (已选)' : ''}',
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
                        layoutVersion: _layoutVersion,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _buildNodeOverlays(cs),
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

  /// Hit targets and labels for every node, built in one pass with the label
  /// text styles hoisted out of the per-node loop.
  List<Widget> _buildNodeOverlays(ColorScheme cs) {
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant,
      height: 1.3,
    );
    final highlightedLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: cs.primary,
      height: 1.3,
    );

    final hitTargets = <Widget>[];
    final labels = <Widget>[];
    for (final node in _graphData.nodes) {
      final radius = _nodeRadius(node);
      final isHighlighted = _highlightedNodeId == node.id;
      void toggleHighlight() => setState(() {
        _highlightedNodeId = isHighlighted ? null : node.id;
      });

      // Hit target on the actual node circle (the painted canvas is not tappable).
      final hit = (radius + 10) * 2;
      hitTargets.add(
        Positioned(
          left: node.x - hit / 2,
          top: node.y - hit / 2,
          width: hit,
          height: hit,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onNodeTap(node),
            onLongPress: toggleHighlight,
            child: Semantics(
              button: true,
              label: node.title,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Labels under nodes remain secondary hit targets.
      final labelWidth = math.max((radius + 20) * 2, 80.0);
      labels.add(
        Positioned(
          left: node.x - labelWidth / 2,
          top: node.y + radius + 4,
          child: GestureDetector(
            onTap: () => _onNodeTap(node),
            onLongPress: toggleHighlight,
            child: SizedBox(
              width: labelWidth,
              // The circle hit target above already exposes the title to
              // screen readers; keep each node a single semantic button.
              child: ExcludeSemantics(
                child: Text(
                  node.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: isHighlighted ? highlightedLabelStyle : labelStyle,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return hitTargets..addAll(labels);
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
            // Lowercase the query once per rebuild instead of once per node.
            final lowerQuery = query.toLowerCase();
            final matches = query.isEmpty
                ? <GraphNode>[]
                : _graphData.nodes
                      .where((n) => n.title.toLowerCase().contains(lowerQuery))
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
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
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
                                borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
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
    // Distinguish "no notes at all" from "the active filter matched nothing",
    // otherwise the hint tells users to create notes they already have.
    final isFiltered = _tagFilter != null || _starredOnly;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? Icons.filter_alt_off_rounded : Icons.hub_outlined,
            size: 64,
            color: cs.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? '没有符合筛选条件的节点' : '还没有笔记节点',
            style: TextStyle(
              color: cs.outline,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? '试试清除标签或星标筛选'
                : '创建笔记后会出现在图谱中；使用 [[笔记名称]] 可建立连接',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outlineVariant, fontSize: 13),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _tagFilter = null;
                _starredOnly = false;
              }),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('清除筛选'),
            ),
          ],
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
  final int layoutVersion;

  _GraphPainter({
    required this.graphData,
    required this.highlightedNodeId,
    required this.colorBy,
    required this.colorScheme,
    required this.layoutVersion,
  });

  // Reused across every edge/node instead of allocating per draw call.
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint();

  late final Map<String, GraphNode> _nodeMap = {
    for (final n in graphData.nodes) n.id: n,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = _nodeMap;

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

      final edgeColor = isConnected
          ? colorScheme.primary.withAlpha(highlightedNodeId != null ? 180 : 80)
          : colorScheme.outlineVariant.withAlpha(30);
      _strokePaint
        ..color = edgeColor
        ..strokeWidth = isConnected && highlightedNodeId != null ? 2.0 : 1.0;

      canvas.drawLine(
        Offset(source.x, source.y),
        Offset(target.x, target.y),
        _strokePaint,
      );

      // Draw arrow
      if (isConnected) {
        _drawArrow(canvas, source, target, edgeColor);
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

      final center = Offset(node.x, node.y);

      // Glow for highlighted
      if (isHighlighted) {
        canvas.drawCircle(
          center,
          radius + 6,
          _fillPaint..color = nodeColor.withAlpha(60),
        );
      }

      // Node circle
      canvas.drawCircle(
        center,
        radius,
        _fillPaint..color = nodeColor.withAlpha(alpha),
      );

      // Border
      canvas.drawCircle(
        center,
        radius,
        _strokePaint
          ..color = isHighlighted
              ? colorScheme.primary
              : nodeColor.withAlpha((alpha * 0.6).round())
          ..strokeWidth = isHighlighted ? 3.0 : 1.5,
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    GraphNode source,
    GraphNode target,
    Color color,
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
    canvas.drawPath(path, _fillPaint..color = color);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.highlightedNodeId != highlightedNodeId ||
      oldDelegate.colorBy != colorBy ||
      oldDelegate.layoutVersion != layoutVersion ||
      oldDelegate.colorScheme != colorScheme ||
      !identical(oldDelegate.graphData, graphData);
}
