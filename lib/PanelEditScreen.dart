import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'ClipArt/CharacterClipartPicker.dart';
import 'Draw/DrawingCanvas.dart';
import 'Draw/DrawingElementPainter.dart';
import 'Draw/DrawingPainter.dart';
import 'Draw/DrawingToolsPanel.dart';
import 'Resizeable/GridPainter.dart';
import 'PanelModel/PanelElementModel.dart';
import 'Resizeable/ResizableDraggable.dart';
import 'package:flutter/services.dart';

import 'SpeechDialog/BubbleEditDialog.dart';
import 'SpeechDialog/SpeechBubbleComponents.dart';
import 'SpeechDialog/SpeechBubbleEditDialog.dart';
import 'TextEditorDialog/TextEditDialog.dart';

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
  Color selectedColor = Colors.black;
  Color _selectedBackgroundColor = Colors.white;

  bool isDrawing = false;
  Color drawSelectedColor = Colors.black;

  double selectedBrushSize = 1.0;

  DrawingTool currentTool = DrawingTool.pen;

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

    print('Panel elements count: ${currentElements.length}');
    for (int i = 0; i < currentElements.length; i++) {
      print(
          'Element $i: ${currentElements[i].type} - ${currentElements[i].value}');
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

    print('Building element: ${element.type} with value: ${element.value}');

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
                fontWeight: element.fontWeight ?? FontWeight.normal,
                fontStyle: element.fontStyle ?? FontStyle.normal,
              ),
            ),
          ),
        );
        break;

      case 'speech_bubble':
        child = _buildSpeechBubble(element);
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
      case 'Draw':
        final points = element.value.split(';').map((pair) {
          final coords = pair.split(',');
          return Offset(
            double.tryParse(coords[0]) ?? 0,
            double.tryParse(coords[1]) ?? 0,
          );
        }).toList();

        final drawingWidget = CustomPaint(
          painter: DrawingElementPainter(
            points: points,
            color: element.color ?? Colors.black,
            strokeWidth: element.fontSize ?? 1.0, // 👈 use saved size
          ),
        );

        final isSelected = selectedElementIndex == index;
        final decoratedChild = Container(
          decoration: BoxDecoration(
            border:
                isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: drawingWidget,
        );

        if (_isEditing) {
          return ResizableDraggable(
            key: elementKeys[index],
            size: Size(element.width, element.height),
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedElementIndex = isSelected ? null : index;
                });
              },
              onDoubleTap: () => _editElement(index),
              child: decoratedChild,
            ),
          );
        } else {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(
              width: element.width,
              height: element.height,
              child: drawingWidget,
            ),
          );
        }

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
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedElementIndex =
                  selectedElementIndex == index ? null : index;
            });
          },
          onDoubleTap: () {
            _editElement(index);
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

  Widget _buildSpeechBubble(PanelElementModel element) {
    // Parse bubble properties from element data
    final bubbleData = _parseBubbleData(element);

    return CustomPaint(
      size: Size(element.width, element.height),
      painter: SpeechBubblePainter(
        bubbleColor: bubbleData['bubbleColor'] ?? Colors.white,
        borderColor: bubbleData['borderColor'] ?? Colors.black,
        borderWidth: bubbleData['borderWidth'] ?? 2.0,
        bubbleShape: bubbleData['bubbleShape'] ?? BubbleShape.oval,
        tailPosition: bubbleData['tailPosition'] ?? TailPosition.bottomLeft,
      ),
      child: Container(
        padding: EdgeInsets.all(bubbleData['padding'] ?? 12.0),
        child: Center(
          child: Text(
            bubbleData['text'] ?? element.value,
            style: TextStyle(
              fontSize: bubbleData['fontSize'] ?? 16.0,
              color: bubbleData['textColor'] ?? Colors.black,
              fontFamily: bubbleData['fontFamily'] ?? 'Roboto',
              fontWeight: bubbleData['fontWeight'] ?? FontWeight.normal,
              fontStyle: bubbleData['fontStyle'] ?? FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseBubbleData(PanelElementModel element) {
    // Parse JSON-like data from element.value or use defaults
    try {
      // If element.value contains JSON data, parse it
      // For now, we'll use a simple format or defaults
      return {
        'text': element.value.split('|')[0] ?? 'Speech',
        'bubbleColor': element.color ?? Colors.white,
        'borderColor': Colors.black,
        'borderWidth': 2.0,
        'bubbleShape': BubbleShape.oval,
        'tailPosition': TailPosition.bottomLeft,
        'fontSize': element.fontSize ?? 16.0,
        'textColor': Colors.black,
        'fontFamily': element.fontFamily ?? 'Roboto',
        'fontWeight': element.fontWeight ?? FontWeight.normal,
        'fontStyle': element.fontStyle ?? FontStyle.normal,
        'padding': 12.0,
      };
    } catch (e) {
      return {
        'text': element.value,
        'bubbleColor': Colors.white,
        'borderColor': Colors.black,
        'borderWidth': 2.0,
        'bubbleShape': BubbleShape.oval,
        'tailPosition': TailPosition.bottomLeft,
        'fontSize': 16.0,
        'textColor': Colors.black,
        'fontFamily': 'Roboto',
        'fontWeight': FontWeight.normal,
        'fontStyle': FontStyle.normal,
        'padding': 12.0,
      };
    }
  }

  void _editElement(int index) {
    final element = currentElements[index];

    switch (element.type) {
      case 'speech_bubble':
        _editSpeechBubble(index);
        break;
      case 'text':
        _editTextElement(index);
        break;
      case 'bubble':
        _editBubbleElement(index);
        break;
      default:
        // Show generic edit options
        break;
    }
  }

  void _editSpeechBubble(int index) async {
    final element = currentElements[index];
    final bubbleData = _parseBubbleData(element);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SpeechBubbleEditDialog(
        initialData: bubbleData,
      ),
    );

    if (result != null) {
      setState(() {
        currentElements[index] = element.copyWith(
          value: result['text'],
          color: result['bubbleColor'],
          fontSize: result['fontSize'],
          fontFamily: result['fontFamily'],
          fontWeight: result['fontWeight'],
          fontStyle: result['fontStyle'],
        );
      });
    }
  }

  void _editTextElement(int index) async {
    final element = currentElements[index];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TextEditDialog(
        initialText: element.value,
        initialFontSize: element.fontSize ?? 20,
        initialColor: element.color ?? Colors.black,
        initialFontFamily: element.fontFamily ?? 'Roboto',
        initialFontWeight: element.fontWeight ?? FontWeight.normal,
        initialFontStyle: element.fontStyle ?? FontStyle.normal,
      ),
    );

    if (result != null) {
      setState(() {
        currentElements[index] = element.copyWith(
          value: result['text'],
          fontSize: result['fontSize'],
          color: result['color'],
          fontFamily: result['fontFamily'],
          fontWeight: result['fontWeight'],
          fontStyle: result['fontStyle'],
        );
      });
    }
  }

  void _editBubbleElement(int index) async {
    final element = currentElements[index];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BubbleEditDialog(
        initialText: element.value,
        initialColor: element.color ?? Colors.blue,
      ),
    );

    if (result != null) {
      setState(() {
        currentElements[index] = element.copyWith(
          value: result['text'],
          color: result['color'],
        );
      });
    }
  }

  void _addNewElement(PanelElementModel element) {
    setState(() {
      currentElements.add(element);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
    });
  }

  void _addSpeechBubble() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SpeechBubbleEditDialog(
        initialData: {
          'text': 'Hello!',
          'bubbleColor': Colors.white,
          'borderColor': Colors.black,
          'borderWidth': 2.0,
          'bubbleShape': BubbleShape.oval,
          'tailPosition': TailPosition.bottomLeft,
          'fontSize': 16.0,
          'textColor': Colors.black,
          'fontFamily': 'Roboto',
          'fontWeight': FontWeight.normal,
          'fontStyle': FontStyle.normal,
          'padding': 12.0,
        },
      ),
    );

    if (result != null) {
      final newElement = PanelElementModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'speech_bubble',
        value: result['text'],
        offset: const Offset(50, 50),
        width: 120,
        height: 80,
        size: const Size(120, 80),
        color: result['bubbleColor'],
        fontSize: result['fontSize'],
        fontFamily: result['fontFamily'],
        fontWeight: result['fontWeight'],
        fontStyle: result['fontStyle'],
      );
      _addNewElement(newElement);
    }
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
              if (currentElements.isNotEmpty && elementKeys.isNotEmpty) {
                setState(() {
                  // Clear selection if last element is selected
                  if (selectedElementIndex == currentElements.length - 1) {
                    selectedElementIndex = null;
                  }
                  currentElements.removeLast();
                  elementKeys.removeLast();
                });
              }
            },
          ),
          if (selectedElementIndex != null)
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Elements: ${currentElements.length} | Editing: $_isEditing',
                  style: const TextStyle(fontSize: 12),
                ),
                if (selectedElementIndex != null)
                  Text(
                    'Selected: ${currentElements[selectedElementIndex!].type}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
              ],
            ),
          ),

          // Panel Canvas Area
          Expanded(
            child: RepaintBoundary(
              key: _panelContentKey,
              child: Container(
                color: _selectedBackgroundColor,
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    // Grid (optional)
                    if (_isEditing)
                      CustomPaint(
                        size: Size.infinite,
                        painter: GridPainter(),
                      ),

                    // ✅ Drawing Canvas on top of grid
                    if (isDrawing)
                      Positioned.fill(
                        child: DrawingCanvas(
                            tool: currentTool,
                            brushSize: selectedBrushSize,
                            color: drawSelectedColor,
                            onDrawingComplete: (points) {
                              final nonZeroPoints = points
                                  .where((p) => p != Offset.zero)
                                  .toList();
                              if (nonZeroPoints.isEmpty) {
                                setState(() => isDrawing = false);
                                return;
                              }
                              final minX = nonZeroPoints
                                  .map((p) => p.dx)
                                  .reduce((a, b) => a < b ? a : b);
                              final minY = nonZeroPoints
                                  .map((p) => p.dy)
                                  .reduce((a, b) => a < b ? a : b);
                              final maxX = nonZeroPoints
                                  .map((p) => p.dx)
                                  .reduce((a, b) => a > b ? a : b);
                              final maxY = nonZeroPoints
                                  .map((p) => p.dy)
                                  .reduce((a, b) => a > b ? a : b);

                              final boundingWidth =
                                  (maxX - minX).clamp(10.0, double.infinity);
                              final boundingHeight =
                                  (maxY - minY).clamp(10.0, double.infinity);

                              final normalizedPoints = points
                                  .map((p) => p - Offset(minX, minY))
                                  .toList();
                              final drawingData = normalizedPoints
                                  .map((e) => '${e.dx},${e.dy}')
                                  .join(';');

                              final newElement = PanelElementModel(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                type: 'Draw',
                                value: drawingData,
                                offset: Offset(minX, minY),
                                width: boundingWidth,
                                height: boundingHeight,
                                size: Size(boundingWidth, boundingHeight),
                                color: drawSelectedColor,
                                fontSize: selectedBrushSize, // 👈 store strokeWidth here
                              );

                              _addNewElement(newElement);
                              setState(() => isDrawing = false);
                            }),
                      ),

                    // All existing elements
                    for (int i = 0; i < currentElements.length; i++)
                      _buildElementWidget(currentElements[i], i),

                    // Empty state message
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

          // Drawing tools & panel controls
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
            _toolButton(Icons.chat_bubble, 'Speech Bubble', _addSpeechBubble),
            _toolButton(Icons.bubble_chart, 'Bubble', _addBubble),
            _toolButton(Icons.text_fields, 'Text', _addTextBox),
            _toolButton(Icons.draw, 'Draw', () {
              setState(() => isDrawing = true);
              _showDrawingToolsPanel();
            }),
          ],
        ),
      ),
    );
  }

  void _showDrawingToolsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      // changed to white for better visibility
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DrawingToolsPanel(
            currentTool: currentTool,
            currentColor: drawSelectedColor,
            currentBrushSize: selectedBrushSize,
            onToolChanged: (tool) {
              if (mounted) {
                setState(() => currentTool = tool);
              }
            },
            onColorChanged: (color) {
              if (mounted) {
                setState(() => drawSelectedColor = color);
              }
            },
            onBrushSizeChanged: (size) {
              if (mounted) {
                setState(() => selectedBrushSize = size);
              }
            },
            onUndo: () {
              // You can implement undo functionality here later
            },
            onClearAll: () {
              // You can implement canvas clear logic here later
            },
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
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

  // ... (keep all your existing methods like _pickBackgroundColor, _uploadImage, etc.)

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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TextEditDialog(
        initialText: 'Enter text',
        initialFontSize: 20,
        initialColor: Colors.black,
        initialFontFamily: 'Roboto',
        initialFontWeight: FontWeight.normal,
        initialFontStyle: FontStyle.normal,
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
        fontWeight: result['fontWeight'],
        fontStyle: result['fontStyle'],
      );
      _addNewElement(newElement);
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
