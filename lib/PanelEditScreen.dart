import 'dart:async';
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
import 'SpeechDrag/SpeechBubbleEditorScreen.dart';
import 'TextEditorDialog/TextEditDialog.dart';

import 'dart:math' as math;

// Menu actions
enum _PanelMenuAction { toggleMultiSelect, group, ungroup, copy, paste, delete, undo ,redo}

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

  // NEW: optional autosave notify
  final ValueChanged<ComicPanel>? onAutosave;

  const PanelEditScreen({
    super.key,
    required this.panel,
    required this.panelOffset,
    required this.panelSize,
    this.onAutosave,
  });

  @override
  _PanelEditScreenState createState() => _PanelEditScreenState();
}

class _PanelEditScreenState extends State<PanelEditScreen> {

  int selectedIndex = -1;
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

  // Add this state field at the top of _PanelEditScreenState

  final GlobalKey _panelContentKey = GlobalKey();
  double aspectRatio = 3 / 4;

  // === NEW: multi-select & grouping ===
  final Set<int> _selected = {}; // indices into currentElements
  bool _multiSelectMode = false;
  Rect? _lastGroupRect; // last overlay rect during drag
  List<PanelElementModel>? _clipboardList; // multi-copy clipboard

  // Clipboard & focus you already had
  PanelElementModel? _clipboard; // kept if you use elsewhere
  Offset? _lastTapLocal;
  final FocusNode _focusNode = FocusNode();

  // === Convenience getters for single vs multi selection
  bool get _hasSelection => _selected.isNotEmpty;

  bool get _hasMultiSelection => _selected.length > 1;

  int? get _singleSelectedIndex =>
      _selected.length == 1 ? _selected.first : null;

  // === Group overlay control ===
  final GlobalKey<ResizableDraggableState> _groupOverlayKey =
      GlobalKey<ResizableDraggableState>();

  static const double _kResizeEps =
      0.75; // px threshold to ignore tiny size jitter

// Resize session (baseline snapshot so we don't accumulate error)
  Rect? _resizeBaseRect;
  bool _resizing = false;

  List<_Snap> _resizeSnap = [];

  // ===== Layer panel (visibility/lock/reorder) =====
  bool _showLayerPanel = false;
  final Map<String, bool> _hiddenById = {}; // id -> hidden?
  final Map<String, bool> _lockedById = {}; // id -> locked?

  bool _isHiddenIdx(int i) => _hiddenById[currentElements[i].id] ?? false;

  bool _isLockedIdx(int i) => _lockedById[currentElements[i].id] ?? false;


  // ===== Unlocked selection

  Iterable<int> get _selectedUnlocked =>
      _selected.where((i) => !_isLockedIdx(i));

  bool get _hasUnlockedSelection => _selectedUnlocked.isNotEmpty;
  bool get _hasMultiUnlocked => _selectedUnlocked.length > 1;
  // ===== Unlocked selection



  // ——— Save/Progress state ———
  String _saveStatus = 'Saved';
  double? _saveProgress;              // null when idle, 0..1 while saving
  Timer? _autosaveDebounce;
  int _saveGen = 0;

  // ——— Save/Progress state ———


  final List<PanelElementModel> _redoStack = []; // holds items removed by Undo


  // ==== NEW: layer locked, hidden handling
// inside _PanelEditScreenState:
  Map<String, dynamic> _safeMetaMap(String? meta) {
    if (meta == null || meta.isEmpty) return {};
    try {
      final m = jsonDecode(meta);
      if (m is Map<String, dynamic>) return m;
    } catch (_) {}
    return {};
  }

  bool _metaGetHidden(Map<String, dynamic> m) {
    final flags = m['flags'];
    if (flags is Map) {
      final v = flags['hidden'];
      if (v is bool) return v;
    }
    final top = m['hidden'];
    if (top is bool) return top;
    return false;
  }

  String _metaSetHidden(Map<String, dynamic> m, bool hidden) {
    final flags = Map<String, dynamic>.from(m['flags'] as Map? ?? {});
    flags['hidden'] = hidden;
    m['flags'] = flags;
    return jsonEncode(m);
  }

  bool _readHiddenFlag(PanelElementModel e) {
    return _metaGetHidden(_safeMetaMap(e.meta));
  }

  PanelElementModel _withHiddenFlag(PanelElementModel e, bool hidden) {
    final map = _safeMetaMap(e.meta);
    final metaStr = _metaSetHidden(map, hidden);
    return e.copyWith(meta: metaStr);
  }
  // ==== NEW: layer locked , hidden handling

// === Right inspector (draggable/collapsible) ===
  double _inspectorTop = 0;            // y-offset from top
  double _inspectorHeight = 420;       // expanded height
  bool _inspectorCollapsed = false;    // collapsed to header

  double? _inspectorDragStartDy;       // for vertical drag
  double? _inspectorStartTop;

  double? _resizeDragStartDy;          // for bottom-edge resize
  double? _inspectorStartHeight;

  static const double _kInspectorWidth = 300;
  static const double _kInspectorHeaderH = 44; // header height when collapsed


 /* @override
  void initState() {
    super.initState();
    panel = widget.panel;
    currentElements = List.from(panel.elements);
    _selectedBackgroundColor = panel.backgroundColor;
    _initializeElements();
  }*/

  @override
  void initState() {
    super.initState();
    panel = widget.panel;
    currentElements = List.from(panel.elements);
    _selectedBackgroundColor = panel.backgroundColor;
    _initializeElements();

    // position the inspector under the app bar on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safeTop = kToolbarHeight + MediaQuery.of(context).padding.top + 8;
      setState(() => _inspectorTop = safeTop);
    });
  }


  void _initializeElements() {
    elementKeys.clear();
    for (final e in currentElements) {
      elementKeys.add(GlobalKey<ResizableDraggableState>());
      _lockedById.putIfAbsent(e.id, () => false);
      _hiddenById.putIfAbsent(e.id, () => _readHiddenFlag(e)); // <-- was false


    }
  }

  // === selection helpers
  void _selectOnly(int index) {
    setState(() {
      _selected
        ..clear()
        ..add(index);
    });
    _resetGroupOverlayRect();
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index))
        _selected.remove(index);
      else
        _selected.add(index);
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
  /*void _copySelection() {
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
  }*/
  void _copySelection() {
    final sel = _selectedUnlocked.toList();
    if (sel.isEmpty) return;
    _clipboardList =
        sel.map((i) => _deepCloneElement(currentElements[i])).toList(growable: false);

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
      final pos =
          _clampOffset(base + rel, Size(e.width, e.height), widget.panelSize);
      newOnes.add(_deepCloneElement(e, offsetOverride: pos));
    }

    setState(() {
      for (final e in newOnes) {
        currentElements.add(e);
        elementKeys.add(GlobalKey<ResizableDraggableState>());
      }
      _selected..clear();
      // reselect pasted ones
      for (int k = currentElements.length - newOnes.length;
          k < currentElements.length;
          k++) {
        _selected.add(k);
      }
    });
  }

/*  void _deleteSelection() {
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
  }*/
  void _deleteSelection() {
    if (!_hasUnlockedSelection) return;
    final toDelete = _selectedUnlocked.toList()..sort();
    setState(() {
      for (int n = toDelete.length - 1; n >= 0; n--) {
        final idx = toDelete[n];
        currentElements.removeAt(idx);
        elementKeys.removeAt(idx);
      }
      _selected.clear();
    });
  }


  bool _pointHitsAnyElement(Offset p) {
    // check topmost first (last drawn wins)
    for (int i = currentElements.length - 1; i >= 0; i--) {
      if (_isHiddenIdx(i)) continue;
      final e = currentElements[i];
      final rect = Rect.fromLTWH(e.offset.dx, e.offset.dy, e.width, e.height);
      if (rect.contains(p)) return true;
    }
    return false;
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;


    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade400,
          foregroundColor: Colors.white,
          // ↓ minimize the gap between back arrow and title
          titleSpacing: 10,            // default is 16
          leadingWidth: 40,           // shrink the leading area (optional)

          title: const Text('Edit', overflow: TextOverflow.ellipsis),

          bottom: _saveProgress != null
              ? PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(value: _saveProgress),
          )
              : null,
          actions: [
            IconButton(
              tooltip: _showLayerPanel ? 'Hide Layers' : 'Layers',
              icon: Icon(Icons.layers,
                  color: _showLayerPanel ? Colors.amberAccent : Colors.white),
              onPressed: () => setState(() => _showLayerPanel = !_showLayerPanel),
            ),

           /* ElevatedButton(
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
            ),*/

            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: SaveStatusPill(status: _saveStatus, progress: _saveProgress),
              ),
            ),
            const SizedBox(width: 5),
            _buildPanelOverflowMenu(),
          ],
        ),

        // NEW: wrap the whole body so we can clear selection on any screen tap
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            // Locate the canvas (the RepaintBoundary content)
            final box = _panelContentKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;

            final canvasRect = box.localToGlobal(Offset.zero) & box.size;

            // Only clear when tap is inside the canvas and not on an element
            if (canvasRect.contains(details.globalPosition)) {
              final local = box.globalToLocal(details.globalPosition);
              _lastTapLocal = local; // keep for paste
              if (!isDrawing && !_pointHitsAnyElement(local)) {
                if (_selected.isNotEmpty) {
                  setState(() {
                    _selected.clear();
                    _resetGroupOverlayRect();
                  });
                }
              }
            }
          },

          child: Stack(
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
                                    if (_hasMultiUnlocked) _buildGroupOverlay(),
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

              if (_showLayerPanel) _buildLayerEditorPanel(),
            ],
          ),
        ),
      ),
    );
  }


  Future<bool> _onWillPop() async {
    final updated = <PanelElementModel>[];
    for (int i = 0; i < currentElements.length; i++) {
      final st = elementKeys[i].currentState;
      if (st != null) {
        updated.add(currentElements[i].copyWith(
          offset: st.position,
          size: st.size,
          width: st.size.width,
          height: st.size.height,
        ));
      } else {
        updated.add(currentElements[i]);
      }
    }

    var updatedPanel = panel.copyWith(
      elements: updated,
      backgroundColor: _selectedBackgroundColor,
    );

    // optional: quick preview refresh
    try {
      final img = await _capturePanelAsImage();
      updatedPanel = updatedPanel.copyWith(previewImage: img);
    } catch (_) {}

    widget.onAutosave?.call(updatedPanel);      // notify parent
    await _performAutosave();
    Navigator.pop(context, updatedPanel);       // return updated panel
    return false; // prevent default pop (we already popped)
  }

  // Helper to keep keys list in sync and avoid RangeError
  GlobalKey<ResizableDraggableState> _ensureKeyFor(int i) {
    if (i < elementKeys.length) return elementKeys[i];
    final k = GlobalKey<ResizableDraggableState>();
    elementKeys.add(k);
    return k;
  }

  Widget _buildElementWidget(PanelElementModel element, int index) {
    if (_isHiddenIdx(index)) return const SizedBox.shrink();

    // ------- build inner child by type -------
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

        if (!_isEditing) {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: img),
          );
        }

        final locked = _isLockedIdx(index);
        if (locked) {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: decorated),
          );
        }

        // Interactive with delete
        final key = _ensureKeyFor(index);
        return ResizableDraggable(
          key: key,
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
            _redoStack.clear();   // ← break redo chain on fresh edits

            _queueAutosave();

          },
          onDelete: () => _deleteElementById(element.id), // <<< NEW
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
                  _selected..clear()..addAll(indices);
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

      case 'Draw': {
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

        if (!_isEditing) {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: drawingWidget),
          );
        }

        final locked = _isLockedIdx(index);
        if (locked) {
          return Positioned(
            top: element.offset.dy,
            left: element.offset.dx,
            child: SizedBox(width: element.width, height: element.height, child: decoratedChild),
          );
        }

        final key = _ensureKeyFor(index);
        return ResizableDraggable(
          key: key,
          isSelected: isSelected,
          size: Size(element.width, element.height),
          initialTop: element.offset.dy,
          initialLeft: element.offset.dx,
          onPositionChanged: (position, size) {
            if (!mounted) return;
            setState(() {
              currentElements[index] = currentElements[index].copyWith(
                offset: position,
                size: size,
                width: size.width,
                height: size.height,
              );
            });
            _redoStack.clear();   // ← break redo chain on fresh edits

            _queueAutosave();

          },
          onDelete: () => _deleteElementById(element.id), // <<< NEW
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
                  _selected..clear()..addAll(indices);
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

    // ------- standard wrapper for character/clipart/text/image -------
    final isSelected = _selected.contains(index);
    final elementSize = Size(
      element.width > 0 ? element.width : 50,
      element.height > 0 ? element.height : 50,
    );

    if (!_isEditing) {
      return Positioned(
        top: element.offset.dy,
        left: element.offset.dx,
        child: SizedBox(width: element.width, height: element.height, child: child),
      );
    }

    final locked = _isLockedIdx(index);
    if (locked) {
      return Positioned(
        top: element.offset.dy,
        left: element.offset.dx,
        child: SizedBox(
          width: elementSize.width,
          height: elementSize.height,
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
    }

    // Interactive + delete
    final key = _ensureKeyFor(index);
    return ResizableDraggable(
      key: key,
      isSelected: isSelected,
      size: elementSize,
      initialTop: element.offset.dy,
      initialLeft: element.offset.dx,
      onPositionChanged: (position, size) {
        if (!mounted) return;
        setState(() {
          currentElements[index] = currentElements[index].copyWith(
            offset: position,
            size: size,
            width: size.width,
            height: size.height,
          );
        });
        _redoStack.clear();   // ← break redo chain on fresh edits
        _queueAutosave();
      },
      onDelete: () => _deleteElementById(element.id), // <<< NEW
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
              _selected..clear()..addAll(indices);
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
  }


  // === Group overlay (a single ResizableDraggable controlling the selection)
  Widget _buildGroupOverlay() {
    // Initialize overlay rect to current selection bounds
    final selRect = _selectionBounds();
    _lastGroupRect ??= selRect;

    return ResizableDraggable(
      key: _groupOverlayKey,
      // stable key keeps the same state instance
      isSelected: true,
      size: _lastGroupRect!.size,
      initialTop: _lastGroupRect!.top,
      initialLeft: _lastGroupRect!.left,
      minWidth: 10,
      minHeight: 10,
      onPositionChanged: (pos, size) {
        final Rect current =
            Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

        // Move-only vs resize
        final bool movingOnly =
            (current.width - _lastGroupRect!.width).abs() < _kResizeEps &&
                (current.height - _lastGroupRect!.height).abs() < _kResizeEps;

        if (movingOnly) {
          // end any resize session
          if (_resizing) {
            _resizing = false;
            _resizeBaseRect = null;
            _resizeSnap = [];
          }

          final dx = current.left - _lastGroupRect!.left;
          final dy = current.top - _lastGroupRect!.top;

          if (dx != 0 || dy != 0) {
            setState(() {
              final upd = List<PanelElementModel>.from(currentElements);
              for (final i in _selectedUnlocked) {
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
          _resizeSnap = _selectedUnlocked.map((i) {
            final e = currentElements[i];
            return _Snap(i, e.offset, e.width, e.height);
          }).toList(growable: false);
        }

        final Rect base = _resizeBaseRect!;
        final double sx =
            (base.width <= 0.0001) ? 1.0 : (current.width / base.width);
        final double sy =
            (base.height <= 0.0001) ? 1.0 : (current.height / base.height);

        setState(() {
          final upd = List<PanelElementModel>.from(currentElements);
          for (final s in _resizeSnap) {
            final rel = s.offset - base.topLeft;
            final newLeft = current.left + rel.dx * sx;
            final newTop = current.top + rel.dy * sy;
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
  void _resetGroupOverlayRect() {
    if (_hasMultiUnlocked) {
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
    final items = _selectedUnlocked.toList();
    if (items.isEmpty) return const Rect.fromLTWH(0, 0, 0, 0);
    double minL = double.infinity, minT = double.infinity;
    double maxR = -double.infinity, maxB = -double.infinity;
    for (final i in items) {
      final e = currentElements[i];
      minL = math.min(minL, e.offset.dx);
      minT = math.min(minT, e.offset.dy);
      maxR = math.max(maxR, e.offset.dx + e.width);
      maxB = math.max(maxB, e.offset.dy + e.height);
    }
    return Rect.fromLTRB(minL, minT, maxR, maxB);
  }

  // ======= Your existing toolbox / dialogs / save etc. (mostly unchanged) =======

  Widget _buildFloatingToolbox(PanelElementModel element) {
    // show only for single selection
    if (_singleSelectedIndex == null) return const SizedBox.shrink();
    if (_isLockedIdx(_singleSelectedIndex!)) return const SizedBox.shrink(); // add this

    List<Widget> toolIcons = [];
    switch (element.type) {
      case 'text':
        toolIcons = [
          _toolIcon(
              id: 'color',
              icon: Icons.format_color_text,
              tooltip: 'Text Color',
              onTap: () => _changeTextColorById(element.id)),
          _toolIcon(
              id: 'size',
              icon: Icons.format_size,
              tooltip: 'Font Size',
              onTap: () => _changeFontSizeById(element.id)),
          _toolIcon(
              id: 'bold',
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onTap: () => _toggleBoldById(element.id)),
          _toolIcon(
              id: 'italic',
              icon: Icons.format_italic,
              tooltip: 'Italic',
              onTap: () => _toggleItalicById(element.id)),
          _toolIcon(
              id: 'delete',
              icon: Icons.delete,
              tooltip: 'Delete',
              onTap: () => _deleteElementById(element.id)),
        ];
        break;

      case 'image':
        toolIcons = [
          _toolIcon(
              id: 'replace',
              icon: Icons.image_search,
              tooltip: 'Replace Image',
              onTap: () => _replaceImageById(element.id)),
          _toolIcon(
              id: 'delete',
              icon: Icons.delete,
              tooltip: 'Delete',
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
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
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
        content:
            MaterialPicker(pickerColor: sel, onColorChanged: (c) => sel = c),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, sel),
              child: const Text("OK")),
        ],
      ),
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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(context, tempSize),
                child: const Text("OK")),
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
      final w = currentElements[index].fontWeight;
      currentElements[index] = currentElements[index].copyWith(
          fontWeight:
              (w == FontWeight.bold ? FontWeight.normal : FontWeight.bold));
    });
  }

  void _toggleItalicById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    setState(() {
      final s = currentElements[index].fontStyle;
      currentElements[index] = currentElements[index].copyWith(
          fontStyle:
              (s == FontStyle.italic ? FontStyle.normal : FontStyle.italic));
    });
  }

  void _replaceImageById(String id) async {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        currentElements[index] =
            currentElements[index].copyWith(value: pickedFile.path);
      });
    }
  }

  void _deleteElementById(String id) {
    final index = currentElements.indexWhere((e) => e.id == id);
    if (index == -1) return;
    if (_isLockedIdx(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layer is locked')),
      );
      return;
    }
    setState(() {
      currentElements.removeAt(index);
      elementKeys.removeAt(index);
      _selected.remove(index);
    });
    _redoStack.clear();   // ← break redo chain on fresh edits

    _queueAutosave();
  }

  Future<void> _editSpeechBubble(int index) async {
    final element = currentElements[index];
    final initialData = _extractBubbleInitialData(element); // you already have this

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechBubbleEditorScreen(
          title: 'Edit Speech Bubble',
          initialData: initialData,
        ),
      ),
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
        offset: element.offset, // keep current placement
        color: updatedBubble.bubbleColor,
        fontSize: updatedBubble.fontSize,
        fontFamily: updatedBubble.fontFamily,
        fontWeight: updatedBubble.fontWeight,
        fontStyle: updatedBubble.fontStyle,
        meta: jsonEncode({'kind': 'speech_bubble_original', 'data': updatedBubble.toMap()}),
      );
    });

    _queueAutosave(); // keep your autosave flow consistent
  }


  // Future<void> _editSpeechBubble(int index) async {
  //   final element = currentElements[index];
  //   final initialData = _extractBubbleInitialData(element);
  //
  //   final result = await showDialog<Map<String, dynamic>>(
  //     context: context,
  //     builder: (context) =>
  //         DragSpeechBubbleEditDialog(initialData: initialData),
  //   );
  //   if (result == null) return;
  //
  //   final updatedBubble = DragSpeechBubbleData(
  //     text: result['text'],
  //     bubbleColor: result['bubbleColor'],
  //     borderColor: result['borderColor'],
  //     borderWidth: (result['borderWidth'] as num).toDouble(),
  //     bubbleShape: result['bubbleShape'] as DragBubbleShape,
  //     fontSize: (result['fontSize'] as num).toDouble(),
  //     textColor: result['textColor'] as Color,
  //     fontFamily: result['fontFamily'] as String,
  //     fontWeight: result['fontWeight'] as FontWeight,
  //     fontStyle: result['fontStyle'] as FontStyle,
  //     padding: (result['padding'] as num).toDouble(),
  //     tailOffset: result['tailOffset'] as Offset,
  //     tailNorm: Offset(
  //       (result['tailNorm']['dx'] as num).toDouble(),
  //       (result['tailNorm']['dy'] as num).toDouble(),
  //     ),
  //   );
  //
  //   final Uint8List pngBytes = result['pngBytes'] as Uint8List;
  //   final double newW = (result['width'] as num).toDouble();
  //   final double newH = (result['height'] as num).toDouble();
  //
  //   setState(() {
  //     currentElements[index] = element.copyWith(
  //       value: base64Encode(pngBytes),
  //       width: newW,
  //       height: newH,
  //       size: Size(newW, newH),
  //       offset: element.offset,
  //       color: updatedBubble.bubbleColor,
  //       fontSize: updatedBubble.fontSize,
  //       fontFamily: updatedBubble.fontFamily,
  //       fontWeight: updatedBubble.fontWeight,
  //       fontStyle: updatedBubble.fontStyle,
  //       meta: jsonEncode({
  //         'kind': 'speech_bubble_original',
  //         'data': updatedBubble.toMap(),
  //       }),
  //     );
  //   });
  // }

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
      _hiddenById[element.id] = false;
      _lockedById[element.id] = false;
      _selected
        ..clear()
        ..add(currentElements.length - 1);
    });
    _redoStack.clear();   // ← break redo chain on fresh edits

    _queueAutosave();
  }

  Future<void> _addSpeechBubble() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const SpeechBubbleEditorScreen(
          title: 'Add Speech Bubble',
          // You can pass custom initialData here if you want
        ),
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


/*
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
      meta: jsonEncode(
          {'kind': 'speech_bubble_original', 'data': bubbleData.toMap()}),
    );

    _addNewElement(newElement);
  }
*/

  Future<Uint8List?> _capturePanelAsImage() async {
    try {
      RenderRepaintBoundary boundary = _panelContentKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
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
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
            onColorChanged: (color) =>
                setState(() => drawSelectedColor = color),
            onBrushSizeChanged: (size) =>
                setState(() => selectedBrushSize = size),
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
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(tempColor),
              child: const Text("Select")),
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
    final dx = desired.dx
        .clamp(0.0, (canvas.width - elSize.width).clamp(0.0, double.infinity));
    final dy = desired.dy.clamp(
        0.0, (canvas.height - elSize.height).clamp(0.0, double.infinity));
    return Offset(dx, dy);
  }

  PanelElementModel _deepCloneElement(PanelElementModel e,
      {Offset? offsetOverride}) {
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

/*
  Future<void> _savePanel({bool exitAfterSave = true}) async {
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
          updatedElements.add(currentElements[i].copyWith(
            offset: state.position,
            size: state.size,
            width: state.size.width,
            height: state.size.height,
            fontFamily: currentElements[i].fontFamily,
          ));
        } else {
          updatedElements.add(currentElements[i]);
        }
      }

      // Let UI settle (e.g., hidden layer removed) before capturing
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() => _isEditing = true);

      final capturedImage = await _capturePanelAsImage();

      final updatedPanel = panel.copyWith(
        elements: updatedElements,                 // ← elements are unchanged
        backgroundColor: _selectedBackgroundColor,
        previewImage: capturedImage,               // ← reflects hidden layers
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panel saved'), duration: Duration(milliseconds: 800)),
        );
      }

      if (mounted && exitAfterSave) {
        Navigator.pop(context, updatedPanel);
      } else {
        // Stay on screen: just update local panel reference
        panel = updatedPanel;
      }
    } catch (e) {
      debugPrint('Error saving panel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save failed'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
*/

  void _savePanel() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _isEditing = false; // temporarily hide guides etc. for capture
    });

    try {
      // 1) Build elements with latest position/size
      final updatedElements = <PanelElementModel>[];
      for (int i = 0; i < currentElements.length; i++) {
        final st = elementKeys[i].currentState;
        final src = currentElements[i];

        final newSize = st?.size ?? src.size ?? Size(src.width, src.height);
        final newOffset = st?.position ?? src.offset;

        var el = src.copyWith(
          offset: newOffset,
          size: newSize,
          width: newSize.width,
          height: newSize.height,
        );

        // 2) Persist hidden flag into meta so it survives reopen
        final hidden = _hiddenById[el.id] ?? false;
        el = _withHiddenFlag(el, hidden);

        updatedElements.add(el);
      }

      // Let the UI settle, then re-enable editing for capture
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) setState(() => _isEditing = true);

      // 3) Capture preview image (reflects hidden layers)
      final capturedImage = await _capturePanelAsImage();

      // 4) Build updated panel
      final updatedPanel = panel.copyWith(
        elements: updatedElements,
        backgroundColor: _selectedBackgroundColor,
        previewImage: capturedImage,
      );

      // 5) Persist upward (callback) and also return via pop
      panel = updatedPanel; // local cache
      widget.onAutosave?.call(updatedPanel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panel saved!'), duration: Duration(milliseconds: 900)),
        );
        Navigator.pop(context, updatedPanel);
      }
    } catch (e) {
      debugPrint('Error saving panel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving panel. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          enabled: _hasMultiUnlocked,
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
          enabled: _hasUnlockedSelection, // was _canPaste or similar
          child: _menuRow(Icons.content_paste, 'Paste'),
        ),
        // Delete selection (single or multiple)
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.delete,
          enabled: _canPaste,
          child: _menuRow(Icons.delete, 'Delete'),
        ),
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.undo,
          enabled: !_isSaving && currentElements.isNotEmpty,
          child: _menuRow(Icons.undo, 'Undo'),
        ),
        PopupMenuItem<_PanelMenuAction>(
          value: _PanelMenuAction.redo,
          enabled: !_isSaving && _redoStack.isNotEmpty,          // ← enable/disable
          child: _menuRow(Icons.redo, 'Redo'),
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
        _resetGroupOverlayRect(); // keep overlay in sync with selection mode
        break;

      case _PanelMenuAction.group:
        if (_hasMultiSelection) _groupSelected();
        break;

      case _PanelMenuAction.ungroup:
        if (_hasSelection) {
          _ungroupSelected(); //  no change to _multiSelectMode here
          _resetGroupOverlayRect();
        }
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
      case _PanelMenuAction.undo:
        _undoLast();
        break;
      case _PanelMenuAction.redo:
        _redoLast();
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
  }

  Widget _wrapLayerLock(int index, Widget child) {
    return AbsorbPointer(
      absorbing: _isLockedIdx(index),
      child: Opacity(
        opacity: _isLockedIdx(index) ? 0.6 : 1.0,
        child: child,
      ),
    );
  }

/*  void _toggleVisibleById(String id) {
    setState(() {
      final nowHidden = !(_hiddenById[id] ?? false);
      _hiddenById[id] = nowHidden;
      if (nowHidden) {
        final idx = currentElements.indexWhere((e) => e.id == id);
        if (idx != -1) _selected.remove(idx);
        _resetGroupOverlayRect();
      }
    });
  }*/

  /*void _toggleVisibleById(String id) {
    setState(() {
      final nowHidden = !(_hiddenById[id] ?? false);
      _hiddenById[id] = nowHidden;

      final idx = currentElements.indexWhere((e) => e.id == id);
      if (idx != -1) {
        // persist to the element’s meta so it survives reopening
        currentElements[idx] = _withHiddenFlag(currentElements[idx], nowHidden);

        // unselect if we just hid it
        if (nowHidden) _selected.remove(idx);
      }
    });
    _resetGroupOverlayRect();
  }
*/

  void _toggleVisibleById(String id) {
    setState(() {
      final nowHidden = !(_hiddenById[id] ?? false);
      _hiddenById[id] = nowHidden;

      final idx = currentElements.indexWhere((e) => e.id == id);
      if (idx != -1) {
        currentElements[idx] = _withHiddenFlag(currentElements[idx], nowHidden); // persist
        if (nowHidden) _selected.remove(idx); // unselect if we just hid it
      }
    });
    _resetGroupOverlayRect();
    _queueAutosave();


    /*   // OPTIONAL: immediate autosave back to parent so state persists even if user doesn’t press “Save”
    final panelSnapshot = panel.copyWith(elements: currentElements, backgroundColor: _selectedBackgroundColor);
    widget.onAutosave?.call(panelSnapshot);*/
  }

/*
  void _toggleVisibleById(String id) {
    setState(() {
      final nowHidden = !(_hiddenById[id] ?? false);
      _hiddenById[id] = nowHidden;

      // If we just hid a selected layer, unselect it
      if (nowHidden) {
        final idx = currentElements.indexWhere((e) => e.id == id);
        if (idx != -1) _selected.remove(idx);
      }
    });

    _resetGroupOverlayRect();

    // Save immediately with the hidden layer NOT rendered in the preview,
    // but WITHOUT leaving the edit screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePanel(exitAfterSave: false);
    });
  }
*/

 /* void _toggleLockById(String id) {
    setState(() => _lockedById[id] = !(_lockedById[id] ?? false));
  }*/
  void _toggleLockById(String id) {
    setState(() {
      final next = !(_lockedById[id] ?? false);
      _lockedById[id] = next;
      if (next) {
        final idx = currentElements.indexWhere((e) => e.id == id);
        if (idx != -1) _selected.remove(idx);
      }
    });
    _resetGroupOverlayRect();
  }


  String _layerTitle(PanelElementModel el, int idx) {
    switch (el.type) {
      case 'text':
        return 'Text (${el.value.toString().trim()})';
      case 'image':
        return 'Image';
      case 'clipart':
        return 'Clipart';
      case 'character':
        return 'Character';
      case 'speech_bubble':
        return 'Speech Bubble';
      case 'Draw':
        return 'Drawing';
      default:
        return 'Layer #${idx + 1}';
    }
  }
  Widget _buildLayerEditorPanel() {
    // Show top-most first

    final EdgeInsets panelPadding =
    _inspectorCollapsed ? const EdgeInsets.symmetric(horizontal: 8)
        : const EdgeInsets.all(8);

    final double collapsedHeight = _kInspectorHeaderH + panelPadding.vertical;
    final double panelHeight = _inspectorCollapsed ? collapsedHeight : _inspectorHeight;



    final displayOrder =
    List<int>.generate(currentElements.length, (i) => i).reversed.toList();

    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final safeTopMin = kToolbarHeight + mq.padding.top + 8;
    const bottomMargin = 16.0;


    // Clamp current top inside screen on every build
    final maxTop = (screenH - panelHeight - bottomMargin).clamp(0.0, screenH);
    final clampedTop = _inspectorTop.clamp(safeTopMin, maxTop);


    final currentHeight = _inspectorCollapsed ? collapsedHeight : _inspectorHeight;
    final maxTopNow = screenH - currentHeight - bottomMargin;


    if (clampedTop != _inspectorTop) {
      // keep state valid without setState loop
      _inspectorTop = clampedTop;
    }

    void _toggleCollapsed() {
      setState(() {
        _inspectorCollapsed = !_inspectorCollapsed;
      });
    }

    void _maximize() {
      setState(() {
        _inspectorCollapsed = false;
        _inspectorTop = safeTopMin;
        _inspectorHeight = screenH - safeTopMin - bottomMargin;
      });
    }

    return Positioned(
      right: 8,
      top: _inspectorTop,
      height: panelHeight,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,

        child: Container(
          width: _kInspectorWidth,
          padding: panelPadding, // <- changed
          child: Column(
            children: [
              // Fixed-height header so it never grows unexpectedly
              SizedBox(
                height: _kInspectorHeaderH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    _inspectorDragStartDy = d.globalPosition.dy;
                    _inspectorStartTop = _inspectorTop;
                  },
                  onPanUpdate: (d) {
                    if (_inspectorDragStartDy == null || _inspectorStartTop == null) return;
                    final dy = d.globalPosition.dy - _inspectorDragStartDy!;
                    final newTop = _inspectorStartTop! + dy;
                    final currentHeight = _inspectorCollapsed ? collapsedHeight : _inspectorHeight;
                    final maxTopNow = screenH - currentHeight - bottomMargin;
                    setState(() => _inspectorTop = newTop.clamp(safeTopMin, maxTopNow));
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Layers', style: TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: _inspectorCollapsed ? 'Expand' : 'Collapse',
                        icon: Icon(_inspectorCollapsed ? Icons.unfold_more : Icons.unfold_less),
                        onPressed: () => setState(() => _inspectorCollapsed = !_inspectorCollapsed),
                      ),
                      IconButton(
                        tooltip: 'Maximize',
                        icon: const Icon(Icons.open_in_full),
                        onPressed: () {
                          setState(() {
                            _inspectorCollapsed = false;
                            _inspectorTop = safeTopMin;
                            _inspectorHeight = screenH - safeTopMin - bottomMargin;
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showLayerPanel = false),
                      ),
                    ],
                  ),
                ),
              ),

              // Only show divider/content when expanded
              if (!_inspectorCollapsed)
                const Divider(height: 1),

              if (!_inspectorCollapsed)
                Expanded(
                  child: Stack(
                    children: [
                      ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayOrder.length,
                        onReorder: (oldDisplay, newDisplay) {
                          setState(() {
                            final len = currentElements.length;

                            // Convert "display row" to actual backing index
                            final oldIdx = len - 1 - oldDisplay;
                            int newIdx = len - 1 - newDisplay;
                            if (newDisplay > oldDisplay) newIdx += 1;
                            newIdx = newIdx.clamp(0, currentElements.length);

                            // Preserve selection by IDs
                            final selectedIds = _selected
                                .map((i) => currentElements[i].id)
                                .toSet();

                            final movedEl = currentElements.removeAt(oldIdx);
                            final movedKey = elementKeys.removeAt(oldIdx);
                            currentElements.insert(newIdx, movedEl);
                            elementKeys.insert(newIdx, movedKey);

                            // Rebuild selection set after reorder
                            _selected.clear();
                            for (int i = 0; i < currentElements.length; i++) {
                              if (selectedIds.contains(currentElements[i].id)) {
                                _selected.add(i);
                              }
                            }
                            _resetGroupOverlayRect();
                          });
                        },
                        itemBuilder: (ctx, displayIndex) {
                          final idx = displayOrder[displayIndex];
                          final el = currentElements[idx];
                          final selected = _selected.contains(idx);
                          final hidden = _isHiddenIdx(idx);
                          final locked = _isLockedIdx(idx);

                          return Container(
                            key: ValueKey(el.id),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.blue.withOpacity(0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                  selected ? Colors.blue : Colors.black12),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              leading: ReorderableDragStartListener(
                                index: displayIndex,
                                child: const Icon(Icons.drag_indicator),
                              ),
                              title: Text(
                                _layerTitle(el, idx),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${el.type}  ·  ${el.width.toInt()}×${el.height.toInt()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                setState(() {
                                  if (_multiSelectMode) {
                                    if (_selected.contains(idx)) {
                                      _selected.remove(idx);
                                    } else {
                                      _selected.add(idx);
                                    }
                                  } else {
                                    _selected
                                      ..clear()
                                      ..add(idx);
                                  }
                                });
                                _resetGroupOverlayRect();
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: hidden ? 'Show' : 'Hide',
                                    icon: Icon(hidden
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => _toggleVisibleById(el.id),
                                  ),
                                  IconButton(
                                    tooltip: locked ? 'Unlock' : 'Lock',
                                    icon: Icon(
                                        locked ? Icons.lock : Icons.lock_open),
                                    onPressed: () => _toggleLockById(el.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      Align(
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (d) {
                            _resizeDragStartDy = d.globalPosition.dy;
                            _inspectorStartHeight = _inspectorHeight;
                          },
                          onPanUpdate: (d) {
                            if (_resizeDragStartDy == null || _inspectorStartHeight == null) return;
                            final dy = d.globalPosition.dy - _resizeDragStartDy!;
                            final newH = (_inspectorStartHeight! + dy).clamp(
                              _kInspectorHeaderH + 120,
                              screenH - _inspectorTop - bottomMargin,
                            );
                            setState(() => _inspectorHeight = newH);
                          },
                          child: Container(
                            height: 10,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: const Icon(Icons.drag_handle, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

      ),
    );
  }

  Future<void> _performAutosave() async {
    final myToken = ++_saveGen;
    setState(() {
      _saveStatus = 'Saving...';
      _saveProgress = 0.0;
      _isSaving = true;
    });

    // Build updatedPanel exactly like your _savePanel() does:
    try {
      // STEP 1: snapshot element states
      final updatedElements = <PanelElementModel>[];
      for (int i = 0; i < currentElements.length; i++) {
        final st = (i < elementKeys.length) ? elementKeys[i].currentState : null;
        final src = currentElements[i];
        final newSize = st?.size ?? src.size ?? Size(src.width, src.height);
        final newOffset = st?.position ?? src.offset;
        var el = src.copyWith(
          offset: newOffset,
          size: newSize,
          width: newSize.width,
          height: newSize.height,
        );
        // persist visibility flag
        final hidden = _hiddenById[el.id] ?? false;
        el = _withHiddenFlag(el, hidden);
        updatedElements.add(el);
      }
      if (!mounted || myToken != _saveGen) return;
      setState(() => _saveProgress = 0.15); // 15%

      // STEP 2: let UI settle
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted || myToken != _saveGen) return;
      setState(() => _saveProgress = 0.25); // 25%

      // STEP 3: capture preview (heaviest)
      setState(() => _isEditing = true); // ensure guides off if you do that
      final capturedImage = await _capturePanelAsImage();
      if (!mounted || myToken != _saveGen) return;
      setState(() => _saveProgress = 0.70); // 70%

      // STEP 4: assemble panel
      final updatedPanel = panel.copyWith(
        elements: updatedElements,
        backgroundColor: _selectedBackgroundColor,
        previewImage: capturedImage,
      );
      if (!mounted || myToken != _saveGen) return;
      setState(() => _saveProgress = 0.85); // 85%

      // STEP 5: notify parent storage layer
      widget.onAutosave?.call(updatedPanel);
      panel = updatedPanel;

      if (!mounted || myToken != _saveGen) return;
      setState(() {
        _saveProgress = 1.0;           // 100%
        _saveStatus   = 'Saved';
        _isSaving     = false;
      });

      // Tiny delay so users see 100% flash, then clear bar
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || myToken != _saveGen) return;
      setState(() => _saveProgress = null);
    } catch (e) {
      if (!mounted || myToken != _saveGen) return;
      setState(() {
        _saveStatus = 'Save failed';
        _isSaving = false;
        _saveProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving panel.'), backgroundColor: Colors.red),
      );
    }
  }

  void _queueAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 350), () {
      _performAutosave();
    });
  }

  /*void _undoLast() {
    if (_isSaving) return;
    if (currentElements.isEmpty || elementKeys.isEmpty) return;

    setState(() {
      currentElements.removeLast();
      elementKeys.removeLast();
      _clearSelection();
    });

    // optional: trigger autosave so preview/state stays consistent
    _queueAutosave(); // if you’re using the debounced autosave from earlier
  }*/

  void _undoLast() {
    if (_isSaving) return;
    if (currentElements.isEmpty) return;

    setState(() {
      final removed = currentElements.removeLast();
      if (elementKeys.isNotEmpty) elementKeys.removeLast();
      _redoStack.add(removed);            // ← enable redo
      _selected.clear();
    });
    _queueAutosave(); // or your autosave trigger
  }

  void _redoLast() {
    if (_isSaving) return;
    if (_redoStack.isEmpty) return;

    setState(() {
      final el = _redoStack.removeLast();
      currentElements.add(el);
      elementKeys.add(GlobalKey<ResizableDraggableState>());
      _selected
        ..clear()
        ..add(currentElements.length - 1);
    });
    _queueAutosave();
  }
}

/// A tiny rounded pill that shows save state + optional percent.
/// Yellow when saving/unsaved, Green when saved.
class SaveStatusPill extends StatelessWidget {
  final String status;        // e.g. "Saving..." or "Saved"
  final double? progress;     // null when idle, 0..1 when saving

  const SaveStatusPill({
    super.key,
    required this.status,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSaving = progress != null && progress! < 1.0;
    final bool isSaved  = (progress == null && status.toLowerCase() == 'saved') || progress == 1.0;

    final Color bg = isSaved
        ? Colors.green.shade600
        : Colors.amber.shade600; // yellow when not saved / saving

    final Color fg = Colors.white;

    final String percentStr =
    isSaving ? '${(progress!.clamp(0, 1) * 100).round()}%' : '';

    final IconData icon = isSaved ? Icons.check_circle : Icons.autorenew;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999), // full pill
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, key: ValueKey(icon), size: 16, color: fg),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isSaving) ...[
            const SizedBox(width: 6),
            Text(
              percentStr,
              style: TextStyle(
                color: fg.withOpacity(0.95),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
