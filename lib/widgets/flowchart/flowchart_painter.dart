import 'dart:math' as math;
import 'dart:ui' as ui;
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

    canvas.drawRRect(rect, Paint()..color = nodeBorderColor.withOpacity(0.08));
    canvas.drawRRect(rect, Paint()
      ..color = nodeBorderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Subgraph label
    final tp = TextPainter(
      text: TextSpan(text: sg.label, style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(minX - pad + 8, minY - pad - 16));
  }

  void _drawEdge(Canvas canvas, MermaidEdge edge) {
    final from = layout.positions[edge.fromId];
    final to = layout.positions[edge.toId];
    if (from == null || to == null) return;

    final fromCenter = Offset(from.dx + nodeWidth / 2, from.dy + nodeHeight / 2);
    final toCenter = Offset(to.dx + nodeWidth / 2, to.dy + nodeHeight / 2);

    // Clip to node boundary
    final fromPt = _clipToNodeBoundary(fromCenter, toCenter);
    final toPt = _clipToNodeBoundary(toCenter, fromCenter);

    final paint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    if (edge.isDashed) {
      _drawDashedLine(canvas, fromPt, toPt, paint);
    } else {
      canvas.drawLine(fromPt, toPt, paint);
    }

    // Arrowhead
    _drawArrowhead(canvas, fromPt, toPt, edgeColor);

    // Edge label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final mid = Offset((fromPt.dx + toPt.dx) / 2, (fromPt.dy + toPt.dy) / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: edge.label,
          style: TextStyle(fontSize: 11, color: labelColor, backgroundColor: nodeColor.withOpacity(0.9)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bgRect = Rect.fromCenter(center: mid, width: tp.width + 8, height: tp.height + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = nodeColor.withOpacity(0.95),
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

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Color color) {
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

    canvas.drawPath(path, Paint()..color = color);
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
    final paint = Paint()..color = nodeColor;
    final borderPaint = Paint()
      ..color = nodeBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (node.shape) {
      case MermaidNodeShape.rectangle:
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, borderPaint);
        break;
      case MermaidNodeShape.rounded:
      case MermaidNodeShape.stadium:
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(nodeHeight / 2));
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
    final tp = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: nodeWidth - 12);

    tp.paint(canvas, Offset(
      rect.center.dx - tp.width / 2,
      rect.center.dy - tp.height / 2,
    ));
  }

  @override
  bool shouldRepaint(FlowchartPainter oldDelegate) =>
      graph != oldDelegate.graph || nodeColor != oldDelegate.nodeColor;
}
