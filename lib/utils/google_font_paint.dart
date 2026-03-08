import 'package:flutter/material.dart';

/// Google Logo 画笔，可在 CustomPaint 中直接使用。
///
/// 使用示例:
/// ```dart
/// CustomPaint(
///   painter: GoogleLogoPainter(),
///   size: Size.square(200),
/// )
/// ```
class GoogleLogoPainter extends CustomPainter {
  @override
  bool shouldRepaint(_) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final length = size.width;
    final verticalOffset = (size.height / 2) - (length / 2);
    final bounds = Offset(0, verticalOffset) & Size.square(length);
    final center = bounds.center;
    final arcThickness = size.width / 4.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcThickness;

    void drawArc(double startAngle, double sweepAngle, Color color) {
      final arcPaint = paint..color = color;
      canvas.drawArc(bounds, startAngle, sweepAngle, false, arcPaint);
    }

    drawArc(3.5, 1.9, Colors.red);
    drawArc(2.5, 1.0, Colors.amber);
    drawArc(0.9, 1.6, Colors.green.shade600);
    drawArc(-0.18, 1.1, Colors.blue.shade600);

    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - (arcThickness / 2),
        bounds.centerRight.dx + (arcThickness / 2) - 4,
        bounds.centerRight.dy + (arcThickness / 2),
      ),
      paint
        ..color = Colors.blue.shade600
        ..style = PaintingStyle.fill
        ..strokeWidth = 0,
    );
  }
}

/// 可直接嵌入到任何 Widget 树中的 Google Logo 组件。
///
/// [size] 控制 Logo 的尺寸，默认 300。
/// [backgroundColor] 控制背景颜色，默认白色。
///
/// 使用示例:
/// ```dart
/// // 基础用法
/// GoogleLogo()
///
/// // 自定义大小和背景色
/// GoogleLogo(size: 120, backgroundColor: Colors.transparent)
/// ```
class GoogleLogo extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const GoogleLogo({
    super.key,
    this.size = 300,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: backgroundColor,
      child: CustomPaint(painter: GoogleLogoPainter(), size: Size.square(size)),
    );
  }
}

/// 便捷方法：将 Google Logo 绘制到指定的 Canvas 上。
///
/// 可以在自定义的 CustomPainter 中直接调用此方法来合成绘制 Google Logo。
///
/// [canvas] 绘制目标画布。
/// [size] Logo 的绘制区域大小。
///
/// 使用示例:
/// ```dart
/// class MyPainter extends CustomPainter {
///   @override
///   void paint(Canvas canvas, Size size) {
///     paintGoogleLogo(canvas, Size.square(100));
///   }
///   @override
///   bool shouldRepaint(_) => false;
/// }
/// ```
void paintGoogleLogo(Canvas canvas, Size size) {
  GoogleLogoPainter().paint(canvas, size);
}
