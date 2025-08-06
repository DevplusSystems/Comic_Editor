import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'DragSpeechBubbleComponents.dart';

class DragSpeechBubbleEditDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const DragSpeechBubbleEditDialog({
    super.key,
    required this.initialData,
  });

  @override
  State<DragSpeechBubbleEditDialog> createState() =>
      _DragSpeechBubbleEditDialogState();
}

class _DragSpeechBubbleEditDialogState
    extends State<DragSpeechBubbleEditDialog> {
  final GlobalKey _bubbleKey = GlobalKey();

  String text = "Hello!";
  Offset _tailOffset = const Offset(150, 180);
  Color bubbleColor = Colors.white;
  Color borderColor = Colors.black;
  Color textColor = Colors.black;
  double fontSize = 16;
  double borderWidth = 2.0;
  DragBubbleShape shape = DragBubbleShape.rectangle;
  late TextEditingController _textController;
  late Color _bubbleColor;
  late Color _borderColor;
  late Color _textColor;
  late double _fontSize;
  late double _borderWidth;
  late String _fontFamily;
  late FontStyle _fontStyle;
  late double _padding;
  late FontWeight _fontWeight;
  late DragBubbleShape _bubbleShape;

  final List<String> _fontFamilies = [
    'Roboto',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Comic Sans MS',
    'Impact',
    'Verdana',
  ];
  String _getBubbleShapeName(DragBubbleShape shape) {
    switch (shape) {
      case DragBubbleShape.rectangle:
        return 'Rectangle';
      default:
        return 'Unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialData['text']);
    _bubbleColor = widget.initialData['bubbleColor'];
    _borderColor = widget.initialData['borderColor'];
    _textColor = widget.initialData['textColor'];
    _fontSize = widget.initialData['fontSize'];
    _borderWidth = widget.initialData['borderWidth'];
    _bubbleShape = widget.initialData['bubbleShape'];
    _tailOffset = widget.initialData['_tailOffset'] ?? const Offset(150, 180);
    _fontFamily = widget.initialData['fontFamily'];
    _fontWeight = widget.initialData['fontWeight'];
    _fontStyle = widget.initialData['fontStyle'];
    _padding = widget.initialData['padding'] ?? 12.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Speech Bubble'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              SizedBox(
                width: 500,
                height: 220, // Full height including tail space
                child: Stack(
                  children: [
                  /*  CustomPaint(
                      size: const Size(300, 240), // Taller canvas
                      painter: DragSpeechBubblePainter(
                        bubbleColor: _bubbleColor,
                        borderColor: _borderColor,
                        borderWidth: _borderWidth,
                        bubbleShape: _bubbleShape,
                        tailOffset: _tailOffset,
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: fontSize, color: textColor),
                        ),
                      ),
                    ),*/

                    Container(
                      key: _bubbleKey,
                      child: CustomPaint(
                        size: const Size(300, 240),
                        painter: DragSpeechBubblePainter(
                          bubbleColor: _bubbleColor,          // ✅ use updated values
                          borderColor: _borderColor,
                          borderWidth: _borderWidth,
                          bubbleShape: _bubbleShape,
                          tailOffset: _tailOffset,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.all(_padding),
                          child: Text(
                            _textController.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _fontSize,
                              color: _textColor,
                              fontFamily: _fontFamily,
                              fontWeight: _fontWeight,
                              fontStyle: _fontStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _tailOffset.dx - 10,
                      top: _tailOffset.dy - 10,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _tailOffset += details.delta;
                            _tailOffset = Offset(
                              _tailOffset.dx.clamp(0, 320),
                              _tailOffset.dy.clamp(0, 200),
                            );
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Text input
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Speech Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Bubble Shape - FIXED
              DropdownButtonFormField<DragBubbleShape>(
                value: _bubbleShape,
                decoration: const InputDecoration(
                  labelText: 'Bubble Shape',
                  border: OutlineInputBorder(),
                ),
                items: DragBubbleShape.values.map((shape) {
                  return DropdownMenuItem(
                    value: shape,
                    child: Text(_getBubbleShapeName(shape)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _bubbleShape = value!),
              ),

              const SizedBox(height: 16),

              // Colors
              Row(
                children: [
                  Expanded(
                    child: _buildColorPicker(
                      'Bubble Color',
                      _bubbleColor,
                      (color) => setState(() => _bubbleColor = color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildColorPicker(
                      'Border Color',
                      _borderColor,
                      (color) => setState(() => _borderColor = color),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildColorPicker(
                'Text Color',
                _textColor,
                (color) => setState(() => _textColor = color),
              ),

              const SizedBox(height: 16),

              // Font Size
              Row(
                children: [
                  const Text('Font Size: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 8,
                      max: 32,
                      divisions: 24,
                      label: _fontSize.round().toString(),
                      onChanged: (value) => setState(() => _fontSize = value),
                    ),
                  ),
                  Text(_fontSize.round().toString()),
                ],
              ),

              // Border Width
              Row(
                children: [
                  const Text('Border Width: '),
                  Expanded(
                    child: Slider(
                      value: _borderWidth,
                      min: 0,
                      max: 8,
                      divisions: 16,
                      label: _borderWidth.toStringAsFixed(1),
                      onChanged: (value) =>
                          setState(() => _borderWidth = value),
                    ),
                  ),
                  Text(_borderWidth.toStringAsFixed(1)),
                ],
              ),

              // Padding
              Row(
                children: [
                  const Text('Padding: '),
                  Expanded(
                    child: Slider(
                      value: _padding,
                      min: 4,
                      max: 24,
                      divisions: 20,
                      label: _padding.round().toString(),
                      onChanged: (value) => setState(() => _padding = value),
                    ),
                  ),
                  Text(_padding.round().toString()),
                ],
              ),

              const SizedBox(height: 16),

              // Font Family
              DropdownButtonFormField<String>(
                value: _fontFamily,
                decoration: const InputDecoration(
                  labelText: 'Font Family',
                  border: OutlineInputBorder(),
                ),
                items: _fontFamilies.map((font) {
                  return DropdownMenuItem(
                    value: font,
                    child: Text(font, style: TextStyle(fontFamily: font)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _fontFamily = value!),
              ),

              const SizedBox(height: 16),

              // Font Style Options
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FontWeight>(
                      value: _fontWeight,
                      decoration: const InputDecoration(
                        labelText: 'Font Weight',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: FontWeight.normal, child: Text('Normal')),
                        DropdownMenuItem(
                            value: FontWeight.bold, child: Text('Bold')),
                        DropdownMenuItem(
                            value: FontWeight.w300, child: Text('Light')),
                        DropdownMenuItem(
                            value: FontWeight.w600, child: Text('Semi-Bold')),
                      ],
                      onChanged: (value) =>
                          setState(() => _fontWeight = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<FontStyle>(
                      value: _fontStyle,
                      decoration: const InputDecoration(
                        labelText: 'Font Style',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: FontStyle.normal, child: Text('Normal')),
                        DropdownMenuItem(
                            value: FontStyle.italic, child: Text('Italic')),
                      ],
                      onChanged: (value) => setState(() => _fontStyle = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {

            final renderBox = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
            final actualSize = renderBox?.size ?? const Size(150, 100); // fallback

            Navigator.pop(context, {
              'text': _textController.text,
              'tailOffset': _tailOffset,
              'bubbleColor': _bubbleColor,
              'borderColor': _borderColor,
              'borderWidth': _borderWidth,
              'textColor': _textColor,
              'fontSize': _fontSize,
              'bubbleShape': _bubbleShape,
              'fontFamily': _fontFamily,
              'fontWeight': _fontWeight,
              'fontStyle': _fontStyle,
              'padding': _padding,
              'width': actualSize.width,   // 👈 include size
              'height': actualSize.height, // 👈 include size
            });
          },

          /* onPressed: () {
            Navigator.pop(context, {
              'text': text,
              'tailOffset': _tailOffset,
              'bubbleColor': bubbleColor,
              'borderColor': borderColor,
              'borderWidth': borderWidth,
              'textColor': textColor,
              'fontSize': fontSize,
              'bubbleShape': shape,
            });
          },*/

          child: const Text("Apply"),
        ),
      ],
    );
  }

  Widget _buildColorPicker(
      String label, Color currentColor, Function(Color) onColorChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            Color? picked = await showDialog<Color>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Pick $label'),
                content: SingleChildScrollView(
                  child: BlockPicker(
                    pickerColor: currentColor,
                    onColorChanged: (color) => Navigator.pop(context, color),
                  ),
                ),
              ),
            );
            if (picked != null) {
              onColorChanged(picked);
            }
          },
          child: Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: currentColor,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }


  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
