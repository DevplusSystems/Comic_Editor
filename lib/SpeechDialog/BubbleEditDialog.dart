import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class BubbleEditDialog extends StatefulWidget {
  final String initialText;
  final Color initialColor;

  const BubbleEditDialog({
    super.key,
    required this.initialText,
    required this.initialColor,
  });

  @override
  _BubbleEditDialogState createState() => _BubbleEditDialogState();
}

class _BubbleEditDialogState extends State<BubbleEditDialog> {
  late TextEditingController _textController;
  late Color _bubbleColor;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _bubbleColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Bubble'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Bubble Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Bubble Color: '),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  Color? picked = await showDialog<Color>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick Bubble Color'),
                      content: SingleChildScrollView(
                        child: MaterialPicker(
                          pickerColor: _bubbleColor,
                          onColorChanged: (color) => Navigator.pop(context, color),
                        ),
                      ),
                    ),
                  );
                  if (picked != null) {
                    setState(() => _bubbleColor = picked);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _bubbleColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              'color': _bubbleColor,
            });
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