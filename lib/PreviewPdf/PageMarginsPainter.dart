import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PageMarginsPainter extends CustomPainter {
  final double marginSize;
  final double pageWidth;
  final double pageHeight;

  PageMarginsPainter({
    required this.marginSize,
    required this.pageWidth,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw margin rectangle
    final marginRect = Rect.fromLTWH(
      marginSize,
      marginSize,
      pageWidth - (2 * marginSize),
      pageHeight - (2 * marginSize),
    );

    canvas.drawRect(marginRect, paint);

    // Draw corner markers
    final cornerPaint = Paint()
      ..color = Colors.blue.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final cornerSize = 8.0;

    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(marginSize - cornerSize/2, marginSize - cornerSize/2, cornerSize, cornerSize),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(pageWidth - marginSize - cornerSize/2, marginSize - cornerSize/2, cornerSize, cornerSize),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawRect(
      Rect.fromLTWH(marginSize - cornerSize/2, pageHeight - marginSize - cornerSize/2, cornerSize, cornerSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawRect(
      Rect.fromLTWH(pageWidth - marginSize - cornerSize/2, pageHeight - marginSize - cornerSize/2, cornerSize, cornerSize),
      cornerPaint,
    );

    // Optional: Draw dashed lines for margins (if you want dashed effect)
    _drawDashedRect(canvas, marginRect, paint);
  }

  // Helper method to draw dashed rectangle (optional)
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;

    // Top line
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );

    // Right line
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );

    // Bottom line
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );

    // Left line
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );
  }

  // Helper method to draw dashed line
  void _drawDashedLine(
      Canvas canvas,
      Offset start,
      Offset end,
      Paint paint,
      double dashWidth,
      double dashSpace,
      ) {
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    final direction = (end - start) / distance;

    for (int i = 0; i < dashCount; i++) {
      final dashStart = start + direction * (dashWidth + dashSpace) * i.toDouble();
      final dashEnd = dashStart + direction * dashWidth;
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
