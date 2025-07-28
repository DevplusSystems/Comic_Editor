import 'dart:ui';

import 'package:flutter/cupertino.dart';

class DrawingElementPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingElementPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Determine the original bounding box of points
    final nonZeroPoints = points.where((p) => p != Offset.zero).toList();
    if (nonZeroPoints.isEmpty) return;

    final minX = nonZeroPoints.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final minY = nonZeroPoints.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxX = nonZeroPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxY = nonZeroPoints.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    final originalWidth = maxX - minX;
    final originalHeight = maxY - minY;

    final scaleX = size.width / originalWidth;
    final scaleY = size.height / originalHeight;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        final p1 = Offset(
          (points[i].dx - minX) * scaleX,
          (points[i].dy - minY) * scaleY,
        );
        final p2 = Offset(
          (points[i + 1].dx - minX) * scaleX,
          (points[i + 1].dy - minY) * scaleY,
        );
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingElementPainter oldDelegate) =>
      oldDelegate.points != points ||
          oldDelegate.color != color ||
          oldDelegate.strokeWidth != strokeWidth;
}
