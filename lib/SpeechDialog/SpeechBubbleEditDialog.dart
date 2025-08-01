import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'SpeechBubbleComponents.dart';

class SpeechBubbleEditDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const SpeechBubbleEditDialog({
    super.key,
    required this.initialData,
  });

  @override
  _SpeechBubbleEditDialogState createState() => _SpeechBubbleEditDialogState();
}

class _SpeechBubbleEditDialogState extends State<SpeechBubbleEditDialog> {
  late TextEditingController _textController;
  late Color _bubbleColor;
  late Color _borderColor;
  late Color _textColor;
  late double _fontSize;
  late double _borderWidth;
  late BubbleShape _bubbleShape;
  late String _fontFamily;
  late FontWeight _fontWeight;
  late FontStyle _fontStyle;
  late double _padding;

  final List<String> _fontFamilies = [
    'Roboto',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Comic Sans MS',
    'Impact',
    'Verdana',
  ];

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
              // Preview - FIXED to update in real-time
              Container(
                height: 150,
                width: 200,
                margin: const EdgeInsets.only(bottom: 16),
                child: CustomPaint(
                  size: const Size(200, 120),
                  painter: SpeechBubblePainter(
                    bubbleColor: _bubbleColor,
                    borderColor: _borderColor,
                    borderWidth: _borderWidth,
                    bubbleShape: _bubbleShape,

                  ),
                  child: Container(
                    padding: EdgeInsets.all(_padding),
                    child: Center(
                      child: Text(
                        _textController.text.isEmpty ? 'Preview' : _textController.text,
                        style: TextStyle(
                          fontSize: _fontSize * 0.8, // Scale for preview
                          color: _textColor,
                          fontFamily: _fontFamily,
                          fontWeight: _fontWeight,
                          fontStyle: _fontStyle,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
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
              DropdownButtonFormField<BubbleShape>(
                value: _bubbleShape,
                decoration: const InputDecoration(
                  labelText: 'Bubble Shape',
                  border: OutlineInputBorder(),
                ),
                items: BubbleShape.values.map((shape) {
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
                      onChanged: (value) => setState(() => _borderWidth = value),
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
                        DropdownMenuItem(value: FontWeight.normal, child: Text('Normal')),
                        DropdownMenuItem(value: FontWeight.bold, child: Text('Bold')),
                        DropdownMenuItem(value: FontWeight.w300, child: Text('Light')),
                        DropdownMenuItem(value: FontWeight.w600, child: Text('Semi-Bold')),
                      ],
                      onChanged: (value) => setState(() => _fontWeight = value!),
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
                        DropdownMenuItem(value: FontStyle.normal, child: Text('Normal')),
                        DropdownMenuItem(value: FontStyle.italic, child: Text('Italic')),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'text': _textController.text,
              'bubbleColor': _bubbleColor,
              'borderColor': _borderColor,
              'textColor': _textColor,
              'fontSize': _fontSize,
              'borderWidth': _borderWidth,
              'bubbleShape': _bubbleShape,
              'fontFamily': _fontFamily,
              'fontWeight': _fontWeight,
              'fontStyle': _fontStyle,
              'padding': _padding,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color currentColor, Function(Color) onColorChanged) {
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

  String _getBubbleShapeName(BubbleShape shape) {
    switch (shape) {
      case BubbleShape.oval:
        return 'Oval';
      case BubbleShape.rectangle:
        return 'Rectangle';
      case BubbleShape.shout:
        return 'shout';
    }
  }


  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
