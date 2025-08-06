import 'dart:math' as math;
import 'package:flutter/material.dart';



// rounded corner
/*
class DragSpeechBubblePainter extends CustomPainter {
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final Offset tailOffset;

  DragSpeechBubblePainter({
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
    required this.tailOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 40.0;
    const bubbleHeight = 120.0;
    const cornerRadius = 10.0;
    const tailBaseWidth = 24.0;
    const tailInset = -4.0; // 👈 Shift tail inside the bubble

    final left = margin;
    final top = margin;
    final right = size.width - margin;
    final bottom = top + bubbleHeight;

    final RRect bubble = RRect.fromLTRBR(
      left,
      top,
      right,
      bottom,
      const Radius.circular(cornerRadius),
    );

    /// Closest point on bubble edge
    Offset getClosestPointOnRRectEdge(RRect rrect, Offset target) {
      final path = Path()..addRRect(rrect);
      final metric = path.computeMetrics().first;
      Offset? closest;
      double minDist = double.infinity;

      for (int i = 0; i <= 500; i++) {
        final pos = metric.getTangentForOffset(metric.length * i / 500)!.position;
        final dist = (pos - target).distance;
        if (dist < minDist) {
          minDist = dist;
          closest = pos;
        }
      }
      return closest ?? target;
    }

    final rawBaseCenter = getClosestPointOnRRectEdge(bubble, tailOffset);

    // 👇 Move base center slightly inside the bubble
    final direction = (tailOffset - rawBaseCenter).direction;
    final baseCenter = rawBaseCenter.translate(
      tailInset * math.cos(direction),
      tailInset * math.sin(direction),
    );

    final dx = tailBaseWidth / 2 * math.cos(direction + math.pi / 2);
    final dy = tailBaseWidth / 2 * math.sin(direction + math.pi / 2);
    final baseLeft = baseCenter.translate(-dx, -dy);
    final baseRight = baseCenter.translate(dx, dy);

    // === Fill Path ===
    final fillPaint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final fillPath = Path()
      ..addRRect(bubble)
      ..moveTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(tailOffset.dx, tailOffset.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    canvas.drawPath(fillPath, fillPaint);

    // === Border Paint ===
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // === Border Path ===
    final borderPath = Path();
    final bubblePath = Path()..addRRect(bubble);
    final metric = bubblePath.computeMetrics().first;

    const segments = 1000;
    final length = metric.length;

    for (int i = 0; i < segments; i++) {
      final t1 = i / segments;
      final t2 = (i + 1) / segments;

      final p1 = metric.getTangentForOffset(t1 * length)!.position;
      final p2 = metric.getTangentForOffset(t2 * length)!.position;

      // Skip small segment around the tail base
      final isInTailBase = ((p1 - rawBaseCenter).distance < tailBaseWidth * 0.6) &&
          ((p2 - rawBaseCenter).distance < tailBaseWidth * 0.6);
      if (isInTailBase) continue;

      borderPath.moveTo(p1.dx, p1.dy);
      borderPath.lineTo(p2.dx, p2.dy);
    }

    // Tail border path (merged)
    borderPath.moveTo(baseLeft.dx, baseLeft.dy);
    borderPath.lineTo(tailOffset.dx, tailOffset.dy);
    borderPath.lineTo(baseRight.dx, baseRight.dy);

    if (borderWidth > 0) {
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DragSpeechBubblePainter oldDelegate) {
    return tailOffset != oldDelegate.tailOffset ||
        bubbleColor != oldDelegate.bubbleColor ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth;
  }
}
*/


enum DragBubbleShape { rectangle }

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

    if (dTop <= dBottom && dTop <= dLeft && dTop <= dRight) {
      // Tail on top edge
      final cx = tailOffset.dx.clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
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
      final cx = tailOffset.dx.clamp(left + tailBaseWidth / 2, right - tailBaseWidth / 2);
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
      final cy = tailOffset.dy.clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
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
      final cy = tailOffset.dy.clamp(top + tailBaseWidth / 2, bottom - tailBaseWidth / 2);
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

    canvas.drawPath(path, paintFill);
    if (borderWidth > 0) {
      canvas.drawPath(path, paintBorder);
    }
  }

  @override
  bool shouldRepaint(covariant DragSpeechBubblePainter oldDelegate) =>
      oldDelegate.tailOffset != tailOffset ||
          oldDelegate.bubbleColor != bubbleColor ||
          oldDelegate.borderColor != borderColor ||
          oldDelegate.borderWidth != borderWidth;
}




/*

*/

/*
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
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // === Bubble settings ===
    const double margin = 40;
    const double bubbleHeight = 120;
    final double bubbleTop = margin;
    final double bubbleWidth = size.width - (2 * margin);
    final Rect bubbleRect = Rect.fromLTWH(margin, bubbleTop, bubbleWidth, bubbleHeight);

    // === Clamp tail to stay below bubble only ===
    final double minTailY = bubbleRect.bottom + 10;
    final double maxTailY = size.height - 10;
    final double clampedTailY = tailOffset.dy.clamp(minTailY, maxTailY);

    final double clampedTailX = tailOffset.dx.clamp(
      bubbleRect.left + 15,
      bubbleRect.right - 15,
    );

    // === Tail base calculation ===
    const double tailBaseWidth = 30;
    final double baseLeftX = (clampedTailX - tailBaseWidth / 2)
        .clamp(bubbleRect.left + 2, bubbleRect.right - tailBaseWidth - 2);
    final double baseRightX = baseLeftX + tailBaseWidth;
    final double baseY = bubbleRect.bottom;

    // === Bubble path (no rounded corners) ===
    final Path path = Path();

    path.moveTo(bubbleRect.left, bubbleRect.top); // Top-left
    path.lineTo(bubbleRect.right, bubbleRect.top); // Top-right
    path.lineTo(bubbleRect.right, bubbleRect.bottom); // Bottom-right (before tail)
    path.lineTo(baseRightX, baseY); // Tail base right
    path.lineTo(clampedTailX, clampedTailY); // Tail tip
    path.lineTo(baseLeftX, baseY); // Tail base left
    path.lineTo(bubbleRect.left, bubbleRect.bottom); // Bottom-left
    path.lineTo(bubbleRect.left, bubbleRect.top); // Back to start

    path.close();

    // === Paint ===
    canvas.drawPath(path, paintFill);
    if (borderWidth > 0) canvas.drawPath(path, paintBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
*/

