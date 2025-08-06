import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ResizableDraggable extends StatefulWidget {
  final Widget child;
  final Size size;
  final double initialTop;
  final double initialLeft;
  final Function(Offset, Size)? onPositionChanged;
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final double maxHeight;

  const ResizableDraggable({
    super.key,
    required this.child,
    required this.size,
    this.initialTop = 0,
    this.initialLeft = 0,
    this.onPositionChanged,
    this.minWidth = 10.0,
    this.minHeight = 10.0,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
  });

  @override
  State<ResizableDraggable> createState() => ResizableDraggableState();
}

class ResizableDraggableState extends State<ResizableDraggable> {
  late double top;
  late double left;
  late double width;
  late double height;

  @override
  void initState() {
    super.initState();
    top = widget.initialTop;
    left = widget.initialLeft;
    width = widget.size.width;
    height = widget.size.height;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            left += details.delta.dx;
            top += details.delta.dy;
          });
        },
        onPanEnd: (details) {
          widget.onPositionChanged?.call(position, size);
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
            /*          width = (width + details.delta.dx).clamp(30.0, 400.0);
                      height = (height + details.delta.dy).clamp(30.0, 400.0);*/
                      width = (width + details.delta.dx).clamp(10.0, double.infinity);
                      height = (height + details.delta.dy).clamp(10.0, double.infinity);
                    });
                  },
                  onPanEnd: (details) {
                    widget.onPositionChanged?.call(position, size);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.open_with,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset get position => Offset(left, top);
  Size get size => Size(width, height);
}