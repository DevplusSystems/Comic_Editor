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
  final bool isSelected;

  /// NEW: parent handles removal
  final VoidCallback? onDelete;

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
    this.isSelected = false,
    this.onDelete,
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

  // === external control API ===
  void externalUpdate({Offset? position, Size? size, bool notify = false}) {
    if (!mounted) return;
    setState(() {
      if (position != null) {
        left = position.dx;
        top = position.dy;
      }
      if (size != null) {
        width = size.width.clamp(widget.minWidth, widget.maxWidth);
        height = size.height.clamp(widget.minHeight, widget.maxHeight);
      }
    });
    if (notify && widget.onPositionChanged != null) {
      widget.onPositionChanged!(this.position, this.size);
    }
  }

  void externalUpdatePosition(Offset position, {bool notify = false}) {
    externalUpdate(position: position, notify: notify);
  }

  void externalUpdateSize(Size size, {bool notify = false}) {
    externalUpdate(size: size, notify: notify);
  }
  // === END external API ===

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            left += details.delta.dx;
            top  += details.delta.dy;
          });
          widget.onPositionChanged?.call(position, size);
        },
        onPanEnd: (_) {
          widget.onPositionChanged?.call(position, size);
        },
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none, // <<< allow delete chip to sit slightly outside
            children: [
              Positioned.fill(child: widget.child),

              // === NEW: Delete button (top-right) ===
              if (widget.isSelected && widget.onDelete != null)
                Positioned(
                  // put slightly outside; set to 4,4 to keep inside
                  top: -20,
                  right: -12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onDelete,
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // resize handle (bottom-right) — only when selected
              if (widget.isSelected)
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        width  = (width  + details.delta.dx)
                            .clamp(widget.minWidth, widget.maxWidth);
                        height = (height + details.delta.dy)
                            .clamp(widget.minHeight, widget.maxHeight);
                      });
                      widget.onPositionChanged?.call(position, size);
                    },
                    onPanEnd: (_) {
                      widget.onPositionChanged?.call(position, size);
                    },
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const Icon(Icons.open_with, size: 15, color: Colors.white),
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
