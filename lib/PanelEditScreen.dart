import 'dart:convert';
import 'dart:io';

import 'package:comic_editor/SpeechDrag/DragSpeechBubbleEditDialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'ClipArt/CharacterClipartPicker.dart';
import 'Draw/DrawingCanvas.dart';
import 'Draw/DrawingElementPainter.dart';
import 'Draw/DrawingToolsPanel.dart';
import 'Resizeable/GridPainter.dart';
import 'PanelModel/PanelElementModel.dart';
import 'Resizeable/ResizableDraggable.dart';
import 'package:flutter/services.dart';
import 'SpeechDrag/DragSpeechBubbleComponents.dart';
import 'SpeechDrag/DragSpeechBubbleData.dart';
import 'SpeechDrag/SpeechBubblePainterWithText.dart';
import 'TextEditorDialog/TextEditDialog.dart';

class PanelEditScreen extends StatefulWidget {
  final ComicPanel panel;
  final Offset panelOffset;
  final Size panelSize; // size of the panel

  const PanelEditScreen({
    super.key,
    required this.panel,
    required this.panelOffset,
    required this.panelSize, // size of the panel
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

  String? _activeToolId;

  bool _isSaving = false;
  bool _isEditing = true;

  final GlobalKey _panelContentKey = GlobalKey();
  int? selectedElementIndex;
  double aspectRatio = 3 / 4; // or 4 / 3 if landscape
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
  Map<String, IconData> iconMap = {
    'star': Icons.star,
    'favorite': Icons.favorite,
    'face': Icons.face,
    'emoji_emotions': Icons.emoji_emotions,
    'emoji_nature': Icons.emoji_nature,
    'emoji_people': Icons.emoji_people,
    'music_note': Icons.music_note,
    'cake': Icons.cake,
    'camera_alt': Icons.camera_alt,
    'wb_sunny': Icons.wb_sunny,
    'beach_access': Icons.beach_access,
    'local_florist': Icons.local_florist,
    'pets': Icons.pets,
    'sports_esports': Icons.sports_esports,
  };

  @override
  void initState() {
    super.initState();
    panel = widget.panel;
    currentElements = List.from(panel.elements);
    _selectedBackgroundColor = panel.backgroundColor;

    _initializeElements();
  }

  void _initializeElements() {
    elementKeys.clear();
    for (int i = 0; i < currentElements.length; i++) {
      elementKeys.add(GlobalKey<ResizableDraggableState>());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;

    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Panel'),
        backgroundColor: Colors.blue.shade400,
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
                        if (selectedElementIndex ==
                            currentElements.length - 1) {
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
      body: Stack(
        clipBehavior: Clip.hardEdge, //   keep visuals inside the panel
        children: [
          Column(
            children: [
              // Panel Canvas Area
/*
              Expanded(
                child: Center(
                  // ensures it's centered if there's padding/margin
                  child: AspectRatio(
*/
/*
                    aspectRatio: aspectRatio,
*/ /*

                    aspectRatio: w / h, // lock aspect
                    // or 4 / 3 or any other fixed ratio
                    child: RepaintBoundary(
                      key: _panelContentKey,
                      child: Container(
                        width: w,              // logical canvas width
                        height: h,
                        color: _selectedBackgroundColor,
                        child: Stack(
                          clipBehavior: Clip.hardEdge, // keep visuals inside the panel
                          children: [
                            if (_isEditing)
                              CustomPaint(
                                size: Size.infinite,
                                painter: GridPainter(),
                              ),
                            if (isDrawing)
                              Positioned.fill(
                                child: DrawingCanvas(
                                  tool: currentTool,
                                  brushSize: selectedBrushSize,
                                  color: drawSelectedColor,
                                  onDrawingComplete: _onDrawingComplete,
                                ),
                              ),
                            for (int i = 0; i < currentElements.length; i++)
                              _buildElementWidget(currentElements[i], i),
                            if (currentElements.isEmpty)
                              const Center(
                                child: Text(
                                  'No elements added yet.\nUse the tools below to add content.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
*/
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: w / h, // keep panel aspect
                    child: Container(
                      // 🔹 Visual chrome (NOT exported)
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RepaintBoundary(
                          key: _panelContentKey, //
                          child: Container(
                            color: _selectedBackgroundColor,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              // keep content within panel
                              children: [
                                if (_isEditing)
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: GridPainter(),
                                  ),
                                if (isDrawing)
                                  Positioned.fill(
                                    child: DrawingCanvas(
                                      tool: currentTool,
                                      brushSize: selectedBrushSize,
                                      color: drawSelectedColor,
                                      onDrawingComplete: _onDrawingComplete,
                                    ),
                                  ),
                                for (int i = 0; i < currentElements.length; i++)
                                  _buildElementWidget(currentElements[i], i),
                                if (currentElements.isEmpty)
                                  const Center(
                                    child: Text(
                                      'No elements added yet.\nUse the tools below to add content.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Footer toolbar
              _buildToolOptions(),
            ],
          ),
          if (selectedElementIndex != null)
            _buildFloatingToolbox(currentElements[selectedElementIndex!]),
        ],
      ),
    );
  }

  Widget _buildElementWidget(PanelElementModel element, int index) {
    Widget child;
    switch (element.type) {
/*      case 'character':
      case 'clipart':
        final isSvg = element.value.toLowerCase().endsWith('.svg');
        final box = SizedBox(
          width: element.width,
          height: element.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: isSvg
                ? SvgPicture.asset(element.value)
                : Image.asset(element.value),
          ),
        );

        if (_isEditing) {
          return ResizableDraggable(
            key: elementKeys[index],
            isSelected: selectedElementIndex == index,
            size: Size(element.width, element.height),
            initialTop: element.offset.dy,
            initialLeft: element.offset.dx,
            onPositionChanged: (pos, size) {
              setState(() {
                currentElements[index] = currentElements[index].copyWith(
                  offset: pos,
                  size: size,
                  width: size.width,
                  height: size.height,
                );
              });
            },
            child: GestureDetector(
              onTap: () => setState(() =>
              selectedElementIndex = selectedElementIndex == index ? null : index),
              onDoubleTap: () => _editElement(index),
              child: box,
            ),
          );
        } else {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(
              width: element.width,
              height: element.height,
              child: box,
            ),
          );
        }*/

      case 'character':
      case 'clipart':
        child = Container(
          width: element.width,
          height: element.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.asset(
                (element.value),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: element.width,
                    height: element.height,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
        );
        break;
      case 'text':
        child = Container(
          width: element.width,
          height: element.height,
          alignment: Alignment.center,
          child: Text(
            element.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: element.fontSize ?? 16,
              color: element.color ?? Colors.black,
              fontFamily: element.fontFamily,
              fontWeight: element.fontWeight ?? FontWeight.normal,
              fontStyle: element.fontStyle ?? FontStyle.normal,
            ),
          ),
        );
        break;

      /* case 'speech_bubble':
        final isSelected = selectedElementIndex == index;
        final decoratedChild = Container(
          decoration: BoxDecoration(
            border:
                isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: _buildSpeechBubble(element),
        );

        if (_isEditing) {
          return ResizableDraggable(
            key: elementKeys[index],
            isSelected: selectedElementIndex == index,
            size: Size(element.width, element.height),
            initialTop: element.offset.dy,
            initialLeft: element.offset.dx,
            minWidth: 10.0,
            minHeight: 10.0,
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
              onDoubleTap: () {
                _editElement(index); // opens the edit dialog
              },
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
              child: _buildSpeechBubble(element),
            ),
          );
        }*/

      // In your element switch:
      case 'speech_bubble':
        {
          final isSelected = selectedElementIndex == index;
          final child = _buildImageElement(element);

          final decorated = Container(
            decoration: BoxDecoration(
              border:
                  isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: child,
          );

          if (_isEditing) {
            return ResizableDraggable(
              key: elementKeys[index],
              isSelected: isSelected,
              size: Size(element.width, element.height),
              initialTop: element.offset.dy,
              initialLeft: element.offset.dx,
              minWidth: 10,
              minHeight: 10,
              onPositionChanged: (pos, size) {
                if (!mounted) return;
                setState(() {
                  currentElements[index] = currentElements[index].copyWith(
                    offset: pos,
                    size: size,
                    width: size.width,
                    height: size.height,
                  );
                });
              },
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedElementIndex = isSelected ? null : index;
                  });
                },
                onDoubleTap: () {
                  _editElement(index); // Optional: reopen dialog using meta
                },
                child: decorated,
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

      case 'image':
        child = Container(
          width: element.width,
          height: element.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.file(
                File(element.value),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: element.width,
                    height: element.height,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
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
            strokeWidth: element.fontSize ?? 1.0,
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
            isSelected: selectedElementIndex == index,
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
        isSelected: selectedElementIndex == index,
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

  Widget _buildFloatingToolbox(PanelElementModel element) {
    List<Widget> toolIcons = [];

    switch (element.type) {
      case 'text':
        toolIcons = [
          _toolIcon(
            id: 'color',
            icon: Icons.format_color_text,
            tooltip: 'Text Color',
            onTap: () => _changeTextColorById(element.id),
          ),
          _toolIcon(
            id: 'size',
            icon: Icons.format_size,
            tooltip: 'Font Size',
            onTap: () => _changeFontSizeById(element.id),
          ),
          _toolIcon(
            id: 'bold',
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onTap: () => _toggleBoldById(element.id),
          ),
          _toolIcon(
            id: 'italic',
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onTap: () => _toggleItalicById(element.id),
          ),
          _toolIcon(
            id: 'delete',
            icon: Icons.delete,
            tooltip: 'Delete',
            onTap: () => _deleteElementById(element.id),
          ),
        ];
        break;

      case 'image':
        toolIcons = [
          /*_toolIcon(
            id: 'rotate',
            icon: Icons.rotate_right,
            tooltip: 'Rotate 90°',
            onTap: () {
              final index = selectedElementIndex!;
              final e = currentElements[index];
              setState(() {
                currentElements[index] = e.copyWith(
                  rotationAngle: ((e.rotationAngle ?? 0) + 90) % 360,
                );
              });
            },
          ),*/
          /*   _toolIcon(
            id: 'flipX',
            icon: Icons.flip,
            tooltip: 'Flip Horizontal',
            onTap: () {
              final index = selectedElementIndex!;
              final e = currentElements[index];
              setState(() {
                currentElements[index] = e.copyWith(
                  flipX: !(e.flipX ?? false),
                );
              });
            },
          ),*/
          /* _toolIcon(
            id: 'flipY',
            icon: Icons.flip_camera_android,
            tooltip: 'Flip Vertical',
            onTap: () {
              final index = selectedElementIndex!;
              final e = currentElements[index];
              setState(() {
                currentElements[index] = e.copyWith(
                  flipY: !(e.flipY ?? false),
                );
              });
            },
          ),*/
          /* _toolIcon(
            id: 'crop',
            icon: Icons.crop,
            tooltip: 'Crop Image',
            onTap: () => _cropImageById(element.id),
          ),*/
          _toolIcon(
            id: 'replace',
            icon: Icons.image_search,
            tooltip: 'Replace Image',
            onTap: () => _replaceImageById(element.id),
          ),
          _toolIcon(
            id: 'delete',
            icon: Icons.delete,
            tooltip: 'Delete',
            onTap: () => _deleteElementById(element.id),
          ),
        ];
        break;

      default:
        return const SizedBox.shrink(); // Don't show toolbox for other types
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: toolIcons,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolIcon({
    required String id,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isActive = _activeToolId == id;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? Colors.blue : Colors.black,
        ),
        tooltip: tooltip,
        onPressed: () {
          setState(() => _activeToolId = id);
          onTap();
          // Reset highlight after some time if you want:
          Future.delayed(const Duration(milliseconds: 400), () {
            if (_activeToolId == id) {
              setState(() => _activeToolId = null);
            }
          });
        },
      ),
    );
  }

  void _changeTextColorById(String id) async {
    print("Pressed Bold for index ${id}");

    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    Color selectedColor = currentElements[index].color ?? Colors.black;

    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pick Text Color"),
          content: MaterialPicker(
            //BlockPicker
            pickerColor: selectedColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(context, selectedColor),
                child: const Text("OK")),
          ],
        );
      },
    );

    if (pickedColor != null) {
      setState(() {
        currentElements[index] =
            currentElements[index].copyWith(color: pickedColor);
      });
    }
  }

  void _changeFontSizeById(String id) async {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    double currentSize = currentElements[index].fontSize ?? 16;

    final newSize = await showDialog<double>(
      context: context,
      builder: (context) {
        double tempSize = currentSize;

        return AlertDialog(
          title: const Text("Set Font Size"),
          content: SizedBox(
            height: 80,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Slider(
                  min: 8,
                  max: 72,
                  divisions: 64,
                  value: tempSize,
                  label: tempSize.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() => tempSize = value);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempSize),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (newSize != null) {
      setState(() {
        currentElements[index] =
            currentElements[index].copyWith(fontSize: newSize);
      });
    }
  }

  void _toggleBoldById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    setState(() {
      final currentWeight = currentElements[index].fontWeight;
      final newWeight = currentWeight == FontWeight.bold
          ? FontWeight.normal
          : FontWeight.bold;
      currentElements[index] =
          currentElements[index].copyWith(fontWeight: newWeight);
    });
  }

  void _toggleItalicById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    setState(() {
      final currentStyle = currentElements[index].fontStyle;
      final newStyle = currentStyle == FontStyle.italic
          ? FontStyle.normal
          : FontStyle.italic;
      currentElements[index] =
          currentElements[index].copyWith(fontStyle: newStyle);
    });
  }

  void _replaceImageById(String id) async {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        currentElements[index] = currentElements[index].copyWith(
          value: pickedFile.path,
        );
      });
    }
  }

  void _deleteElementById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    setState(() {
      currentElements.removeAt(index);
      elementKeys.removeAt(index);
      if (selectedElementIndex == index) {
        selectedElementIndex = null;
      } else if (selectedElementIndex != null &&
          selectedElementIndex! > index) {
        selectedElementIndex = selectedElementIndex! - 1;
      }
    });
  }

  Widget _buildSpeechBubble(PanelElementModel element) {
    final bubble = element.speechBubbleData ??
        DragSpeechBubbleData.fromMap(jsonDecode(element.value));
    if (bubble == null) {
      return const SizedBox(); // fallback
    }
    return SizedBox.expand(
      child: CustomPaint(
        painter: DragSpeechBubblePainter(
          bubbleColor: bubble.bubbleColor,
          borderColor: bubble.borderColor,
          borderWidth: bubble.borderWidth,
          bubbleShape: bubble.bubbleShape,
          tailOffset: bubble.tailOffset,
        ),
        child: Padding(
          padding: EdgeInsets.all(bubble.padding),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              bubble.text,
              style: TextStyle(
                fontSize: bubble.fontSize,
                color: bubble.textColor,
                fontFamily: bubble.fontFamily,
                fontWeight: bubble.fontWeight,
                fontStyle: bubble.fontStyle,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseBubbleData(PanelElementModel element) {
    try {
      final parsed = jsonDecode(element.value);
      return {
        'text': parsed['text'] ?? 'Speech',
        'bubbleColor': Color(parsed['bubbleColor'] ?? Colors.white.value),
        'borderColor': Color(parsed['borderColor'] ?? Colors.black.value),
        'borderWidth': (parsed['borderWidth'] ?? 2.0).toDouble(),
        'bubbleShape': DragBubbleShape.values[parsed['bubbleShape'] ?? 0],
        'tailOffset': Offset(
          (parsed['tailOffset']?['dx'] ?? 100.0).toDouble(),
          (parsed['tailOffset']?['dy'] ?? 120.0).toDouble(),
        ),
        'fontSize': (parsed['fontSize'] ?? 16.0).toDouble(),
        'textColor': Color(parsed['textColor'] ?? Colors.black.value),
        'fontFamily': parsed['fontFamily'] ?? 'Roboto',
        'fontWeight': parsed['fontWeight'] != null
            ? FontWeight.values[parsed['fontWeight']]
            : FontWeight.normal,
        'fontStyle': parsed['fontStyle'] != null
            ? FontStyle.values[parsed['fontStyle']]
            : FontStyle.normal,
        'padding': (parsed['padding'] ?? 12.0).toDouble(),
      };
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing bubble data: $e");
      }

      return {
        'text': element.value,
        'bubbleColor': Colors.white,
        'borderColor': Colors.black,
        'borderWidth': 2.0,
        'bubbleShape': DragBubbleShape.rectangle,
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
      default:
        // Show generic edit options
        break;
    }
  }


/*
  void _editSpeechBubble(int index) async {
    final element = currentElements[index];

    // Try parsing existing bubble data from element.value
    final Map<String, dynamic> initialData = _parseBubbleData(element);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(
        initialData: initialData,
      ),
    );

    if (result != null) {

      final updatedBubble = DragSpeechBubbleData(
        text: result['text'],
        bubbleColor: result['bubbleColor'],
        borderColor: result['borderColor'],
        borderWidth: result['borderWidth'],
        bubbleShape: result['bubbleShape'],
        tailOffset: result['tailOffset'],
        fontSize: result['fontSize'],
        textColor: result['textColor'],
        fontFamily: result['fontFamily'],
        fontWeight: result['fontWeight'],
        fontStyle: result['fontStyle'],
        padding: result['padding'],
      );
      setState(() {
        currentElements[index] = element.copyWith(
          value: jsonEncode(updatedBubble.toMap()),
          color: updatedBubble.bubbleColor,
          fontSize: updatedBubble.fontSize,
          fontFamily: updatedBubble.fontFamily,
          fontWeight: updatedBubble.fontWeight,
          fontStyle: updatedBubble.fontStyle,
          width: result['width'],
          height: result['height'],
          size: Size(result['width'], result['height']),
        );
      });

    }
  }
*/

  /// ===== Edit flow: open dialog with original vector data and save new PNG + vector =====
  Future<void> _editSpeechBubble(int index) async {
    final element = currentElements[index];

    // 1) Prefill the editor with the ORIGINAL vector data saved in meta
    final initialData = _extractBubbleInitialData(element);

    // 2) Open your editor; it should return fresh pngBytes + updated vector fields
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(
        initialData: initialData,
      ),
    );

    if (result == null) return;

    // 3) Build updated vector model from dialog result
    final updatedBubble = DragSpeechBubbleData(
      text: result['text'],
      bubbleColor: result['bubbleColor'],
      borderColor: result['borderColor'],
      borderWidth: (result['borderWidth'] as num).toDouble(),
      bubbleShape: result['bubbleShape'] as DragBubbleShape,
      fontSize: (result['fontSize'] as num).toDouble(),
      textColor: result['textColor'] as Color,
      fontFamily: result['fontFamily'] as String,
      fontWeight: result['fontWeight'] as FontWeight,
      fontStyle: result['fontStyle'] as FontStyle,
      padding: (result['padding'] as num).toDouble(),
      tailOffset: result['tailOffset'] as Offset,
      // ✅ keep normalized tail for future size changes / re-edits
      tailNorm: Offset(
        (result['tailNorm']['dx'] as num).toDouble(),
        (result['tailNorm']['dy'] as num).toDouble(),
      ),
    );

    // 4) Read the fresh rendered image + size from dialog
    final Uint8List pngBytes = result['pngBytes'] as Uint8List;
    final double newW = (result['width'] as num).toDouble();
    final double newH = (result['height'] as num).toDouble();

    // 5) Commit changes:
    //    - value: PNG (base64)
    //    - meta: original vector data (for future edits)
    //    - width/height/size: from the renderer
    //    - offset: keep existing position on the page
    setState(() {
      currentElements[index] = element.copyWith(
        value: base64Encode(pngBytes),
        // ✅ bitmap goes into value
        width: newW,
        height: newH,
        size: Size(newW, newH),
        offset: element.offset,
        // keep position
        // optional: expose some style fields for searches/filters
        color: updatedBubble.bubbleColor,
        fontSize: updatedBubble.fontSize,
        fontFamily: updatedBubble.fontFamily,
        fontWeight: updatedBubble.fontWeight,
        fontStyle: updatedBubble.fontStyle,
        // ✅ keep the original data for re-edit
        meta: jsonEncode({
          'kind': 'speech_bubble_original',
          'data': updatedBubble.toMap(),
        }),
      );
    });
  }

  /// ===== Helper: extract initial data for the editor from the element.meta =====
  Map<String, dynamic> _extractBubbleInitialData(PanelElementModel element) {
    // Default fallback if meta is missing/corrupt
    Map<String, dynamic> fallback = {
      'text': 'Hello!',
      'bubbleColor': Colors.white,
      'borderColor': Colors.black,
      'borderWidth': 2.0,
      'bubbleShape': DragBubbleShape.rectangle,
      'tailOffset': Offset(element.width * 0.5, element.height * 0.85),
      'tailNorm': {'dx': 0.5, 'dy': 0.9},
      'fontSize': 16.0,
      'textColor': Colors.black,
      'fontFamily': 'Roboto',
      'fontWeight': FontWeight.normal,
      'fontStyle': FontStyle.normal,
      'padding': 12.0,
      // optional hints for the dialog if it uses them
      'width': element.width,
      'height': element.height,
    };

    try {
      if (element.meta == null || element.meta!.isEmpty) return fallback;

      final metaObj = jsonDecode(element.meta!);
      if (metaObj is! Map) return fallback;

      if (metaObj['kind'] == 'speech_bubble_original' &&
          metaObj['data'] != null) {
        final dataMap = Map<String, dynamic>.from(metaObj['data'] as Map);
        return {
          'text': dataMap['text'],
          'bubbleColor':
              _readColor(dataMap['bubbleColor'], fallback['bubbleColor']),
          'borderColor':
              _readColor(dataMap['borderColor'], fallback['borderColor']),
          'borderWidth': (dataMap['borderWidth'] as num?)?.toDouble() ??
              fallback['borderWidth'],
          'bubbleShape': _readBubbleShape(dataMap['bubbleShape']) ??
              fallback['bubbleShape'],
          'tailOffset':
              _readOffset(dataMap['tailOffset']) ?? fallback['tailOffset'],
          'tailNorm':
              _readTailNorm(dataMap['tailNorm']) ?? fallback['tailNorm'],
          'fontSize':
              (dataMap['fontSize'] as num?)?.toDouble() ?? fallback['fontSize'],
          'textColor': _readColor(dataMap['textColor'], fallback['textColor']),
          'fontFamily': dataMap['fontFamily'] ?? fallback['fontFamily'],
          'fontWeight':
              _readFontWeight(dataMap['fontWeight']) ?? fallback['fontWeight'],
          'fontStyle':
              _readFontStyle(dataMap['fontStyle']) ?? fallback['fontStyle'],
          'padding':
              (dataMap['padding'] as num?)?.toDouble() ?? fallback['padding'],
          'width': element.width,
          'height': element.height,
        };
      }
    } catch (_) {
      // fall through to fallback
    }

    return fallback;
  }

// --- small readers to keep parsing robust ---

  Color _readColor(dynamic v, Color fallback) {
    if (v is int) return Color(v);
    if (v is Color) return v;
    return fallback;
  }

  Offset? _readOffset(dynamic v) {
    if (v is Offset) return v;
    if (v is Map) {
      final dx = (v['dx'] as num?)?.toDouble();
      final dy = (v['dy'] as num?)?.toDouble();
      if (dx != null && dy != null) return Offset(dx, dy);
    }
    return null;
  }

  Map<String, double>? _readTailNorm(dynamic v) {
    if (v is Map) {
      final dx = (v['dx'] as num?)?.toDouble();
      final dy = (v['dy'] as num?)?.toDouble();
      if (dx != null && dy != null) return {'dx': dx, 'dy': dy};
    }
    return null;
  }

  DragBubbleShape? _readBubbleShape(dynamic v) {
    if (v is DragBubbleShape) return v;
    if (v is String) {
      // adjust if you serialize enums as strings
      switch (v) {
        case 'rectangle':
          return DragBubbleShape.rectangle;
        case 'shout':
          return DragBubbleShape.shout;
      }
    }
    return null;
  }

  FontWeight? _readFontWeight(dynamic v) {
    if (v is FontWeight) return v;
    if (v is String) {
      switch (v) {
        case 'w100':
          return FontWeight.w100;
        case 'w200':
          return FontWeight.w200;
        case 'w300':
          return FontWeight.w300;
        case 'w400':
          return FontWeight.w400;
        case 'w500':
          return FontWeight.w500;
        case 'w600':
          return FontWeight.w600;
        case 'w700':
          return FontWeight.w700;
        case 'w800':
          return FontWeight.w800;
        case 'w900':
          return FontWeight.w900;
        case 'normal':
          return FontWeight.normal;
        case 'bold':
          return FontWeight.bold;
      }
    }
    return null;
  }

  FontStyle? _readFontStyle(dynamic v) {
    if (v is FontStyle) return v;
    if (v is String) {
      switch (v) {
        case 'normal':
          return FontStyle.normal;
        case 'italic':
          return FontStyle.italic;
      }
    }
    return null;
  }

/*
  void _editSpeechBubble(int index) async {
    final element = currentElements[index];

    // Try parsing existing bubble data from element.value
    final Map<String, dynamic> initialData = _parseBubbleData(element);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(
        initialData: initialData,
      ),
    );

    if (result != null) {
      final updatedBubble = DragSpeechBubbleData(
        text: result['text'],
        bubbleColor: result['bubbleColor'],
        borderColor: result['borderColor'],
        borderWidth: result['borderWidth'],
        bubbleShape: result['bubbleShape'],
        tailOffset: result['tailOffset'],
        fontSize: result['fontSize'],
        textColor: result['textColor'],
        fontFamily: result['fontFamily'],
        fontWeight: result['fontWeight'],
        fontStyle: result['fontStyle'],
        padding: result['padding'],
      );
      setState(() {
        currentElements[index] = element.copyWith(
          value: jsonEncode(updatedBubble.toMap()),
          color: updatedBubble.bubbleColor,
          fontSize: updatedBubble.fontSize,
          fontFamily: updatedBubble.fontFamily,
          fontWeight: updatedBubble.fontWeight,
          fontStyle: updatedBubble.fontStyle,
          width: result['width'],
          height: result['height'],
          size: Size(result['width'], result['height']),
        );
      });
    }
  }
*/

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

  void _addNewElement(PanelElementModel element) {
    setState(() {
      currentElements.add(element);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
    });
  }

  Future<void> _addSpeechBubble() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(
        initialData: {
          'text': 'Hello!',
          'bubbleColor': Colors.white,
          'borderColor': Colors.black,
          'borderWidth': 2.0,
          'bubbleShape': DragBubbleShape.rectangle,
          'tailOffset': const Offset(140, 120),
          'fontSize': 16.0,
          'textColor': Colors.black,
          'fontFamily': 'Roboto',
          'fontWeight': FontWeight.normal,
          'fontStyle': FontStyle.normal,
          'padding': 12.0,
        },
      ),
    );

    if (result == null) return;

    final bytes = result['pngBytes'] as Uint8List;
    final width = (result['width'] as num).toDouble();
    final height = (result['height'] as num).toDouble();

    final bubbleData = DragSpeechBubbleData(
      text: result['text'],
      bubbleColor: result['bubbleColor'],
      borderColor: result['borderColor'],
      borderWidth: (result['borderWidth'] as num).toDouble(),
      bubbleShape: result['bubbleShape'] as DragBubbleShape,
      fontSize: (result['fontSize'] as num).toDouble(),
      textColor: result['textColor'] as Color,
      fontFamily: result['fontFamily'] as String,
      fontWeight: result['fontWeight'] as FontWeight,
      fontStyle: result['fontStyle'] as FontStyle,
      padding: (result['padding'] as num).toDouble(),
      tailOffset: result['tailOffset'] as Offset,
      tailNorm: Offset(
        (result['tailNorm']['dx'] as num).toDouble(),
        (result['tailNorm']['dy'] as num).toDouble(),
      ),
    );

    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'speech_bubble',
      // IMPORTANT: it's now a bitmap
      value: base64Encode(bytes),
      // or save to file and store a path
      offset: const Offset(50, 50),
      width: width,
      height: height,
      size: Size(width, height),
      // Keep original vector data for re-edit
      meta: jsonEncode({
        'kind': 'speech_bubble_original',
        'data': bubbleData.toMap(),
      }),
    );

    _addNewElement(newElement);
  }

/*  void _addSpeechBubble() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(
        initialData: {
          'text': 'Hello!',
          'bubbleColor': Colors.white,
          'borderColor': Colors.black,
          'borderWidth': 2.0,
          'bubbleShape': DragBubbleShape.rectangle,
          'tailOffset': const Offset(100, 120),
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
      final bubble = DragSpeechBubbleData(
          text: result['text'],
          bubbleColor: result['bubbleColor'],
          borderColor: result['borderColor'],
          borderWidth: result['borderWidth'],
          bubbleShape: result['bubbleShape'],
          fontSize: result['fontSize'],
          textColor: result['textColor'],
          fontFamily: result['fontFamily'],
          fontWeight: result['fontWeight'],
          fontStyle: result['fontStyle'],
          padding: result['padding'],
          tailOffset: result['tailOffset']);

      final newElement = PanelElementModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'speech_bubble',
        value: jsonEncode(bubble.toMap()),
        offset: const Offset(50, 50),
        width: result['width'],
        height: result['height'],
        size: Size(result['width'], result['height']),
      );

      _addNewElement(newElement);
    }
  }*/

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

  Widget _buildToolOptions() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolNavButton(
                    Icons.format_color_fill, 'BG', _pickBackgroundColor),
                _toolNavButton(Icons.image, 'Image', _uploadImage),
                /* _toolNavButton(Icons.face, 'Character', () async {
                  final selected = await showCharacterPicker(context);
                  if (selected != null) {
                    _addCharacterAsset(selected); // You will implement this
                  }
                }),*/

/*
                _toolNavButton(Icons.insert_emoticon, 'Clipart', () async {
                  final result = await showCharacterAndClipartPicker(context);
                  if (result != null && result['type'] == 'character') {
                    _addCharacterEmoji(result['value']);
                  }
                }),*/
                _toolNavButton(Icons.face, 'Character', () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => CharacterClipartPickerDialog(),
                  );
                  if (result != null) {
                    if (result['type'] == 'character') {
                      _addCharacterAsset(result['value'] as String);
                    } else if (result['type'] == 'clipart') {
                      _addClipArtAsset(result['value'] as String);
                    }
                  }
                }),
                _toolNavButton(
                    Icons.chat_bubble, 'Speech Bubble', _addSpeechBubble),
                _toolNavButton(Icons.text_fields, 'Text', _addTextBox),
                _toolNavButton(Icons.draw, 'Draw', () {
                  setState(() => isDrawing = true);
                  _showDrawingToolsPanel();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolNavButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.black87)),
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
          child: MaterialPicker(
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

/*  void _addCharacterAsset(String imagePath) {
    final characterElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'character',
      value: imagePath,
      offset: Offset(50, 50),
      width: 100,
      height: 100,
      size: Size(100, 100),
    );
    _addNewElement(characterElement);
  }*/

  /*void _addClipArt(IconData selectedIcon) {
    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'clipart',
      value: selectedIcon.codePoint.toString(),
      fontFamily: selectedIcon.fontFamily,
      offset: const Offset(50, 50),
      width: 50,
      height: 50,
      size: const Size(50, 50),
      color: Colors.black,
    );
    _addNewElement(newElement);
  }*/
  void _addCharacterAsset(String assetPath) {
    final el = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'character',
      // same type, but now value is a path
      value: assetPath,
      // <-- path to asset
      offset: const Offset(50, 50),
      width: 120,
      height: 120,
      size: const Size(120, 120),
    );
    _addNewElement(el);
  }

  void _addClipArtAsset(String assetPath) {
    final el = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'clipart',
      // distinguish if you want
      value: assetPath,
      offset: const Offset(50, 50),
      width: 100,
      height: 100,
      size: const Size(100, 100),
    );
    _addNewElement(el);
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

/*  Future<Map<String, dynamic>?> showCharacterAndClipartPicker(
      BuildContext context) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return CharacterClipartPickerDialog();
      },
    );
  }*/
  Future<String?> showCharacterPicker(BuildContext context) async {
    final characters = [
      'assets/characters/ic_super_hero_1.png',
      'assets/characters/ic_engineer.png',
      'assets/characters/ic_super_hero.png',
      'assets/characters/ic_women.png',
      'assets/characters/ic_boy.png',
    ];

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose a character'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            itemCount: characters.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, characters[index]),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(characters[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Size _calculateTextSize(
    String text,
    double fontSize,
    FontWeight fontWeight,
    FontStyle fontStyle,
    String fontFamily,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 300);
    return textPainter.size;
  }

  void _onDrawingComplete(List<Offset> points) {
    final nonZeroPoints = points.where((p) => p != Offset.zero).toList();
    if (nonZeroPoints.isEmpty) {
      setState(() => isDrawing = false);
      return;
    }

    final minX = nonZeroPoints.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final minY = nonZeroPoints.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxX = nonZeroPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxY = nonZeroPoints.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    final boundingWidth = (maxX - minX).clamp(10.0, double.infinity);
    final boundingHeight = (maxY - minY).clamp(10.0, double.infinity);

    final normalizedPoints = points.map((p) => p - Offset(minX, minY)).toList();
    final drawingData =
        normalizedPoints.map((e) => '${e.dx},${e.dy}').join(';');

    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'Draw',
      value: drawingData,
      offset: Offset(minX, minY),
      width: boundingWidth,
      height: boundingHeight,
      size: Size(boundingWidth, boundingHeight),
      color: drawSelectedColor,
      fontSize: selectedBrushSize, // store strokeWidth
    );

    _addNewElement(newElement);
    setState(() => isDrawing = false);
  }

  Widget _buildImageElement(PanelElementModel element) {
    try {
      final bytes = base64Decode(element.value);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
