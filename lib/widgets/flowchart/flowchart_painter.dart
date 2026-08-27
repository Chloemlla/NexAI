import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mermaid_parser.dart';
import 'flowchart_layout.dart';

class FlowchartPainter extends CustomPainter {
  final MermaidGraph graph;
  final FlowchartLayout layout;
  final Color nodeColor;
  final Color nodeBorderColor;
  final Color textColor;
  final Color edgeColor;
  final Color labelColor;
  final double nodeWidth;
  final double nodeHeight;

  FlowchartPainter({
    required this.graph,
    required this.layout,
    required this.nodeColor,
    required this.nodeBorderColor,
    required this.textColor,
    required this.edgeColor,
    required this.labelColor,
    this.nodeWidth = 140,
    this.nodeHeight = 48,
  });

  // Paints and label styles depend only on the constructor colors, so they are
  // built once per painter instead of once per node/edge on every repaint
  // (InteractiveViewer pan & zoom repaints the whole canvas each frame).
  late final Paint _nodeFillPaint = Paint()..color = nodeColor;
  late final Paint _nodeBorderPaint = Paint()
    ..color = nodeBorderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  late final Paint _edgePaint = Paint()
    ..color = edgeColor
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;
  late final Paint _arrowFillPaint = Paint()..color = edgeColor;
  late final Paint _subgraphFillPaint = Paint()
    ..color = nodeBorderColor.withAlpha((0.08 * 255).round());
  late final Paint _subgraphBorderPaint = Paint()
    ..color = nodeBorderColor.withAlpha((0.3 * 255).round())
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  late final Paint _labelBackgroundPaint = Paint()
    ..color = nodeColor.withAlpha((0.95 * 255).round());

  late final TextStyle _nodeLabelStyle = TextStyle(
    fontSize: 12,
    color: textColor,
    fontWeight: FontWeight.w500,
  );
  late final TextStyle _edgeLabelStyle = TextStyle(
    fontSize: 11,
    color: labelColor,
    backgroundColor: nodeColor.withAlpha((0.9 * 255).round()),
  );
  late final TextStyle _subgraphLabelStyle = TextStyle(
    fontSize: 11,
    color: labelColor,
    fontWeight: FontWeight.w600,
  );

  /// Laid-out text keyed by `kind:label`; text layout is the dominant cost
  /// of a repaint and none of it changes while the graph and colors are fixed.
  final Map<String, TextPainter> _textPainters = {};

  TextPainter _nodeLabelPainter(String label) {
    return _textPainters.putIfAbsent(
      'n:$label',
      () => TextPainter(
        text: TextSpan(text: label, style: _nodeLabelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: nodeWidth - 12),
    );
  }

  TextPainter _edgeLabelPainter(String label) {
    return _textPainters.putIfAbsent(
      'e:$label',
      () => TextPainter(
        text: TextSpan(text: label, style: _edgeLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  TextPainter _subgraphLabelPainter(String label) {
    return _textPainters.putIfAbsent(
      's:$label',
      () => TextPainter(
        text: TextSpan(text: label, style: _subgraphLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subgraph backgrounds
    for (final sg in graph.subgraphs) {
      _drawSubgraph(canvas, sg);
    }

    // Draw edges first (behind nodes)
    for (final edge in graph.edges) {
      _drawEdge(canvas, edge);
    }

    // Draw nodes
    for (final node in graph.nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawSubgraph(Canvas canvas, MermaidSubgraph sg) {
    if (sg.nodeIds.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final nid in sg.nodeIds) {
      final pos = layout.positions[nid];
      if (pos == null) continue;
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx + nodeWidth);
      maxY = math.max(maxY, pos.dy + nodeHeight);
    }

    if (minX == double.infinity) return;

    const pad = 16.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(minX - pad, minY - pad - 20, maxX + pad, maxY + pad),
      const Radius.circular(8),
    );

    canvas.drawRRect(rect, _subgraphFillPaint);
    canvas.drawRRect(rect, _subgraphBorderPaint);

    // Subgraph label
    final tp = _subgraphLabelPainter(sg.label);
    tp.paint(canvas, Offset(minX - pad + 8, minY - pad - 16));
  }

  void _drawEdge(Canvas canvas, MermaidEdge edge) {
    final from = layout.positions[edge.fromId];
    final to = layout.positions[edge.toId];
    if (from == null || to == null) return;

    // Handle self-loop node
    if (edge.fromId == edge.toId) {
      _drawSelfLoop(canvas, from, edge);
      return;
    }

    final fromCenter = Offset(
      from.dx + nodeWidth / 2,
      from.dy + nodeHeight / 2,
    );
    final toCenter = Offset(to.dx + nodeWidth / 2, to.dy + nodeHeight / 2);

    // Clip to node boundary
    final fromPt = _clipToNodeBoundary(fromCenter, toCenter);
    final toPt = _clipToNodeBoundary(toCenter, fromCenter);

    if (edge.isDashed) {
      _drawDashedLine(canvas, fromPt, toPt, _edgePaint);
    } else {
      canvas.drawLine(fromPt, toPt, _edgePaint);
    }

    // Arrowhead
    _drawArrowhead(canvas, fromPt, toPt);

    // Edge label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final mid = Offset((fromPt.dx + toPt.dx) / 2, (fromPt.dy + toPt.dy) / 2);
      final tp = _edgeLabelPainter(edge.label!);
      final bgRect = Rect.fromCenter(
        center: mid,
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        _labelBackgroundPaint,
      );
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  Offset _clipToNodeBoundary(Offset center, Offset target) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx == 0 && dy == 0) return center;

    final hw = nodeWidth / 2;
    final hh = nodeHeight / 2;

    // Scale to hit rectangle boundary
    double sx = dx != 0 ? hw / dx.abs() : double.infinity;
    double sy = dy != 0 ? hh / dy.abs() : double.infinity;
    double s = math.min(sx, sy);

    return Offset(center.dx + dx * s, center.dy + dy * s);
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowLen = 10.0;
    const arrowAngle = 0.45;

    final p1 = Offset(
      to.dx - arrowLen * math.cos(angle - arrowAngle),
      to.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - arrowLen * math.cos(angle + arrowAngle),
      to.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(path, _arrowFillPaint);
  }

  void _drawSelfLoop(Canvas canvas, Offset nodePos, MermaidEdge edge) {
    final cx = nodePos.dx + nodeWidth / 2;
    final cy = nodePos.dy + nodeHeight / 2;
    final loopRadius = 20.0;
    final loopTop = cy - nodeHeight / 2 - loopRadius * 2;

    final path = Path()
      ..moveTo(cx + nodeWidth / 2, cy - nodeHeight / 2)
      ..quadraticBezierTo(
        cx + nodeWidth / 2 + loopRadius,
        loopTop,
        cx,
        loopTop,
      )
      ..quadraticBezierTo(
        cx - nodeWidth / 2 - loopRadius,
        loopTop,
        cx - nodeWidth / 2,
        cy - nodeHeight / 2,
      );

    if (edge.isDashed) {
      _drawDashedPath(canvas, path, _edgePaint);
    } else {
      canvas.drawPath(path, _edgePaint);
    }

    // Arrowhead at the end of the loop
    _drawArrowhead(
      canvas,
      Offset(cx - nodeWidth / 2, cy - nodeHeight / 2 + 2),
      Offset(cx - nodeWidth / 2, cy - nodeHeight / 2),
    );

    // Edge label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final tp = _edgeLabelPainter(edge.label!);
      final labelPos = Offset(cx - tp.width / 2, loopTop - tp.height - 4);
      final bgRect = Rect.fromCenter(
        center: Offset(cx, loopTop - tp.height / 2 - 2),
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        _labelBackgroundPaint,
      );
      tp.paint(canvas, labelPos);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + 8.0).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += 14.0;
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    const dashLen = 6.0;
    const gapLen = 4.0;
    final ux = dx / dist;
    final uy = dy / dist;

    double d = 0;
    while (d < dist) {
      final end = math.min(d + dashLen, dist);
      canvas.drawLine(
        Offset(from.dx + ux * d, from.dy + uy * d),
        Offset(from.dx + ux * end, from.dy + uy * end),
        paint,
      );
      d = end + gapLen;
    }
  }

  void _drawNode(Canvas canvas, MermaidNode node) {
    final pos = layout.positions[node.id];
    if (pos == null) return;

    final rect = Rect.fromLTWH(pos.dx, pos.dy, nodeWidth, nodeHeight);
    final paint = _nodeFillPaint;
    final borderPaint = _nodeBorderPaint;

    switch (node.shape) {
      case MermaidNodeShape.rectangle:
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, borderPaint);
        break;
      case MermaidNodeShape.rounded:
      case MermaidNodeShape.stadium:
        final rr = RRect.fromRectAndRadius(
          rect,
          Radius.circular(nodeHeight / 2),
        );
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, borderPaint);
        break;
      case MermaidNodeShape.circle:
        final r = math.max(nodeWidth, nodeHeight) / 2;
        final center = Offset(pos.dx + nodeWidth / 2, pos.dy + nodeHeight / 2);
        canvas.drawCircle(center, r, paint);
        canvas.drawCircle(center, r, borderPaint);
        break;
      case MermaidNodeShape.diamond:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, borderPaint);
        break;
      case MermaidNodeShape.hexagon:
        final inset = nodeWidth * 0.15;
        final path = Path()
          ..moveTo(rect.left + inset, rect.top)
          ..lineTo(rect.right - inset, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.right - inset, rect.bottom)
          ..lineTo(rect.left + inset, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, borderPaint);
        break;
    }

    // Node label
    final tp = _nodeLabelPainter(node.label);

    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(FlowchartPainter oldDelegate) =>
      graph != oldDelegate.graph ||
      layout != oldDelegate.layout ||
      nodeColor != oldDelegate.nodeColor ||
      nodeBorderColor != oldDelegate.nodeBorderColor ||
      textColor != oldDelegate.textColor ||
      edgeColor != oldDelegate.edgeColor ||
      labelColor != oldDelegate.labelColor;
}
