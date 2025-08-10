import 'package:flutter/cupertino.dart';

import 'DragSpeechBubbleComponents.dart';
import 'DragSpeechBubbleData.dart';

class SpeechBubblePainterWithText extends CustomPainter {
  final DragSpeechBubbleData d;

  SpeechBubblePainterWithText(this.d);

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = d.bubbleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintBorder = Paint()
      ..color = d.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.borderWidth
      ..isAntiAlias = true;


    const double margin = 40;
    const double bubbleHeight = 120;
    const double bubbleWidthMargin = 50;
    const double tailBaseWidth = 20;



    // Add:
    const double kTailPlay = 10.0; // space around bubble for tail

// Replace your left/right/top/bottom with:
    final double left   = bubbleWidthMargin + kTailPlay;
    final double right  = size.width - bubbleWidthMargin - kTailPlay;
    final double top    = margin + kTailPlay * 0.4;      // optional top space
    final double bottom = top + bubbleHeight;



    final Rect bubbleRect = Rect.fromLTRB(left, top, right, bottom);

    final dTop = (d.tailOffset.dy - top).abs();
    final dBottom = (d.tailOffset.dy - bottom).abs();
    final dLeft = (d.tailOffset.dx - left).abs();
    final dRight = (d.tailOffset.dx - right).abs();

    final path = Path();
    switch (d.bubbleShape) {
      case DragBubbleShape.rectangle:
        _drawRectangleBubble(dTop, dBottom, dLeft, dRight, tailBaseWidth, path,
            left, top, right, bottom);
        break;
      case DragBubbleShape.shout:
        _drawShoutBubble(path, size,left, top, right, bottom);
        break;
    }

    canvas.drawPath(path, paintFill);
    if (d.borderWidth > 0) {
      canvas.drawPath(path, paintBorder);
    }
    // ---------- TEXT (add this block) ----------
    final double inset = d.padding; // or a fixed 8.0
    final Rect textRect = bubbleRect.deflate(inset);

    if ((d.text.isNotEmpty) && textRect.width > 0 && textRect.height > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: d.text,
          style: TextStyle(
            color: d.textColor,
            fontSize: d.fontSize,
            fontWeight: d.fontWeight,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(minWidth: textRect.width, maxWidth: textRect.width);
      // If you want exact vertical+horizontal centering instead:
      final Offset centered = Offset(
        textRect.left + (textRect.width - tp.width) / 2,
        textRect.top  + (textRect.height - tp.height) / 2,
      );
      tp.paint(canvas, centered);
    }
  }

  void _drawShoutBubble(
      Path path,
      Size size,
      double left,
      double top,
      double right,
      double bottom,
      )
  {
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
      const Offset(0.10, 0.30), const Offset(0.15, 0.10), const Offset(0.25, 0.28),
      const Offset(0.35, 0.08), const Offset(0.42, 0.25), const Offset(0.52, 0.05),
      const Offset(0.60, 0.22), const Offset(0.70, 0.02), const Offset(0.75, 0.20),
      const Offset(0.88, 0.05), const Offset(0.90, 0.25), const Offset(0.98, 0.18),
      const Offset(0.95, 0.38), const Offset(1.00, 0.45), const Offset(0.90, 0.52),
      const Offset(0.95, 0.60), const Offset(0.85, 0.65), const Offset(0.98, 0.75),
      const Offset(0.80, 0.78), const Offset(0.90, 0.90), const Offset(0.75, 0.88),
      const Offset(0.78, 1.00), const Offset(0.65, 0.90), const Offset(0.60, 0.98),
      const Offset(0.52, 0.85), const Offset(0.45, 1.00), const Offset(0.40, 0.83),
      const Offset(0.30, 0.95), const Offset(0.32, 0.75), const Offset(0.25, 0.88),
      const Offset(0.20, 0.75), const Offset(0.12, 0.90), const Offset(0.15, 0.70),
      const Offset(0.05, 0.72), const Offset(0.08, 0.60), const Offset(0.00, 0.50),
      const Offset(0.10, 0.45), const Offset(0.00, 0.38), const Offset(0.08, 0.32),
    ];

    final points = relativePoints
        .map((p) => Offset(offsetX + p.dx * bubbleW, offsetY + p.dy * bubbleH))
        .toList();

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
      double bottom)
  {
    if (dTop <= dBottom && dTop <= dLeft && dTop <= dRight) {
      // Tail on top edge
      final cx = d.tailOffset.dx
          .clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
      final baseLeft = Offset(cx - tailBaseWidth / 2, top);
      final baseRight = Offset(cx + tailBaseWidth / 2, top);

      path.moveTo(baseLeft.dx, baseLeft.dy);
      path.lineTo(d.tailOffset.dx, d.tailOffset.dy);
      path.lineTo(baseRight.dx, baseRight.dy);

      // Bubble clockwise
      path.lineTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      path.lineTo(left, top);
      path.close();
    } else if (dBottom <= dLeft && dBottom <= dRight) {
      // Tail on bottom edge
      final cx = d.tailOffset.dx
          .clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
      final baseLeft = Offset(cx - tailBaseWidth / 2, bottom);
      final baseRight = Offset(cx + tailBaseWidth / 2, bottom);

      path.moveTo(left, top);
      path.lineTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(baseRight.dx, baseRight.dy);
      path.lineTo(d.tailOffset.dx, d.tailOffset.dy);
      path.lineTo(baseLeft.dx, baseLeft.dy);
      path.lineTo(left, bottom);
      path.close();
    } else if (dLeft <= dRight) {
      // Tail on left edge
      final cy = d.tailOffset.dy
          .clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
      final baseTop = Offset(left, cy - tailBaseWidth / 2);
      final baseBottom = Offset(left, cy + tailBaseWidth / 2);

      path.moveTo(baseTop.dx, baseTop.dy);
      path.lineTo(d.tailOffset.dx, d.tailOffset.dy);
      path.lineTo(baseBottom.dx, baseBottom.dy);

      // Bubble clockwise
      path.lineTo(left, bottom);
      path.lineTo(right, bottom);
      path.lineTo(right, top);
      path.lineTo(left, top);
      path.close();
    } else {
      // Tail on right edge
      final cy = d.tailOffset.dy
          .clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
      final baseTop = Offset(right, cy - tailBaseWidth / 2);
      final baseBottom = Offset(right, cy + tailBaseWidth / 2);

      path.moveTo(left, top);
      path.lineTo(right, top);
      path.lineTo(baseTop.dx, baseTop.dy);
      path.lineTo(d.tailOffset.dx, d.tailOffset.dy);
      path.lineTo(baseBottom.dx, baseBottom.dy);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      path.close();
    }
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePainterWithText old) => old.d != d;

}
