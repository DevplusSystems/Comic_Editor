import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';



// Define your DrawingTool enum
enum DrawingTool { pen }

class DrawingToolsPanel extends StatefulWidget {
  final DrawingTool currentTool;
  final Color currentColor;
  final double currentBrushSize;

  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onBrushSizeChanged;
  final VoidCallback onUndo;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const DrawingToolsPanel({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.currentBrushSize,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onBrushSizeChanged,
    required this.onUndo,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  State<DrawingToolsPanel> createState() => _DrawingToolsPanelState();
}

class _DrawingToolsPanelState extends State<DrawingToolsPanel> {
  final List<Color> quickColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.grey,
  ];

  late DrawingTool _localTool;
  late Color _localColor;
  late double _localBrushSize;

  @override
  void initState() {
    super.initState();
    _localTool = widget.currentTool;
    _localColor = widget.currentColor;
    _localBrushSize = widget.currentBrushSize;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        minHeight: 300,
      ),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Drawing Tools',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Tools:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DrawingTool.values.map((tool) {
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getToolIcon(tool), size: 16),
                      const SizedBox(width: 4),
                      Text(_getToolName(tool)),
                    ],
                  ),
                  selected: _localTool == tool,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _localTool = tool);
                      widget.onToolChanged(tool);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Brush Size:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _localBrushSize,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: _localBrushSize.round().toString(),
                    onChanged: (value) {
                      setState(() => _localBrushSize = value);
                      widget.onBrushSizeChanged(value);
                    },
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: _localBrushSize,
                      height: _localBrushSize,
                      decoration: BoxDecoration(
                        color: _localColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Colors:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...quickColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _localColor = color);
                      widget.onColorChanged(color);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: _localColor == color ? Colors.blue : Colors.grey,
                          width: _localColor == color ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
                      ),
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.palette, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onUndo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onClearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getToolIcon(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
        return Icons.edit;
    /*  case DrawingTool.highlighter:
        return Icons.highlight;
      case DrawingTool.eraser:
        return Icons.cleaning_services;
      case DrawingTool.line:
        return Icons.horizontal_rule;
      case DrawingTool.rectangle:
        return Icons.crop_square;
      case DrawingTool.circle:
        return Icons.circle_outlined;
      case DrawingTool.arrow:
        return Icons.arrow_forward;*/
    }
  }

  String _getToolName(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
        return 'Pen';
      /*case DrawingTool.highlighter:
        return 'Highlighter';
      case DrawingTool.eraser:
        return 'Eraser';
      case DrawingTool.line:
        return 'Line';
      case DrawingTool.rectangle:
        return 'Rectangle';
      case DrawingTool.circle:
        return 'Circle';
      case DrawingTool.arrow:
        return 'Arrow';*/
    }
  }

  void _showColorPicker() async {
    Color tempColor = _localColor;

    Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _localColor,
            onColorChanged: (color) {
              tempColor = color;
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, tempColor),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() => _localColor = picked);
      widget.onColorChanged(picked);
    }
  }
}

