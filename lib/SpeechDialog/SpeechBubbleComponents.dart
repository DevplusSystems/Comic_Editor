import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'dart:math' as math;

enum BubbleShape {
/*
  oval,
*/
  rectangle,
  shout
}
enum TailPosition {
  bottomLeft,
  bottomRight,
  bottomCenter,
  topLeft,
  topRight,
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
     /* case BubbleShape.oval:
        _drawOvalBubble(path, size);
        break;*/
      case BubbleShape.rectangle:
        _drawRectangleBubble(path, size);
        break;
      case BubbleShape.shout:
        _drawShoutBubble(path, size);
        break;
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

/*
  void _drawOvalBubble(Path path, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double tailWidth = w * 0.18;  // width of tail
    final double tailHeight = h * 0.25; // height of tail

    final double bodyHeight = h - tailHeight;

    // Start at top center of the oval
    path.moveTo(w / 2, 0);

    // Top-right curve
    path.quadraticBezierTo(w, 0, w, bodyHeight / 2);

    // Bottom-right curve
    path.quadraticBezierTo(w, bodyHeight, w / 2, bodyHeight);

    // Tail insertion (bottom-left)
    path.lineTo(w * 0.35, bodyHeight);                  // approach tail
    path.lineTo(w * 0.20, h);                           // tip of tail
    path.lineTo(w * 0.25, bodyHeight);                  // back to body

    // Bottom-left curve
    path.quadraticBezierTo(0, bodyHeight, 0, bodyHeight / 2);

    // Top-left curve
    path.quadraticBezierTo(0, 0, w / 2, 0);

    path.close();
  }
*/
  void _drawOvalBubble(Path path, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double tailWidth = w * 0.18;
    final double tailHeight = h * 0.20;

    final bool hasTopTail = tailPosition == TailPosition.topLeft || tailPosition == TailPosition.topRight;
    final bool hasBottomTail = tailPosition == TailPosition.bottomLeft || tailPosition == TailPosition.bottomCenter || tailPosition == TailPosition.bottomRight;

    final double top = hasTopTail ? tailHeight : 0;
    final double bottom = hasBottomTail ? h - tailHeight : h;

    // Start at top center
    path.moveTo(w / 2, top);

    // Top-right curve
    path.quadraticBezierTo(w, top, w, (top + bottom) / 2);
    path.quadraticBezierTo(w, bottom, w / 2, bottom);

    // ➤ Bottom tail insertions
    if (tailPosition == TailPosition.bottomLeft) {
      path.lineTo(w * 0.35, bottom);
      path.lineTo(w * 0.20, h);
      path.lineTo(w * 0.25, bottom);
    } else if (tailPosition == TailPosition.bottomCenter) {
      path.lineTo(w * 0.55, bottom);
      path.lineTo(w * 0.50, h);
      path.lineTo(w * 0.45, bottom);
    } else if (tailPosition == TailPosition.bottomRight) {
      path.lineTo(w * 0.75, bottom);
      path.lineTo(w * 0.85, h);
      path.lineTo(w * 0.65, bottom);
    }

    // Bottom-left curve
    path.quadraticBezierTo(0, bottom, 0, (top + bottom) / 2);

    // ➤ Top tail insertions
    if (tailPosition == TailPosition.topLeft) {
      path.quadraticBezierTo(0, top, w * 0.25, top);
      path.lineTo(w * 0.20, 0);
      path.lineTo(w * 0.35, top);
    } else if (tailPosition == TailPosition.topRight) {
      path.quadraticBezierTo(0, top, w * 0.65, top);
      path.lineTo(w * 0.80, 0);
      path.lineTo(w * 0.75, top);
    } else {
      // No top tail
      path.quadraticBezierTo(0, top, w / 2, top);
    }

    path.close();
  }


// tail position= bottom left, right, center, top -> right, left
  // working code
  void _drawRectangleBubble(Path path, Size size) {
    const double borderRadius = 16.0;
    const double tailWidth = 22.0;
    const double tailHeight = 28.0;

    final double w = size.width;
    final double h = size.height;

    final bool hasTopTail =
        tailPosition == TailPosition.topLeft || tailPosition == TailPosition.topRight;
    final bool hasBottomTail =
        tailPosition == TailPosition.bottomLeft ||
            tailPosition == TailPosition.bottomCenter ||
            tailPosition == TailPosition.bottomRight;

    final double bodyTop = hasTopTail ? tailHeight : 0;
    final double bodyBottom = hasBottomTail ? h - tailHeight : h;

    double tailInset = 28.0;

    // Calculate tail inset
    switch (tailPosition) {
      case TailPosition.bottomCenter:
        tailInset = (w - tailWidth) / 2;
        break;
      case TailPosition.bottomRight:
      case TailPosition.topRight:
        tailInset = w - tailWidth - 28.0;
        break;
      default:
        tailInset = 28.0; // for bottomLeft, topLeft
    }

    // 🟢 Start at top-left (with offset if top tail exists)
    path.moveTo(borderRadius, bodyTop);

    // 🔵 Top edge
    if (tailPosition == TailPosition.topLeft || tailPosition == TailPosition.topRight) {
      if (tailPosition == TailPosition.topLeft) {
        path.lineTo(tailInset, bodyTop);
        path.lineTo(tailInset + tailWidth / 2, 0); // tail tip
        path.lineTo(tailInset + tailWidth, bodyTop);
      } else if (tailPosition == TailPosition.topRight) {
        path.lineTo(tailInset, bodyTop);
        path.lineTo(tailInset + tailWidth / 2, 0); // tail tip
        path.lineTo(tailInset + tailWidth, bodyTop);
      }
    }

    // Continue top edge to top-right
    path.lineTo(w - borderRadius, bodyTop);
    path.quadraticBezierTo(w, bodyTop, w, bodyTop + borderRadius);

    // 🔵 Right side
    path.lineTo(w, bodyBottom - borderRadius);
    path.quadraticBezierTo(w, bodyBottom, w - borderRadius, bodyBottom);

    // 🔵 Bottom edge
    if (tailPosition == TailPosition.bottomLeft ||
        tailPosition == TailPosition.bottomCenter ||
        tailPosition == TailPosition.bottomRight) {
      path.lineTo(tailInset + tailWidth, bodyBottom);
      path.lineTo(tailInset + tailWidth / 2, h); // tail tip
      path.lineTo(tailInset, bodyBottom);
    }

    path.lineTo(borderRadius, bodyBottom);
    path.quadraticBezierTo(0, bodyBottom, 0, bodyBottom - borderRadius);

    // 🔵 Left side
    path.lineTo(0, bodyTop + borderRadius);
    path.quadraticBezierTo(0, bodyTop, borderRadius, bodyTop);

    path.close();
  }




/*
// tail position = bottom left, right
  void _drawRectangleBubble(Path path, Size size) {
    const double borderRadius = 16.0;
    const double tailWidth = 22.0;
    const double tailHeight = 28.0;

    final double w = size.width;
    final double h = size.height;
    final double bodyHeight = h - tailHeight;

    double tailInset;

    switch (tailPosition) {
      case TailPosition.bottomLeft:
        tailInset = 28.0;
        break;
      case TailPosition.bottomCenter:
        tailInset = (w - tailWidth) / 2;
        break;
      case TailPosition.bottomRight:
        tailInset = w - tailWidth - 28.0;
        break;
      case TailPosition.none:
        tailInset = -1; // No tail
        break;
    }

    // Start at top-left
    path.moveTo(borderRadius, 0);
    path.lineTo(w - borderRadius, 0);
    path.quadraticBezierTo(w, 0, w, borderRadius);

    // Right side
    path.lineTo(w, bodyHeight - borderRadius);
    path.quadraticBezierTo(w, bodyHeight, w - borderRadius, bodyHeight);

    // Bottom edge before tail
    if (tailPosition != TailPosition.none) {
      path.lineTo(tailInset + tailWidth, bodyHeight);
      path.lineTo(tailInset + tailWidth / 2, h);       // Tail tip
      path.lineTo(tailInset, bodyHeight);
    }

    // Continue bottom line (if tail exists, continue from after tail; else full line)
    path.lineTo(borderRadius, bodyHeight);
    path.quadraticBezierTo(0, bodyHeight, 0, bodyHeight - borderRadius);

    // Left side
    path.lineTo(0, borderRadius);
    path.quadraticBezierTo(0, 0, borderRadius, 0);

    path.close();
  }*/



/*

    for original bottom left tail

  void _drawRectangleBubble(Path path, Size size) {
    const double borderRadius = 16.0;
    const double tailWidth = 22.0;
    const double tailHeight = 28.0;
    const double tailInset = 28.0; // distance from left

    final double bodyHeight = size.height - tailHeight;

    // Start at top-left
    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, borderRadius);

    // Right side
    path.lineTo(size.width, bodyHeight - borderRadius);
    path.quadraticBezierTo(size.width, bodyHeight, size.width - borderRadius, bodyHeight);

    // Bottom line (from right to just before tail)
    path.lineTo(tailInset + tailWidth, bodyHeight);

    // Tail: skip the top side of the triangle (so it appears open at the top)
    path.lineTo(tailInset + tailWidth / 2, size.height);
    path.lineTo(tailInset, bodyHeight);

    // Continue bottom line to bottom-left
    path.lineTo(borderRadius, bodyHeight);
    path.quadraticBezierTo(0, bodyHeight, 0, bodyHeight - borderRadius);

    // Left side
    path.lineTo(0, borderRadius);
    path.quadraticBezierTo(0, 0, borderRadius, 0);

    path.close();
  }
*/
  void _drawShoutBubble(Path path, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Approximate outer polygon points
    final points = <Offset>[
      Offset(w * 0.10, h * 0.30),
      Offset(w * 0.15, h * 0.10),
      Offset(w * 0.25, h * 0.28),
      Offset(w * 0.35, h * 0.08),
      Offset(w * 0.42, h * 0.25),
      Offset(w * 0.52, h * 0.05),
      Offset(w * 0.60, h * 0.22),
      Offset(w * 0.70, h * 0.02),
      Offset(w * 0.75, h * 0.20),
      Offset(w * 0.88, h * 0.05),
      Offset(w * 0.90, h * 0.25),
      Offset(w * 0.98, h * 0.18),
      Offset(w * 0.95, h * 0.38),
      Offset(w,      h * 0.45),
      Offset(w * 0.90, h * 0.52),
      Offset(w * 0.95, h * 0.60),
      Offset(w * 0.85, h * 0.65),
      Offset(w * 0.98, h * 0.75),
      Offset(w * 0.80, h * 0.78),
      Offset(w * 0.90, h * 0.90),
      Offset(w * 0.75, h * 0.88),
      Offset(w * 0.78, h),
      Offset(w * 0.65, h * 0.90),
      Offset(w * 0.60, h * 0.98),
      Offset(w * 0.52, h * 0.85),
      Offset(w * 0.45, h),
      Offset(w * 0.40, h * 0.83),
      Offset(w * 0.30, h * 0.95),
      Offset(w * 0.32, h * 0.75),
      Offset(w * 0.25, h * 0.88),
      Offset(w * 0.20, h * 0.75),
      Offset(w * 0.12, h * 0.90),
      Offset(w * 0.15, h * 0.70),
      Offset(w * 0.05, h * 0.72),
      Offset(w * 0.08, h * 0.60),
      Offset(0,      h * 0.50),
      Offset(w * 0.10, h * 0.45),
      Offset(0,      h * 0.38),
      Offset(w * 0.08, h * 0.32),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.close();
  }


/*
  void _drawRectangleBubble(Path path, Size size) {
    const double borderRadius = 16.0;
    const double tailWidth = 20.0;
    const double tailHeight = 20.0;
    const double tailInset = 20.0;

    final double bodyHeight = size.height - tailHeight;

    // Start at top-left corner
    path.moveTo(borderRadius, 0);

    // Top line
    path.lineTo(size.width - borderRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, borderRadius);

    // Right side
    path.lineTo(size.width, bodyHeight - borderRadius);
    path.quadraticBezierTo(size.width, bodyHeight, size.width - borderRadius, bodyHeight);

    // Bottom side to tail (right to left)
    path.lineTo(tailInset + tailWidth, bodyHeight);

    // Tail
    path.lineTo(tailInset + tailWidth / 2, size.height);
    path.lineTo(tailInset, bodyHeight);

    // Continue bottom line
    path.lineTo(borderRadius, bodyHeight);
    path.quadraticBezierTo(0, bodyHeight, 0, bodyHeight - borderRadius);

    // Left side
    path.lineTo(0, borderRadius);
    path.quadraticBezierTo(0, 0, borderRadius, 0);

    path.close();
  }
*/



  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
