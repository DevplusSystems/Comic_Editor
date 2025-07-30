import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'DrawingToolsPanel.dart';


class DrawingCanvas extends StatefulWidget {
  final DrawingTool tool;
  final Color color;
  final double brushSize;
  final Function(List<Offset>) onDrawingComplete;

  const DrawingCanvas({
    super.key,
    required this.tool,
    required this.color,
    required this.brushSize,
    required this.onDrawingComplete,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> points = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          points.add(details.localPosition);
        });
      },
      onPanEnd: (_) {
        widget.onDrawingComplete(points);
        points.clear();
      },
      child: CustomPaint(
        painter: _DrawingPainter(
          points: points,
          color: widget.color,
          brushSize: widget.brushSize,
          tool: widget.tool,
        ),
        size: Size.infinite,
      ),
    );
  }
}
class _DrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double brushSize;
  final DrawingTool tool;

  _DrawingPainter({
    required this.points,
    required this.color,
    required this.brushSize,
    required this.tool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (tool == DrawingTool.pen)
          ? color.withOpacity(0.4)
          : color
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..style = (tool == DrawingTool.pen) ? PaintingStyle.stroke : PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

