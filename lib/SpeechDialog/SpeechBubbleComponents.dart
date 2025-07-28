import 'package:flutter/material.dart';
import 'dart:math' as math;

enum BubbleShape {
  oval,
  rectangle,
  cloud,
  thought,
  shout,
}

enum TailPosition {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight,
  leftCenter,
  rightCenter,
  none,
}

class SpeechBubblePainter extends CustomPainter {
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final BubbleShape bubbleShape;
  final TailPosition tailPosition;

  SpeechBubblePainter({
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
    required this.bubbleShape,
    required this.tailPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    switch (bubbleShape) {
      case BubbleShape.oval:
        _drawOvalBubble(path, size);
        break;
      case BubbleShape.rectangle:
        _drawRectangleBubble(path, size);
        break;
      case BubbleShape.cloud:
        _drawCloudBubble(path, size);
        break;
      case BubbleShape.thought:
        _drawThoughtBubble(path, size);
        break;
      case BubbleShape.shout:
        _drawShoutBubble(path, size);
        break;
    }

    // Add tail if needed
    if (tailPosition != TailPosition.none) {
      _addTail(path, size);
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawOvalBubble(Path path, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.8);
    path.addOval(rect);
  }

  void _drawRectangleBubble(Path path, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.8);
    path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
  }

  void _drawCloudBubble(Path path, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.8);

    // Create cloud-like shape with multiple circles
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final radius = rect.width / 6;

    // Main body
    path.addOval(Rect.fromCenter(center: rect.center, width: rect.width * 0.8, height: rect.height * 0.6));

    // Cloud bumps
    path.addOval(Rect.fromCenter(center: Offset(centerX - radius, centerY - radius/2), width: radius * 2, height: radius * 2));
    path.addOval(Rect.fromCenter(center: Offset(centerX + radius, centerY - radius/2), width: radius * 2, height: radius * 2));
    path.addOval(Rect.fromCenter(center: Offset(centerX, centerY - radius), width: radius * 1.5, height: radius * 1.5));
  }

  void _drawThoughtBubble(Path path, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.7);

    // Main thought bubble (cloud-like)
    _drawCloudBubble(path, Size(size.width, size.height * 0.7));

    // Add small thought circles
    final circle1 = Rect.fromCenter(
      center: Offset(size.width * 0.2, size.height * 0.85),
      width: size.width * 0.1,
      height: size.width * 0.1,
    );
    final circle2 = Rect.fromCenter(
      center: Offset(size.width * 0.1, size.height * 0.95),
      width: size.width * 0.06,
      height: size.width * 0.06,
    );

    path.addOval(circle1);
    path.addOval(circle2);
  }

  void _drawShoutBubble(Path path, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.8);

    // Create jagged/spiky border
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final radiusX = rect.width / 2;
    final radiusY = rect.height / 2;

    path.moveTo(centerX + radiusX, centerY);

    for (int i = 0; i < 16; i++) {
      final angle = (i * 2 * math.pi) / 16;
      final isSpike = i % 2 == 0;
      final radiusMultiplier = isSpike ? 0.9 : 1.0;
      final x = centerX + radiusX * radiusMultiplier * math.cos(angle);
      final y = centerY + radiusY * radiusMultiplier * math.sin(angle);
      path.lineTo(x, y);
    }

    path.close();
  }

  void _addTail(Path path, Size size) {
    switch (tailPosition) {
      case TailPosition.bottomLeft:
        path.moveTo(size.width * 0.2, size.height * 0.8);
        path.lineTo(size.width * 0.1, size.height);
        path.lineTo(size.width * 0.3, size.height * 0.8);
        break;
      case TailPosition.bottomRight:
        path.moveTo(size.width * 0.8, size.height * 0.8);
        path.lineTo(size.width * 0.9, size.height);
        path.lineTo(size.width * 0.7, size.height * 0.8);
        break;
      case TailPosition.topLeft:
        path.moveTo(size.width * 0.2, size.height * 0.1);
        path.lineTo(size.width * 0.1, 0);
        path.lineTo(size.width * 0.3, size.height * 0.1);
        break;
      case TailPosition.topRight:
        path.moveTo(size.width * 0.8, size.height * 0.1);
        path.lineTo(size.width * 0.9, 0);
        path.lineTo(size.width * 0.7, size.height * 0.1);
        break;
      case TailPosition.leftCenter:
        path.moveTo(size.width * 0.1, size.height * 0.4);
        path.lineTo(0, size.height * 0.5);
        path.lineTo(size.width * 0.1, size.height * 0.6);
        break;
      case TailPosition.rightCenter:
        path.moveTo(size.width * 0.9, size.height * 0.4);
        path.lineTo(size.width, size.height * 0.5);
        path.lineTo(size.width * 0.9, size.height * 0.6);
        break;
      case TailPosition.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
