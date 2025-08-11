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
import 'TextEditorDialog/TextEditDialog.dart';

import 'dart:math' as math;

// Menu actions
enum _PanelMenuAction { toggleMultiSelect, group, ungroup, copy, paste ,delete}
bool get _canPaste => true; // or: clipboardElements.isNotEmpty;
class _Snap {
  final int index;
  final Offset offset;
  final double w, h;
  const _Snap(this.index, this.offset, this.w, this.h);
}

class PanelEditScreen extends StatefulWidget {
  final ComicPanel panel;
  final Offset panelOffset;
  final Size panelSize;

  const PanelEditScreen({
    super.key,
    required this.panel,
    required this.panelOffset,
    required this.panelSize,
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
  double aspectRatio = 3 / 4;

  // === NEW: multi-select & grouping ===
  final Set<int> _selected = {};             // indices into currentElements
  bool _multiSelectMode = false;
  Rect? _lastGroupRect;                      // last overlay rect during drag
  List<PanelElementModel>? _clipboardList;   // multi-copy clipboard

  // Clipboard & focus you already had
  PanelElementModel? _clipboard; // kept if you use elsewhere
  Offset? _lastTapLocal;
  final FocusNode _focusNode = FocusNode();

  // === Convenience getters for single vs multi selection
  bool get _hasSelection => _selected.isNotEmpty;
  bool get _hasMultiSelection => _selected.length > 1;
  int? get _singleSelectedIndex => _selected.length == 1 ? _selected.first : null;

  // === Group overlay control ===
  final GlobalKey<ResizableDraggableState> _groupOverlayKey =
  GlobalKey<ResizableDraggableState>();

  static const double _kResizeEps = 0.75; // px threshold to ignore tiny size jitter

// Resize session (baseline snapshot so we don't accumulate error)
  Rect? _resizeBaseRect;
  bool _resizing = false;

  List<_Snap> _resizeSnap = [];


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

  // === selection helpers
  void _selectOnly(int index) {
    setState(() { _selected..clear()..add(index); });
    _resetGroupOverlayRect();
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) _selected.remove(index);
      else _selected.add(index);
    });
    _resetGroupOverlayRect();
  }

  void _clearSelection() {
    setState(() => _selected.clear());
    _resetGroupOverlayRect();
  }

  // === grouping
  void _groupSelected() {
    if (_selected.length < 2) return;
    final gid = 'grp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      for (final i in _selected) {
        currentElements[i] = currentElements[i].copyWith(groupId: gid);
      }
    });
  }

  void _ungroupSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      for (final i in _selected) {
        currentElements[i] = currentElements[i].copyWith(groupId: null);
      }
      _selected.clear();
    });
  }

  // === copy/paste multi
  void _copySelection() {
    if (!_hasSelection) return;
    _clipboardList = _selected
        .map((i) => _deepCloneElement(currentElements[i]))
        .toList(growable: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _clipboardList!.length > 1
              ? 'Copied ${_clipboardList!.length} elements'
              : 'Copied',
        ),
      ),
    );
  }

  void _pasteSelection() {
    if (_clipboardList == null || _clipboardList!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final list = _clipboardList!;

    double minL = double.infinity, minT = double.infinity;
    for (final e in list) {
      minL = math.min(minL, e.offset.dx);
      minT = math.min(minT, e.offset.dy);
    }
    final base = _lastTapLocal ?? const Offset(32, 32);

    final newOnes = <PanelElementModel>[];
    for (final e in list) {
      final rel = e.offset - Offset(minL, minT);
      final pos = _clampOffset(base + rel, Size(e.width, e.height), widget.panelSize);
      newOnes.add(_deepCloneElement(e, offsetOverride: pos));
    }

    setState(() {
      for (final e in newOnes) {
        currentElements.add(e);
        elementKeys.add(GlobalKey<ResizableDraggableState>());
      }
      _selected
        ..clear();
      // reselect pasted ones
      for (int k = currentElements.length - newOnes.length; k < currentElements.length; k++) {
        _selected.add(k);
      }
    });
  }

  void _deleteSelection() {
    if (!_hasSelection) return;
    final toDelete = _selected.toList()..sort();
    setState(() {
      for (int n = toDelete.length - 1; n >= 0; n--) {
        final idx = toDelete[n];
        currentElements.removeAt(idx);
        elementKeys.removeAt(idx);
      }
      _selected.clear();
    });
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Panel'),
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
        actions: [
          // Toggle multi-select
         /* IconButton(
            tooltip: _multiSelectMode ? 'Exit Multi-select' : 'Multi-select',
            icon: Icon(_multiSelectMode ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: () {
              setState(() {
                _multiSelectMode = !_multiSelectMode;
                if (!_multiSelectMode && _selected.length > 1) {
                  // collapse to last tapped if needed
                  final keep = _selected.isNotEmpty ? _selected.last : null;
                  _selected.clear();
                  if (keep != null) _selected.add(keep);
                }
              });
            },
          ),*/

         /* // Group / Ungroup
          IconButton(
            tooltip: 'Group',
            icon: const Icon(Icons.merge_type),
            onPressed: _hasMultiSelection ? _groupSelected : null,
          ),
          IconButton(
            tooltip: 'Ungroup',
            icon: const Icon(Icons.call_split),
            onPressed: _hasSelection ? _ungroupSelected : null,
          ),*/

         /* // Copy / Paste now support multi
          IconButton(icon: const Icon(Icons.copy), onPressed: _copySelection),
          IconButton(icon: const Icon(Icons.content_paste), onPressed: _pasteSelection),
*/
          // Quick undo: remove last element (kept from yours)
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _isSaving
                ? null
                : () {
              if (currentElements.isNotEmpty && elementKeys.isNotEmpty) {
                setState(() {
                  currentElements.removeLast();
                  elementKeys.removeLast();
                  _clearSelection();
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

          _buildPanelOverflowMenu(),

        ],
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: w / h,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RepaintBoundary(
                          key: _panelContentKey,
                          child: Container(
                            color: _selectedBackgroundColor,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                if (_isEditing)
                                  CustomPaint(size: Size.infinite, painter: GridPainter()),
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
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ),

                                // === NEW: group overlay (shows only when multiple are selected)
                                if (_hasMultiSelection) _buildGroupOverlay(),
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

          // Floating toolbox for single selection only
          if (_singleSelectedIndex != null)
            _buildFloatingToolbox(currentElements[_singleSelectedIndex!]),
        ],
      ),
    );
  }

  /// Build each element with selection logic updated for multi-select / grouping
  Widget _buildElementWidget(PanelElementModel element, int index) {
    Widget child;

    switch (element.type) {
      case 'character':
      case 'clipart':
        child = SizedBox(
          width: element.width,
          height: element.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.asset(
                element.value,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: element.width,
                  height: element.height,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
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

      case 'speech_bubble': {
        final isSelected = _selected.contains(index);
        final img = _buildImageElement(element);
        final decorated = Container(
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: img,
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
              onTapDown: (d) => _lastTapLocal = d.localPosition,
              onTap: () {
                final el = currentElements[index];
                if (!_multiSelectMode && el.groupId != null) {
                  final gid = el.groupId;
                  final indices = <int>[];
                  for (int i = 0; i < currentElements.length; i++) {
                    if (currentElements[i].groupId == gid) indices.add(i);
                  }
                  setState(() {
                    _selected
                      ..clear()
                      ..addAll(indices);
                  });
                } else if (_multiSelectMode) {
                  _toggleSelect(index);
                } else {
                  _selectOnly(index);
                }
              },
              onDoubleTap: () => _editElement(index),
              child: decorated,
            ),
          );
        } else {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: img),
          );
        }
      }

      case 'image':
        child = SizedBox(
          width: element.width,
          height: element.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.file(
                File(element.value),
                errorBuilder: (context, error, stackTrace) => Container(
                  width: element.width,
                  height: element.height,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
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

        final isSelected = _selected.contains(index);
        final decoratedChild = Container(
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: drawingWidget,
        );

        if (_isEditing) {
          return ResizableDraggable(
            key: elementKeys[index],
            isSelected: isSelected,
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
              onTapDown: (d) => _lastTapLocal = d.localPosition,
              onTap: () {
                final el = currentElements[index];
                if (!_multiSelectMode && el.groupId != null) {
                  final gid = el.groupId;
                  final indices = <int>[];
                  for (int i = 0; i < currentElements.length; i++) {
                    if (currentElements[i].groupId == gid) indices.add(i);
                  }
                  setState(() {
                    _selected
                      ..clear()
                      ..addAll(indices);
                  });
                } else if (_multiSelectMode) {
                  _toggleSelect(index);
                } else {
                  _selectOnly(index);
                }
              },
              onDoubleTap: () => _editElement(index),
              child: decoratedChild,
            ),
          );
        } else {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: drawingWidget),
          );
        }

      default:
        child = Container(
          width: element.width,
          height: element.height,
          color: Colors.red.withOpacity(0.3),
          child: Center(
            child: Text('Unknown: ${element.type}', style: const TextStyle(fontSize: 12)),
          ),
        );
    }

    // Standard wrapper for other types (character/clipart/text/image default branch)
    final isSelected = _selected.contains(index);
    final elementSize = Size(
      element.width > 0 ? element.width : 50,
      element.height > 0 ? element.height : 50,
    );

    if (_isEditing) {
      return ResizableDraggable(
        key: elementKeys[index],
        isSelected: isSelected,
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
          onTapDown: (d) => _lastTapLocal = d.localPosition,
          onTap: () {
            final el = currentElements[index];
            if (!_multiSelectMode && el.groupId != null) {
              final gid = el.groupId;
              final indices = <int>[];
              for (int i = 0; i < currentElements.length; i++) {
                if (currentElements[i].groupId == gid) indices.add(i);
              }
              setState(() {
                _selected
                  ..clear()
                  ..addAll(indices);
              });
            } else if (_multiSelectMode) {
              _toggleSelect(index);
            } else {
              _selectOnly(index);
            }
          },
          onDoubleTap: () => _editElement(index),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.transparent,
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
        child: SizedBox(width: element.width, height: element.height, child: child),
      );
    }
  }

  // === Group overlay (a single ResizableDraggable controlling the selection)
  // === Group overlay (a single ResizableDraggable controlling the selection)
  Widget _buildGroupOverlay() {
    // Initialize overlay rect to current selection bounds
    final selRect = _selectionBounds();
    _lastGroupRect ??= selRect;

    return ResizableDraggable(
      key: _groupOverlayKey, // stable key keeps the same state instance
      isSelected: true,
      size: _lastGroupRect!.size,
      initialTop: _lastGroupRect!.top,
      initialLeft: _lastGroupRect!.left,
      minWidth: 10,
      minHeight: 10,
      onPositionChanged: (pos, size) {
        final Rect current = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

        // Move-only vs resize
        final bool movingOnly =
            (current.width  - _lastGroupRect!.width ).abs() < _kResizeEps &&
                (current.height - _lastGroupRect!.height).abs() < _kResizeEps;

        if (movingOnly) {
          // end any resize session
          if (_resizing) {
            _resizing = false;
            _resizeBaseRect = null;
            _resizeSnap = [];
          }

          final dx = current.left - _lastGroupRect!.left;
          final dy = current.top  - _lastGroupRect!.top;

          if (dx != 0 || dy != 0) {
            setState(() {
              final upd = List<PanelElementModel>.from(currentElements);
              for (final i in _selected) {
                final e = upd[i];
                final newPos = _clampOffset(
                  e.offset + Offset(dx, dy),
                  Size(e.width, e.height),
                  widget.panelSize,
                );
                upd[i] = e.copyWith(offset: newPos);

                // ⬅️ update the mounted draggable immediately
                elementKeys[i].currentState?.externalUpdatePosition(newPos);
              }
              currentElements = upd;
              _lastGroupRect = _lastGroupRect!.translate(dx, dy);
            });
          }
          return;
        }

        // RESIZE path
        if (!_resizing) {
          _resizing = true;
          _resizeBaseRect = _lastGroupRect; // baseline
          _resizeSnap = _selected.map((i) {
            final e = currentElements[i];
            return _Snap(i, e.offset, e.width, e.height);
          }).toList(growable: false);
        }

        final Rect base = _resizeBaseRect!;
        final double sx = (base.width  <= 0.0001) ? 1.0 : (current.width  / base.width);
        final double sy = (base.height <= 0.0001) ? 1.0 : (current.height / base.height);

        setState(() {
          final upd = List<PanelElementModel>.from(currentElements);
          for (final s in _resizeSnap) {
            final rel = s.offset - base.topLeft;
            final newLeft = current.left + rel.dx * sx;
            final newTop  = current.top  + rel.dy * sy;
            final newW = (s.w * sx).clamp(5.0, double.infinity);
            final newH = (s.h * sy).clamp(5.0, double.infinity);

            final unclampedPos = Offset(newLeft, newTop);
            final sz = Size(newW, newH);
            final clampedPos = _clampOffset(unclampedPos, sz, widget.panelSize);

            upd[s.index] = upd[s.index].copyWith(
              offset: clampedPos,
              width: sz.width,
              height: sz.height,
              size: sz,
            );

            // ⬅️ push visual update to the child draggable
            elementKeys[s.index].currentState?.externalUpdate(
              position: clampedPos,
              size: sz,
            );
          }
          currentElements = upd;
          _lastGroupRect = current;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
      ),
    );
  }


  /* Widget _buildGroupOverlay() {
    // Initialize overlay rect to current selection bounds
    final selRect = _selectionBounds();
    _lastGroupRect ??= selRect;

    return ResizableDraggable(
      key: _groupOverlayKey, // <-- stable key (don’t recreate every build)
      isSelected: true,
      size: _lastGroupRect!.size,
      initialTop: _lastGroupRect!.top,
      initialLeft: _lastGroupRect!.left,
      minWidth: 10,
      minHeight: 10,
      onPositionChanged: (pos, size) {
        final Rect current = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

        // Decide: move-only vs resize by comparing size change with small epsilon
        final bool movingOnly =
            (current.width  - _lastGroupRect!.width ).abs() < _kResizeEps &&
                (current.height - _lastGroupRect!.height).abs() < _kResizeEps;

        if (movingOnly) {
          // END any resize session
          if (_resizing) {
            _resizing = false;
            _resizeBaseRect = null;
            _resizeSnap = [];
          }

          // Pure translate by delta from last frame (no scaling)
          final dx = current.left - _lastGroupRect!.left;
          final dy = current.top  - _lastGroupRect!.top;

          if (dx != 0 || dy != 0) {
            setState(() {
              final upd = List<PanelElementModel>.from(currentElements);
              for (final i in _selected) {
                final e = upd[i];
                final newPos = _clampOffset(
                  e.offset + Offset(dx, dy),
                  Size(e.width, e.height),
                  widget.panelSize,
                );
                upd[i] = e.copyWith(offset: newPos);
              }
              currentElements = upd;
              _lastGroupRect = _lastGroupRect!.translate(dx, dy); // keep overlay in sync
            });
          }
          return;
        }

        // RESIZE path: start a session (baseline) at the moment we detect size change
        if (!_resizing) {
          _resizing = true;
          _resizeBaseRect = _lastGroupRect;               // baseline rect
          _resizeSnap = _selected.map((i) {
            final e = currentElements[i];
            return _Snap(i, e.offset, e.width, e.height);
          }).toList(growable: false);
        }

        // Scale from the baseline snapshot to the NEW current rect
        final Rect base = _resizeBaseRect!;
        final double sx = (base.width  <= 0.0001) ? 1.0 : (current.width  / base.width);
        final double sy = (base.height <= 0.0001) ? 1.0 : (current.height / base.height);

        setState(() {
          final upd = List<PanelElementModel>.from(currentElements);
          for (final s in _resizeSnap) {
            final rel = s.offset - base.topLeft;
            final newLeft = current.left + rel.dx * sx;
            final newTop  = current.top  + rel.dy * sy;
            final newW = (s.w * sx).clamp(5.0, double.infinity);
            final newH = (s.h * sy).clamp(5.0, double.infinity);
            upd[s.index] = upd[s.index].copyWith(
              offset: _clampOffset(Offset(newLeft, newTop), Size(newW, newH), widget.panelSize),
              width: newW,
              height: newH,
              size: Size(newW, newH),
            );
          }
          currentElements = upd;
          _lastGroupRect = current; // overlay follows the resized bounds
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
      ),
    );
  }*/
 /* void _resetGroupOverlayRect() {
    if (_hasMultiSelection) {
      final r = _selectionBounds();
      setState(() {
        _lastGroupRect = r;
        // clear any active resize session
        _resizing = false;
        _resizeBaseRect = null;
        _resizeSnap = [];
      });
    } else {
      setState(() {
        _lastGroupRect = null;
        _resizing = false;
        _resizeBaseRect = null;
        _resizeSnap = [];
      });
    }
  }*/
  void _resetGroupOverlayRect() {
    if (_hasMultiSelection) {
      final r = _selectionBounds();
      setState(() {
        _lastGroupRect = r;
        _resizing = false;
        _resizeBaseRect = null;
        _resizeSnap = [];
      });

      // push to the overlay's ResizableDraggable so it jumps to new bounds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _groupOverlayKey.currentState?.externalUpdate(
          position: r.topLeft,
          size: r.size,
        );
      });
    } else {
      setState(() {
        _lastGroupRect = null;
        _resizing = false;
        _resizeBaseRect = null;
        _resizeSnap = [];
      });
    }
  }




  Rect _selectionBounds() {
    double minL = double.infinity, minT = double.infinity;
    double maxR = -double.infinity, maxB = -double.infinity;
    for (final i in _selected) {
      final e = currentElements[i];
      minL = math.min(minL, e.offset.dx);
      minT = math.min(minT, e.offset.dy);
      maxR = math.max(maxR, e.offset.dx + e.width);
      maxB = math.max(maxB, e.offset.dy + e.height);
    }
    return Rect.fromLTRB(minL, minT, maxR, maxB);
  }

  void _transformSelection(Rect from, Rect to) {
    final double sx = (from.width <= 0.0001) ? 1.0 : (to.width / from.width);
    final double sy = (from.height <= 0.0001) ? 1.0 : (to.height / from.height);

    final upd = List<PanelElementModel>.from(currentElements);
    for (final i in _selected) {
      final e = upd[i];
      // position relative to group top-left (before transform)
      final rel = e.offset - Offset(from.left, from.top);

      final newLeft = to.left + rel.dx * sx;
      final newTop  = to.top  + rel.dy * sy;

      final newW = (e.width  * sx).clamp(5.0, double.infinity);
      final newH = (e.height * sy).clamp(5.0, double.infinity);

      upd[i] = e.copyWith(
        offset: _clampOffset(Offset(newLeft, newTop), Size(newW, newH), widget.panelSize),
        width: newW,
        height: newH,
        size: Size(newW, newH),
      );
    }

    setState(() {
      currentElements = upd;
    });
  }

  // ======= Your existing toolbox / dialogs / save etc. (mostly unchanged) =======

  Widget _buildFloatingToolbox(PanelElementModel element) {
    // show only for single selection
    if (_singleSelectedIndex == null) return const SizedBox.shrink();

    List<Widget> toolIcons = [];
    switch (element.type) {
      case 'text':
        toolIcons = [
          _toolIcon(id: 'color', icon: Icons.format_color_text, tooltip: 'Text Color',
              onTap: () => _changeTextColorById(element.id)),
          _toolIcon(id: 'size', icon: Icons.format_size, tooltip: 'Font Size',
              onTap: () => _changeFontSizeById(element.id)),
          _toolIcon(id: 'bold', icon: Icons.format_bold, tooltip: 'Bold',
              onTap: () => _toggleBoldById(element.id)),
          _toolIcon(id: 'italic', icon: Icons.format_italic, tooltip: 'Italic',
              onTap: () => _toggleItalicById(element.id)),
          _toolIcon(id: 'delete', icon: Icons.delete, tooltip: 'Delete',
              onTap: () => _deleteElementById(element.id)),
        ];
        break;

      case 'image':
        toolIcons = [
          _toolIcon(id: 'replace', icon: Icons.image_search, tooltip: 'Replace Image',
              onTap: () => _replaceImageById(element.id)),
          _toolIcon(id: 'delete', icon: Icons.delete, tooltip: 'Delete',
              onTap: () => _deleteElementById(element.id)),
        ];
        break;

      default:
        return const SizedBox.shrink();
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
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: toolIcons),
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
        icon: Icon(icon, color: isActive ? Colors.blue : Colors.black),
        tooltip: tooltip,
        onPressed: () {
          setState(() => _activeToolId = id);
          onTap();
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
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    Color sel = currentElements[index].color ?? Colors.black;

    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick Text Color"),
        content: MaterialPicker(pickerColor: sel, onColorChanged: (c) => sel = c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, sel), child: const Text("OK")),
        ],
      ),
    );
    if (pickedColor != null) {
      setState(() {
        currentElements[index] = currentElements[index].copyWith(color: pickedColor);
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
              builder: (context, setState) => Slider(
                min: 8,
                max: 72,
                divisions: 64,
                value: tempSize,
                label: tempSize.toStringAsFixed(0),
                onChanged: (v) => setState(() => tempSize = v),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, tempSize), child: const Text("OK")),
          ],
        );
      },
    );

    if (newSize != null) {
      setState(() {
        currentElements[index] = currentElements[index].copyWith(fontSize: newSize);
      });
    }
  }

  void _toggleBoldById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    setState(() {
      final w = currentElements[index].fontWeight;
      currentElements[index] =
          currentElements[index].copyWith(fontWeight: (w == FontWeight.bold ? FontWeight.normal : FontWeight.bold));
    });
  }

  void _toggleItalicById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    setState(() {
      final s = currentElements[index].fontStyle;
      currentElements[index] =
          currentElements[index].copyWith(fontStyle: (s == FontStyle.italic ? FontStyle.normal : FontStyle.italic));
    });
  }

  void _replaceImageById(String id) async {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        currentElements[index] = currentElements[index].copyWith(value: pickedFile.path);
      });
    }
  }

  void _deleteElementById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    setState(() {
      currentElements.removeAt(index);
      elementKeys.removeAt(index);
      _selected.remove(index);
    });
  }

  Future<void> _editSpeechBubble(int index) async {
    final element = currentElements[index];
    final initialData = _extractBubbleInitialData(element);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DragSpeechBubbleEditDialog(initialData: initialData),
    );
    if (result == null) return;

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
      tailNorm: Offset(
        (result['tailNorm']['dx'] as num).toDouble(),
        (result['tailNorm']['dy'] as num).toDouble(),
      ),
    );

    final Uint8List pngBytes = result['pngBytes'] as Uint8List;
    final double newW = (result['width'] as num).toDouble();
    final double newH = (result['height'] as num).toDouble();

    setState(() {
      currentElements[index] = element.copyWith(
        value: base64Encode(pngBytes),
        width: newW,
        height: newH,
        size: Size(newW, newH),
        offset: element.offset,
        color: updatedBubble.bubbleColor,
        fontSize: updatedBubble.fontSize,
        fontFamily: updatedBubble.fontFamily,
        fontWeight: updatedBubble.fontWeight,
        fontStyle: updatedBubble.fontStyle,
        meta: jsonEncode({
          'kind': 'speech_bubble_original',
          'data': updatedBubble.toMap(),
        }),
      );
    });
  }

  Map<String, dynamic> _extractBubbleInitialData(PanelElementModel element) {
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
      'width': element.width,
      'height': element.height,
    };

    try {
      if (element.meta == null || element.meta!.isEmpty) return fallback;
      final metaObj = jsonDecode(element.meta!);
      if (metaObj is! Map) return fallback;

      if (metaObj['kind'] == 'speech_bubble_original' && metaObj['data'] != null) {
        final dataMap = Map<String, dynamic>.from(metaObj['data'] as Map);
        return {
          'text': dataMap['text'],
          'bubbleColor': _readColor(dataMap['bubbleColor'], fallback['bubbleColor']),
          'borderColor': _readColor(dataMap['borderColor'], fallback['borderColor']),
          'borderWidth': (dataMap['borderWidth'] as num?)?.toDouble() ?? fallback['borderWidth'],
          'bubbleShape': _readBubbleShape(dataMap['bubbleShape']) ?? fallback['bubbleShape'],
          'tailOffset': _readOffset(dataMap['tailOffset']) ?? fallback['tailOffset'],
          'tailNorm': _readTailNorm(dataMap['tailNorm']) ?? fallback['tailNorm'],
          'fontSize': (dataMap['fontSize'] as num?)?.toDouble() ?? fallback['fontSize'],
          'textColor': _readColor(dataMap['textColor'], fallback['textColor']),
          'fontFamily': dataMap['fontFamily'] ?? fallback['fontFamily'],
          'fontWeight': _readFontWeight(dataMap['fontWeight']) ?? fallback['fontWeight'],
          'fontStyle': _readFontStyle(dataMap['fontStyle']) ?? fallback['fontStyle'],
          'padding': (dataMap['padding'] as num?)?.toDouble() ?? fallback['padding'],
          'width': element.width,
          'height': element.height,
        };
      }
    } catch (_) {}
    return fallback;
  }

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
      switch (v) {
        case 'rectangle': return DragBubbleShape.rectangle;
        case 'shout': return DragBubbleShape.shout;
      }
    }
    return null;
  }

  FontWeight? _readFontWeight(dynamic v) {
    if (v is FontWeight) return v;
    if (v is String) {
      switch (v) {
        case 'w100': return FontWeight.w100;
        case 'w200': return FontWeight.w200;
        case 'w300': return FontWeight.w300;
        case 'w400': return FontWeight.w400;
        case 'w500': return FontWeight.w500;
        case 'w600': return FontWeight.w600;
        case 'w700': return FontWeight.w700;
        case 'w800': return FontWeight.w800;
        case 'w900': return FontWeight.w900;
        case 'normal': return FontWeight.normal;
        case 'bold': return FontWeight.bold;
      }
    }
    return null;
  }

  FontStyle? _readFontStyle(dynamic v) {
    if (v is FontStyle) return v;
    if (v is String) {
      switch (v) {
        case 'normal': return FontStyle.normal;
        case 'italic': return FontStyle.italic;
      }
    }
    return null;
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
        break;
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

  void _addNewElement(PanelElementModel element) {
    setState(() {
      currentElements.add(element);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
      // optional: auto-select the new element
      _selected
        ..clear()
        ..add(currentElements.length - 1);
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
      value: base64Encode(bytes),
      offset: const Offset(50, 50),
      width: width,
      height: height,
      size: Size(width, height),
      meta: jsonEncode({'kind': 'speech_bubble_original', 'data': bubbleData.toMap()}),
    );

    _addNewElement(newElement);
  }

  Future<Uint8List?> _capturePanelAsImage() async {
    try {
      RenderRepaintBoundary boundary =
      _panelContentKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing panel image: $e');
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolNavButton(Icons.format_color_fill, 'BG', _pickBackgroundColor),
                _toolNavButton(Icons.image, 'Image', _uploadImage),
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
                _toolNavButton(Icons.chat_bubble, 'Speech Bubble', _addSpeechBubble),
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
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
            onToolChanged: (tool) => setState(() => currentTool = tool),
            onColorChanged: (color) => setState(() => drawSelectedColor = color),
            onBrushSizeChanged: (size) => setState(() => selectedBrushSize = size),
            onUndo: () {},
            onClearAll: () {},
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _pickBackgroundColor() async {
    Color tempColor = _selectedBackgroundColor;
    Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick Background Color"),
        content: SingleChildScrollView(
          child: MaterialPicker(
            pickerColor: tempColor,
            onColorChanged: (color) => tempColor = color,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(tempColor), child: const Text("Select")),
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

  void _addCharacterAsset(String assetPath) {
    final el = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'character',
      value: assetPath,
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

  void _onDrawingComplete(List<Offset> points) {
    final nonZeroPoints = points.where((p) => p != Offset.zero).toList();
    if (nonZeroPoints.isEmpty) {
      setState(() => isDrawing = false);
      return;
    }

    final minX = nonZeroPoints.map((p) => p.dx).reduce(math.min);
    final minY = nonZeroPoints.map((p) => p.dy).reduce(math.min);
    final maxX = nonZeroPoints.map((p) => p.dx).reduce(math.max);
    final maxY = nonZeroPoints.map((p) => p.dy).reduce(math.max);

    final boundingWidth = (maxX - minX).clamp(10.0, double.infinity);
    final boundingHeight = (maxY - minY).clamp(10.0, double.infinity);

    final normalizedPoints = points.map((p) => p - Offset(minX, minY)).toList();
    final drawingData = normalizedPoints.map((e) => '${e.dx},${e.dy}').join(';');

    final newElement = PanelElementModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'Draw',
      value: drawingData,
      offset: Offset(minX, minY),
      width: boundingWidth,
      height: boundingHeight,
      size: Size(boundingWidth, boundingHeight),
      color: drawSelectedColor,
      fontSize: selectedBrushSize,
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

  Offset _clampOffset(Offset desired, Size elSize, Size canvas) {
    final dx = desired.dx.clamp(0.0, (canvas.width - elSize.width).clamp(0.0, double.infinity));
    final dy = desired.dy.clamp(0.0, (canvas.height - elSize.height).clamp(0.0, double.infinity));
    return Offset(dx, dy);
  }

  PanelElementModel _deepCloneElement(PanelElementModel e, {Offset? offsetOverride}) {
    final cloned = e.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      offset: offsetOverride ?? (e.offset + const Offset(12, 12)),
      size: Size(e.width, e.height),
      width: e.width,
      height: e.height,
      value: e.value,
      meta: e.meta,
      color: e.color,
      fontSize: e.fontSize,
      fontFamily: e.fontFamily,
      fontWeight: e.fontWeight,
      fontStyle: e.fontStyle,
      groupId: e.groupId, // keep group if you want; or null to paste ungrouped
    );
    return cloned;
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
          const SnackBar(content: Text('Panel saved successfully!'), duration: Duration(seconds: 1)),
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context, updatedPanel);
      }
    } catch (e) {
      debugPrint('Error saving panel: $e');
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

  Widget _buildPanelOverflowMenu() {
    final String multiLabel =
    _multiSelectMode ? 'Exit Multi-select' : 'Multi-select';

    return PopupMenuButton<_PanelMenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.menu),
      onSelected: _onPanelMenuSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      itemBuilder: (context) => [
        // Multi-select toggle with a checkmark
        CheckedPopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.toggleMultiSelect,
          checked: _multiSelectMode,
          child: _menuRow(
            _multiSelectMode ? Icons.check_box : Icons.check_box_outline_blank,
            multiLabel,
          ),
        ),
        // Group / Ungroup (disabled as needed)
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.group,
          enabled: _hasMultiSelection,
          child: _menuRow(Icons.merge_type, 'Group'),
        ),
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.ungroup,
          enabled: _hasSelection,
          child: _menuRow(Icons.call_split, 'Ungroup'),
        ),
        const PopupMenuDivider(),
        // Copy / Paste
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.copy,
          enabled: _hasSelection,
          child: _menuRow(Icons.copy, 'Copy'),
        ),
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.paste,
          enabled: _canPaste,
          child: _menuRow(Icons.content_paste, 'Paste'),
        ),
        // Delete selection (single or multiple)
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.delete,
          enabled: _canPaste,
          child: _menuRow(Icons.delete, 'Delete'),
        ),
      ],
    );
  }

  void _onPanelMenuSelected(_PanelMenuAction action) {
    switch (action) {
      case _PanelMenuAction.toggleMultiSelect:
        setState(() {
          _multiSelectMode = !_multiSelectMode;
          if (!_multiSelectMode && _selected.length > 1) {
            final keep = _selected.isNotEmpty ? _selected.last : null;
            _selected.clear();
            if (keep != null) _selected.add(keep);
          }
        });
        break;

      case _PanelMenuAction.group:
        if (_hasMultiSelection) _groupSelected();
        break;

      case _PanelMenuAction.ungroup:
        if (_hasSelection) _ungroupSelected();
        break;

      case _PanelMenuAction.copy:
        if (_hasSelection) _copySelection();
        break;

      case _PanelMenuAction.paste:
        _pasteSelection();
        break;
        case _PanelMenuAction.delete:
        if (_hasSelection) _deleteSelection();
        break;
    }
  }

// Small helper to render icon + label in menu
  Widget _menuRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }}


/*class PanelEditScreen extends StatefulWidget {
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

  // --- Clipboard & focus ---
  PanelElementModel? _clipboard;
  Offset? _lastTapLocal; // where the user clicked last on the canvas
  final FocusNode _focusNode = FocusNode();


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

          IconButton(icon: const Icon(Icons.copy), onPressed: _copySelected),
          IconButton(icon: const Icon(Icons.content_paste), onPressed: _pasteElement),
          
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
*//*
              Expanded(
                child: Center(
                  // ensures it's centered if there's padding/margin
                  child: AspectRatio(
*//*
*//*
                    aspectRatio: aspectRatio,
*//* *//*

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
*//*
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
*//*      case 'character':
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
        }*//*

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

      *//* case 'speech_bubble':
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
        }*//*

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
          *//*_toolIcon(
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
          ),*//*
          *//*   _toolIcon(
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
          ),*//*
          *//* _toolIcon(
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
          ),*//*
          *//* _toolIcon(
            id: 'crop',
            icon: Icons.crop,
            tooltip: 'Crop Image',
            onTap: () => _cropImageById(element.id),
          ),*//*
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


*//*
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
*//*

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

*//*
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
*//*

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

*//*  void _addSpeechBubble() async {
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
  }*//*

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
                *//* _toolNavButton(Icons.face, 'Character', () async {
                  final selected = await showCharacterPicker(context);
                  if (selected != null) {
                    _addCharacterAsset(selected); // You will implement this
                  }
                }),*//*

*//*
                _toolNavButton(Icons.insert_emoticon, 'Clipart', () async {
                  final result = await showCharacterAndClipartPicker(context);
                  if (result != null && result['type'] == 'character') {
                    _addCharacterEmoji(result['value']);
                  }
                }),*//*
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

*//*  void _addCharacterAsset(String imagePath) {
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
  }*//*

  *//*void _addClipArt(IconData selectedIcon) {
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
  }*//*
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

*//*  Future<Map<String, dynamic>?> showCharacterAndClipartPicker(
      BuildContext context) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return CharacterClipartPickerDialog();
      },
    );
  }*//*
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

  void _copySelected() {
    if (selectedElementIndex == null) return;
    _clipboard = _deepCloneElement(currentElements[selectedElementIndex!]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  void _cutSelected() {
    if (selectedElementIndex == null) return;
    _clipboard = _deepCloneElement(currentElements[selectedElementIndex!]);
    _deleteSelected();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cut')),
    );
  }

  void _pasteElement() {
    if (_clipboard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final src = _clipboard!;
    final Offset base = _lastTapLocal ?? src.offset + const Offset(16, 16);
    final Size canvas = widget.panelSize;

    final pasted = _deepCloneElement(
      src,
      offsetOverride: _clampOffset(base, Size(src.width, src.height), canvas),
    );

    setState(() {
      currentElements.add(pasted);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
      selectedElementIndex = currentElements.length - 1;
    });
  }

  void _duplicateSelected() {
    if (selectedElementIndex == null) return;
    // duplicate relative to the original with a slight offset
    _clipboard = _deepCloneElement(currentElements[selectedElementIndex!]);
    _lastTapLocal = currentElements[selectedElementIndex!].offset + const Offset(20, 20);
    _pasteElement();
  }

  void _deleteSelected() {
    if (selectedElementIndex == null) return;
    final idx = selectedElementIndex!;
    setState(() {
      currentElements.removeAt(idx);
      elementKeys.removeAt(idx);
      selectedElementIndex = null;
    });
  }

  // Ensure the element stays inside panel bounds
  Offset _clampOffset(Offset desired, Size elSize, Size canvas) {
    final dx = desired.dx.clamp(0.0, (canvas.width - elSize.width).clamp(0.0, double.infinity));
    final dy = desired.dy.clamp(0.0, (canvas.height - elSize.height).clamp(0.0, double.infinity));
    return Offset(dx, dy);
  }

// Deep-ish clone with a fresh id; keep meta/value etc.
  PanelElementModel _deepCloneElement(PanelElementModel e, {Offset? offsetOverride}) {
    final cloned = e.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      offset: offsetOverride ?? (e.offset + const Offset(12, 12)),
      // keep everything else the same:
      size: Size(e.width, e.height),
      width: e.width,
      height: e.height,
      // keep style bits & meta (important for speech_bubble re-edit)
      value: e.value,
      meta: e.meta,
      color: e.color,
      fontSize: e.fontSize,
      fontFamily: e.fontFamily,
      fontWeight: e.fontWeight,
      fontStyle: e.fontStyle,
    );
    return cloned;
  }


}*/
