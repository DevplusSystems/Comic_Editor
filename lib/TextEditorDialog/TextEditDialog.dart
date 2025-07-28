import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class TextEditDialog extends StatefulWidget {
  final String initialText;
  final double initialFontSize;
  final Color initialColor;
  final String initialFontFamily;
  final FontWeight initialFontWeight;
  final FontStyle initialFontStyle;

  const TextEditDialog({
    super.key,
    required this.initialText,
    required this.initialFontSize,
    required this.initialColor,
    required this.initialFontFamily,
    required this.initialFontWeight,
    required this.initialFontStyle,
  });

  @override
  _TextEditDialogState createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  late TextEditingController _textController;
  late double _fontSize;
  late Color _textColor;
  late String _fontFamily;
  late FontWeight _fontWeight;
  late FontStyle _fontStyle;

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
    _textController = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialFontSize;
    _textColor = widget.initialColor;
    _fontFamily = widget.initialFontFamily;
    _fontWeight = widget.initialFontWeight;
    _fontStyle = widget.initialFontStyle;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Text'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _textController.text.isEmpty ? 'Preview' : _textController.text,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: _textColor,
                  fontFamily: _fontFamily,
                  fontWeight: _fontWeight,
                  fontStyle: _fontStyle,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Text input
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Text',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => setState(() {}),
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
                    max: 72,
                    divisions: 64,
                    label: _fontSize.round().toString(),
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ),
                Text(_fontSize.round().toString()),
              ],
            ),

            const SizedBox(height: 16),

            // Color picker
            Row(
              children: [
                const Text('Text Color: '),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    Color? picked = await showDialog<Color>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Pick Text Color'),
                        content: SingleChildScrollView(
                          child: BlockPicker(
                            pickerColor: _textColor,
                            onColorChanged: (color) => Navigator.pop(context, color),
                          ),
                        ),
                      ),
                    );
                    if (picked != null) {
                      setState(() => _textColor = picked);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _textColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
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

            // Font Weight and Style
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FontWeight>(
                    value: _fontWeight,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
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
                      labelText: 'Style',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'text': _textController.text.trim(),
                'fontSize': _fontSize,
                'color': _textColor,
                'fontFamily': _fontFamily,
                'fontWeight': _fontWeight,
                'fontStyle': _fontStyle,
              });
            }
          },
          child: const Text('Apply'),
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