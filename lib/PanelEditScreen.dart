import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'CharacterClipartPicker.dart';
import 'GridPainter.dart';
import 'PanelElementModel.dart';
import 'Resizeable/ResizableDraggable.dart';
import 'package:flutter/services.dart';

class PanelEditScreen extends StatefulWidget {
  final ComicPanel panel;
  final Offset panelOffset;

  const PanelEditScreen({
    super.key,
    required this.panel,
    required this.panelOffset,
  });

  @override
  _PanelEditScreenState createState() => _PanelEditScreenState();
}

class _PanelEditScreenState extends State<PanelEditScreen> {
  late ComicPanel panel;
  List<GlobalKey<ResizableDraggableState>> elementKeys = [];
  List<PanelElementModel> currentElements = [];
  bool isDrawing = false;
  Color selectedColor = Colors.black;
  Color _selectedBackgroundColor = Colors.white;
  bool _isSaving = false;
  bool _isEditing = true;

  final GlobalKey _panelContentKey = GlobalKey();
  int? selectedElementIndex;

  late final double _screenWidth;
  late final double _screenHeight;

  List<IconData> clipArtIcons = [
    Icons.star,
    Icons.favorite,
    Icons.face,
    Icons.emoji_emotions,
    Icons.emoji_nature,
    Icons.emoji_people,
    Icons.emoji_objects,
    Icons.emoji_symbols,
    Icons.pets,
    Icons.music_note,
    Icons.cake,
    Icons.wb_sunny,
    Icons.nightlight_round,
    Icons.local_florist,
    Icons.flight,
    Icons.beach_access,
    Icons.sports_esports,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenWidth = MediaQuery.of(context).size.width;
      _screenHeight = MediaQuery.of(context).size.height;
    });

    panel = widget.panel;
    currentElements = List.from(panel.elements);
    _selectedBackgroundColor = panel.backgroundColor;

    print('Panel elements count: ${currentElements.length}'); // Debug print
    for (int i = 0; i < currentElements.length; i++) {
      print(
          'Element $i: ${currentElements[i].type} - ${currentElements[i].value}'); // Debug print
    }

    _initializeElements();
  }

  void _initializeElements() {
    elementKeys.clear();
    for (int i = 0; i < currentElements.length; i++) {
      elementKeys.add(GlobalKey<ResizableDraggableState>());
    }
  }

  Widget _buildElementWidget(PanelElementModel element, int index) {
    Widget child;

    print(
        'Building element: ${element.type} with value: ${element.value}'); // Debug print

    switch (element.type) {
      case 'clipart':
        try {
          child = SizedBox(
            width: element.width,
            height: element.height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(
                IconData(
                  int.parse(element.value),
                  fontFamily: element.fontFamily ?? 'MaterialIcons',
                ),
                color: element.color ?? Colors.deepPurple,
              ),
            ),
          );
        } catch (e) {
          print('Error parsing clipart icon: $e');
          // Fallback to a default icon
          child = SizedBox(
            width: element.width,
            height: element.height,
            child: Icon(
              Icons.star,
              size: element.height * 0.8,
              color: element.color ?? Colors.deepPurple,
            ),
          );
        }
        break;

      case 'character':
        child = SizedBox(
          width: element.width,
          height: element.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              element.value,
              style: TextStyle(
                fontSize: element.height * 0.8,
                color: element.color ?? Colors.black,
              ),
            ),
          ),
        );
        break;

      case 'text':
        child = SizedBox(
          width: element.width,
          height: element.height,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            child: Text(
              element.value,
              style: TextStyle(
                fontSize: element.fontSize ?? 20,
                color: element.color ?? Colors.black,
                fontFamily: element.fontFamily,
              ),
            ),
          ),
        );
        break;

      case 'bubble':
        child = Container(
          width: element.width,
          height: element.height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (element.color ?? Colors.blue).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: element.color ?? Colors.blue, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              element.value,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        break;

      case 'image':
        child = Container(
          width: element.width,
          height: element.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(element.value),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
        );
        break;

      default:
        child = Container(
          width: element.width,
          height: element.height,
          color: Colors.red.withOpacity(0.3),
          child: Center(
            child: Text(
              'Unknown: ${element.type}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
    }

    // Ensure element has valid size
    final elementSize = Size(
      element.width > 0 ? element.width : 50,
      element.height > 0 ? element.height : 50,
    );

    if (_isEditing) {
      return ResizableDraggable(
        key: elementKeys[index],
        size: elementSize,
        initialTop: element.offset.dy,
        initialLeft: element.offset.dx,
        onPositionChanged: (position, size) {
          if (mounted) {
            setState(() {
              currentElements[index] = currentElements[index].copyWith(
                offset: position,
                size: size,
                width: size.width,
                height: size.height,
              );
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedElementIndex == index
                  ? Colors.blue
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      );
    } else {
      return Positioned(
        top: element.offset.dy,
        left: element.offset.dx,
        child: SizedBox(
          width: element.width,
          height: element.height,
          child: child,
        ),
      );
    }
  }

  void _addNewElement(PanelElementModel element) {
    setState(() {
      currentElements.add(element);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
    });
  }

  Future<Uint8List?> _capturePanelAsImage() async {
    try {
      RenderRepaintBoundary boundary = _panelContentKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing panel image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Panel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _isSaving
                ? null
                : () {
                    if (currentElements.isNotEmpty) {
                      setState(() {
                        currentElements.removeLast();
                        elementKeys.removeLast();
                      });
                    }
                  },
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _savePanel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save Panel'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Debug info
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(
              'Elements: ${currentElements.length} | Editing: $_isEditing',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _panelContentKey,
              child: Container(
                color: _selectedBackgroundColor,
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    // Show a grid for reference
                    if (_isEditing)
                      CustomPaint(
                        size: Size.infinite,
                        painter: GridPainter(),
                      ),
                    // Elements
                    for (int i = 0; i < currentElements.length; i++)
                      _buildElementWidget(currentElements[i], i),
                    // Show message if no elements
                    if (currentElements.isEmpty)
                      const Center(
                        child: Text(
                          'No elements added yet.\nUse the tools below to add content.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _buildToolOptions(),
        ],
      ),
    );
  }

  Widget _buildToolOptions() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolButton(
                Icons.format_color_fill, 'Background', _pickBackgroundColor),
            _toolButton(Icons.image, 'Upload Image', _uploadImage),
            _toolButton(Icons.insert_emoticon, 'Clip-art', () async {
              final result = await showCharacterAndClipartPicker(context);
              if (result != null) {
                if (result['type'] == 'clipart') {
                  _addClipArt(IconData(result['value'],
                      fontFamily: result['fontFamily']));
                } else if (result['type'] == 'character') {
                  _addCharacterEmoji(result['value']);
                }
              }
            }),
            _toolButton(Icons.bubble_chart, 'Bubble', _addBubble),
            _toolButton(Icons.text_fields, 'Text', _addTextBox),
            _toolButton(Icons.draw, 'Draw', _toggleDrawing),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon),
            onPressed: _isSaving ? null : onTap,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _isSaving ? Colors.grey : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    if (selectedElementIndex == null) return SizedBox.shrink();
    final element = currentElements[selectedElementIndex!];
    final key = elementKeys[selectedElementIndex!];
    final state = key.currentState;
    if (state == null) return SizedBox.shrink();

    final Offset toolbarPosition =
        state.position.translate(state.size.width + 10, -40);

    return Positioned(
      top: toolbarPosition.dy.clamp(0.0, _screenHeight - 50),
      left: toolbarPosition.dx.clamp(0.0, _screenWidth - 250),
      child: Row(
        children: [
          IconButton(
            icon: Icon(element.locked ? Icons.lock : Icons.lock_open),
            onPressed: () {
              setState(() {
                currentElements[selectedElementIndex!] =
                    element.copyWith(locked: !element.locked);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editText(selectedElementIndex!),
          ),
          IconButton(
            icon: const Icon(Icons.font_download),
            onPressed: () => _changeFont(selectedElementIndex!),
          ),
          IconButton(
            icon: const Icon(Icons.format_color_fill),
            onPressed: () => _changeColor(selectedElementIndex!),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                currentElements.removeAt(selectedElementIndex!);
                elementKeys.removeAt(selectedElementIndex!);
                selectedElementIndex = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _editText(int index) {
    final controller =
        TextEditingController(text: currentElements[index].value);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                currentElements[index] =
                    currentElements[index].copyWith(value: controller.text);
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeFont(int index) async {
    // Reuse part of your existing _addTextBox font size & fontFamily dialog
  }

  void _changeColor(int index) async {
    final current = currentElements[index];
    Color? picked = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: current.color ?? Colors.black,
            onColorChanged: (c) => Navigator.pop(context, c),
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        currentElements[index] = current.copyWith(color: picked);
      });
    }
  }

  void _pickBackgroundColor() async {
    Color tempColor = _selectedBackgroundColor;
    Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick Background Color"),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: tempColor,
            onColorChanged: (color) {
              tempColor = color;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(tempColor),
            child: const Text("Select"),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedBackgroundColor = picked;
      });
    }
  }

  void _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final newElement = PanelElementModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'image',
        value: pickedFile.path,
        offset: const Offset(50, 50),
        width: 100,
        height: 100,
        size: const Size(100, 100),
        color: Colors.orangeAccent,
      );
      _addNewElement(newElement);
    }
  }

  void _addCharacterEmoji(String emoji) {
    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'character',
      value: emoji,
      offset: const Offset(50, 50),
      width: 60,
      height: 60,
      size: const Size(60, 60),
    );
    _addNewElement(newElement);
  }

  void _addClipArt(IconData selectedIcon) {
    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'clipart',
      value: selectedIcon.codePoint.toString(),
      fontFamily: selectedIcon.fontFamily,
      offset: const Offset(50, 50),
      width: 50,
      height: 50,
      size: const Size(50, 50),
      color: Colors.deepPurple,
    );
    _addNewElement(newElement);
  }

  void _addBubble() {
    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'bubble',
      value: 'Bubble',
      offset: const Offset(50, 50),
      width: 80,
      height: 40,
      size: const Size(80, 40),
      color: Colors.blue,
    );
    _addNewElement(newElement);
  }

  void _addTextBox() async {
    final textController = TextEditingController();
    double fontSize = 20;
    Color selectedColor = Colors.black;
    String fontFamily = 'Roboto';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Text'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: 'Text'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Font Size: "),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 10,
                        max: 60,
                        divisions: 10,
                        label: fontSize.round().toString(),
                        onChanged: (value) => setState(() => fontSize = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Font Color: "),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        Color? picked = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Pick a Color'),
                            content: SingleChildScrollView(
                              child: BlockPicker(
                                pickerColor: selectedColor,
                                onColorChanged: (color) =>
                                    Navigator.pop(context, color),
                              ),
                            ),
                          ),
                        );
                        if (picked != null) {
                          setState(() => selectedColor = picked);
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          border: Border.all(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop({
                    'text': textController.text.trim(),
                    'fontSize': fontSize,
                    'color': selectedColor,
                    'fontFamily': fontFamily,
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final newElement = PanelElementModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'text',
        value: result['text'],
        offset: const Offset(50, 50),
        width: 100,
        height: 30,
        size: const Size(100, 30),
        fontSize: result['fontSize'],
        color: result['color'],
        fontFamily: result['fontFamily'],
      );
      _addNewElement(newElement);
    }
  }

  void _toggleDrawing() {
    setState(() => isDrawing = !isDrawing);
    if (isDrawing) _showDrawingTools();
  }

  void _showDrawingTools() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Drawing Tools'),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Clear drawing logic here
                  },
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pickDrawingColor,
                  child: const Text('Color'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickDrawingColor() async {
    Color? picked = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick Drawing Color"),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: selectedColor,
            onColorChanged: (color) => Navigator.of(context).pop(color),
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        selectedColor = picked;
      });
    }
  }

  void _savePanel() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _isEditing = false;
    });

    try {
      final updatedElements = <PanelElementModel>[];
      for (int i = 0; i < currentElements.length; i++) {
        final key = elementKeys[i];
        final state = key.currentState;
        if (state != null) {
          final updatedElement = currentElements[i].copyWith(
            offset: state.position,
            size: state.size,
            width: state.size.width,
            height: state.size.height,
            fontFamily: currentElements[i].fontFamily,
          );
          updatedElements.add(updatedElement);
        } else {
          updatedElements.add(currentElements[i]);
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        _isEditing = true;
      });

      final capturedImage = await _capturePanelAsImage();

      final updatedPanel = panel.copyWith(
        elements: updatedElements,
        backgroundColor: _selectedBackgroundColor,
        previewImage: capturedImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panel saved successfully!'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, updatedPanel);
      }
    } catch (e) {
      print('Error saving panel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving panel. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> showCharacterAndClipartPicker(
      BuildContext context) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return CharacterClipartPickerDialog();
      },
    );
  }
}

/*
  void _showColorPicker(BuildContext context) {
    Color pickerColor = selectedColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a Background Color'),
          content: BlockPicker(
            pickerColor: pickerColor,
            onColorChanged: (Color color) {
              pickerColor = color;
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Select'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  selectedColor = pickerColor;
                  // Update the panel background color here
                });
              },
            ),
          ],
        );
      },
    );
  }
*/
