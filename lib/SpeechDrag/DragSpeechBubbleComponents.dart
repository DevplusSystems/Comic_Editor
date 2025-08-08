import 'package:flutter/material.dart';
enum DragBubbleShape { rectangle, shout }

class DragSpeechBubblePainter extends CustomPainter {
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final DragBubbleShape bubbleShape;
  final Offset tailOffset;

  DragSpeechBubblePainter({
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
    required this.bubbleShape,
    required this.tailOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;

    const double margin = 40;
    const double bubbleHeight = 120;
    const double bubbleWidthMargin = 40;
    const double tailBaseWidth = 30;

    final double left = bubbleWidthMargin;
    final double top = margin;
    final double right = size.width - bubbleWidthMargin;
    final double bottom = margin + bubbleHeight;

    final Rect bubbleRect = Rect.fromLTRB(left, top, right, bottom);

    final dTop = (tailOffset.dy - top).abs();
    final dBottom = (tailOffset.dy - bottom).abs();
    final dLeft = (tailOffset.dx - left).abs();
    final dRight = (tailOffset.dx - right).abs();

    final path = Path();
    switch (bubbleShape) {
      case DragBubbleShape.rectangle:
        _drawRectangleBubble(dTop, dBottom, dLeft, dRight, tailBaseWidth, path,
            left, top, right, bottom);
        break;
      case DragBubbleShape.shout:
        _drawShoutBubble(path, size,left, top, right, bottom);
        break;
    }

    canvas.drawPath(path, paintFill);
    if (borderWidth > 0) {
      canvas.drawPath(path, paintBorder);
    }
  }


  void _drawShoutBubble(Path path, Size size, double left, double top, double right, double bottom) {
    final double w = size.width;
    final double h = size.height;

    const double margin = 12.0;
    const double scale = 0.8;

    final double usableW = w - 2 * margin;
    final double usableH = h - 2 * margin;

    final double bubbleW = usableW * scale;
    final double bubbleH = usableH * scale;

    final double offsetX = (w - bubbleW) / 2;
    final double offsetY = (h - bubbleH) / 2;

    final List<Offset> relativePoints = [
      Offset(0.10, 0.30),
      Offset(0.15, 0.10),
      Offset(0.25, 0.28),
      Offset(0.35, 0.08),
      Offset(0.42, 0.25),
      Offset(0.52, 0.05),
      Offset(0.60, 0.22),
      Offset(0.70, 0.02),
      Offset(0.75, 0.20),
      Offset(0.88, 0.05),
      Offset(0.90, 0.25),
      Offset(0.98, 0.18),
      Offset(0.95, 0.38),
      Offset(1.00, 0.45),
      Offset(0.90, 0.52),
      Offset(0.95, 0.60),
      Offset(0.85, 0.65),
      Offset(0.98, 0.75),
      Offset(0.80, 0.78),
      Offset(0.90, 0.90),
      Offset(0.75, 0.88),
      Offset(0.78, 1.00),
      Offset(0.65, 0.90),
      Offset(0.60, 0.98),
      Offset(0.52, 0.85),
      Offset(0.45, 1.00),
      Offset(0.40, 0.83),
      Offset(0.30, 0.95),
      Offset(0.32, 0.75),
      Offset(0.25, 0.88),
      Offset(0.20, 0.75),
      Offset(0.12, 0.90),
      Offset(0.15, 0.70),
      Offset(0.05, 0.72),
      Offset(0.08, 0.60),
      Offset(0.00, 0.50),
      Offset(0.10, 0.45),
      Offset(0.00, 0.38),
      Offset(0.08, 0.32),
    ];

    final List<Offset> points = relativePoints.map((p) {
      return Offset(
        offsetX + p.dx * bubbleW,
        offsetY + p.dy * bubbleH,
      );
    }).toList();

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.close();
  }

  void _drawRectangleBubble(
      double dTop,
      double dBottom,
      double dLeft,
      double dRight,
      double tailBaseWidth,
      Path path,
      double left,
      double top,
      double right,
      double bottom) {
    if (dTop <= dBottom && dTop <= dLeft && dTop <= dRight) {
      // Tail on top edge
      final cx = tailOffset.dx
          .clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
      final baseLeft = Offset(cx - tailBaseWidth / 2, top);
      final baseRight = Offset(cx + tailBaseWidth / 2, top);

      path.moveTo(baseLeft.dx, baseLeft.dy);
      path.lineTo(tailOffset.dx, tailOffset.dy);
      path.lineTo(baseRight.dx, baseRight.dy);

      // Bubble clockwise
      path.lineTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      path.lineTo(left, top);
      path.close();
    } else if (dBottom <= dLeft && dBottom <= dRight) {
      // Tail on bottom edge
      final cx = tailOffset.dx
          .clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
      final baseLeft = Offset(cx - tailBaseWidth / 2, bottom);
      final baseRight = Offset(cx + tailBaseWidth / 2, bottom);

      path.moveTo(left, top);
      path.lineTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(baseRight.dx, baseRight.dy);
      path.lineTo(tailOffset.dx, tailOffset.dy);
      path.lineTo(baseLeft.dx, baseLeft.dy);
      path.lineTo(left, bottom);
      path.close();
    } else if (dLeft <= dRight) {
      // Tail on left edge
      final cy = tailOffset.dy
          .clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
      final baseTop = Offset(left, cy - tailBaseWidth / 2);
      final baseBottom = Offset(left, cy + tailBaseWidth / 2);

      path.moveTo(baseTop.dx, baseTop.dy);
      path.lineTo(tailOffset.dx, tailOffset.dy);
      path.lineTo(baseBottom.dx, baseBottom.dy);

      // Bubble clockwise
      path.lineTo(left, bottom);
      path.lineTo(right, bottom);
      path.lineTo(right, top);
      path.lineTo(left, top);
      path.close();
    } else {
      // Tail on right edge
      final cy = tailOffset.dy
          .clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
      final baseTop = Offset(right, cy - tailBaseWidth / 2);
      final baseBottom = Offset(right, cy + tailBaseWidth / 2);

      path.moveTo(left, top);
      path.lineTo(right, top);
      path.lineTo(baseTop.dx, baseTop.dy);
      path.lineTo(tailOffset.dx, tailOffset.dy);
      path.lineTo(baseBottom.dx, baseBottom.dy);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      path.close();
    }
  }

  @override
  bool shouldRepaint(covariant DragSpeechBubblePainter oldDelegate) =>
      oldDelegate.tailOffset != tailOffset ||
      oldDelegate.bubbleColor != bubbleColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}