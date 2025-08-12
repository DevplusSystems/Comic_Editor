import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:comic_editor/project_hive_model.dart';
import 'package:comic_editor/project_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'PreviewPdf/PDFPageFormat.dart';
import 'PreviewPdf/PageMarginsPainter.dart';
import 'Resizeable/GridPainter.dart';
import 'PanelEditScreen.dart';
import 'PanelModel/PanelElementModel.dart';
import 'PanelModel/Project.dart';
import 'PreviewPdf/AllPagesPreviewScreen.dart';

enum AlignAlignment { topLeft, topRight, bottomLeft, bottomRight }

enum _SaveState { idle, saving, saved, error }

// 1) Menu actions enum
enum _MenuAction {
  export,
  preview,
  toggleMargins,
  toggleGrid,
  layouts,
  addPage
}

class PanelLayoutEditorScreen extends StatefulWidget {
  final Project project;

  const PanelLayoutEditorScreen({super.key, required this.project});

  @override
  State<PanelLayoutEditorScreen> createState() =>
      _PanelLayoutEditorScreenState();
}

class _PanelLayoutEditorScreenState extends State<PanelLayoutEditorScreen>
    with WidgetsBindingObserver {
  late Project currentProject;
  int currentPageIndex = 0;
  bool isDrawerOpen = false;
  List<List<LayoutPanel>> pages = [[]];
  int _currentPage = 0;
  LayoutPanel? selectedPanel;
  final GlobalKey _canvasKey = GlobalKey();
  bool _showGrid = false;
  final bool _snapToGrid = false;
  String _selectedPageFormat = 'A4';
  bool _showPageMargins = true;
  final double _pageMargin = 10.0;

  double _drawerTopOffset = 100.0; // initial vertical position

  Size get _currentPageSize => PDFPageFormat.formats[_selectedPageFormat]!;

  double get _canvasWidth => _currentPageSize.width;

  double get _canvasHeight => _currentPageSize.height;

  List<LayoutPanel> get currentPagePanels => currentProject.pages.isNotEmpty
      ? currentProject.pages[currentPageIndex]
      : [];

  final double _minPanelSize = 40.0; // smaller min size

  // 👉 Floating inspector bar state
  bool _inspectorCollapsed = false;
  double _inspectorTop = 140.0;
  bool _lockAspect = false;

  // --- Autosave state ---

  Timer? _autosaveTimer;
  bool _dirty = false;
  DateTime? _lastSavedAt;

  final ValueNotifier<_SaveState> _saveState =
      ValueNotifier<_SaveState>(_SaveState.saved);

  // Wraps setState and marks project dirty
  void _mutate(VoidCallback changes) {
    setState(changes);
    _markDirty();
  }

  // --- Page reordering state ---
  int? _draggingPageIndex;
  int? _hoveredPageIndex;
  bool _showReorderStrip = false;




  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    currentProject = widget.project;
    pages = List.from(widget.project.pages);

    if (kDebugMode) {
      print('=== PanelLayoutEditorScreen INIT ===');
      print('Project: ${currentProject.name}');
      print('Pages count: ${pages.length}');
    }
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      if (kDebugMode) {
        print('Page $pageIndex: ${page.length} panels');
      }

      for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
        final panel = page[panelIndex];
        if (kDebugMode) {
          print(
              '  Panel $panelIndex (${panel.id}): ${panel.elements.length} elements');
        }

        for (int elementIndex = 0;
            elementIndex < panel.elements.length;
            elementIndex++) {
          final element = panel.elements[elementIndex];
          if (kDebugMode) {
            print(
                '    Element $elementIndex: ${element.type} - "${element.value}"');
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save when app backgrounds or is about to detach
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _flushAutosaveNow(); // fire & forget
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
        title: Text(currentProject.name),
        actions: [

        /*  IconButton(
            tooltip: pages.length > 1
                ? (_showReorderStrip ? 'Hide Reorder' : 'Reorder Pages')
                : 'Need at least 2 pages',
            icon: Icon(
              Icons.reorder,
              // highlight when active; disabled handled by onPressed=null
              color: _showReorderStrip ? Colors.amberAccent : Colors.white,
            ),
            onPressed: pages.length > 1
                ? () {
              setState(() {
                _showReorderStrip = !_showReorderStrip;
                _draggingPageIndex = null;
                _hoveredPageIndex = null;
              });
            }
                : null,
          ),*/
/*
          Builder(builder: (context) {
            final canReorder = pages.length > 1;
            return IconButton(
              tooltip: canReorder
                  ? (_showReorderStrip ? 'Hide Reorder' : 'Reorder Pages')
                  : 'Need at least 2 pages',
              icon: Icon(
                Icons.reorder,
                // highlight when active; dim when disabled
                color: !canReorder
                    ? Colors.white54
                    : (_showReorderStrip ? Colors.amberAccent : Colors.white),
              ),
              onPressed: canReorder
                  ? () {
                setState(() {
                  _showReorderStrip = !_showReorderStrip;
                  _draggingPageIndex = null; // optional: clear drag state
                  _hoveredPageIndex = null;
                });
              }
                  : null,
            );
          }),
*/
          _buildReorderToggleAction(),  // ⬅️ new button

         /* Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildSaveStatusPill(), // your existing pill
          ),*/
          _buildOverflowMenu(),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) _toggleDrawer(true);
            if (details.primaryVelocity! < 0) _toggleDrawer(false);
          }
        },
        onTap: () {
          if (isDrawerOpen) _toggleDrawer(false);
          setState(() => selectedPanel = null);
        },
        child: Stack(
          children: [
            Column(
              children: [
                _buildPageActionButtons(),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _canvasWidth / _canvasHeight,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scaleX = constraints.maxWidth / _canvasWidth;
                          final scaleY = constraints.maxHeight / _canvasHeight;
                          return RepaintBoundary(
                            key: _canvasKey,
                            child: Container(
                              color: Colors.grey[100],
                              child: DragTarget<LayoutPanel>(
                                onAcceptWithDetails: (details) {
                                  final box = _canvasKey.currentContext
                                      ?.findRenderObject() as RenderBox?;
                                  if (box != null) {
                                    final offset =
                                        box.globalToLocal(details.offset);
                                    final incoming = details.data;
                                    final newPanel = LayoutPanel(
                                      id: incoming.id,
                                      width: incoming.width,
                                      height: incoming.height,
                                      x: (offset.dx - incoming.width / 2).clamp(
                                          _pageMargin,
                                          _canvasWidth -
                                              incoming.width -
                                              _pageMargin),
                                      y: (offset.dy - incoming.height / 2)
                                          .clamp(
                                              _pageMargin,
                                              _canvasHeight -
                                                  incoming.height -
                                                  _pageMargin),
                                      backgroundColor: Colors.white,
                                    );
                                    if (!_isOverlapping(newPanel)) {
                                      _mutate(() {
                                        pages[_currentPage].add(newPanel);
                                      });
                                    }
                                  }
                                },
                                builder:
                                    (context, candidateData, rejectedData) {
                                  return Stack(
                                    children: [
                                      if (_showGrid)
                                        Transform.scale(
                                          scale: min(scaleX, scaleY),
                                          alignment: Alignment.topLeft,
                                          child: _buildGridOverlay(),
                                        ),
                                      Transform.scale(
                                        scale: min(scaleX, scaleY),
                                        alignment: Alignment.topLeft,
                                        child: _buildPageMarginsOverlay(),
                                      ),
                                      if (pages[_currentPage].isEmpty)
                                        Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.description_outlined,
                                                  size: 64,
                                                  color: Colors.grey[400]),
                                              const SizedBox(height: 16),
                                              Text('Empty Page',
                                                  style: TextStyle(
                                                      fontSize: 20,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text(
                                                  'Add panels or choose a layout template',
                                                  style: TextStyle(
                                                      color: Colors.grey[500])),
                                            ],
                                          ),
                                        ),
                                      ...pages[_currentPage].map((panel) {
                                        return Positioned(
                                          left: panel.x * scaleX,
                                          top: panel.y * scaleY,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedPanel =
                                                    selectedPanel == panel
                                                        ? null
                                                        : panel;
                                              });
                                            },
                                            onPanUpdate: (details) {
                                              double newX = panel.x +
                                                  details.delta.dx / scaleX;
                                              double newY = panel.y +
                                                  details.delta.dy / scaleY;
                                              if (_snapToGrid) {
                                                newX =
                                                    (newX / 20).round() * 20.0;
                                                newY =
                                                    (newY / 20).round() * 20.0;
                                              }
                                              newX = newX.clamp(
                                                  _pageMargin,
                                                  _canvasWidth -
                                                      panel.width -
                                                      _pageMargin);
                                              newY = newY.clamp(
                                                  _pageMargin,
                                                  _canvasHeight -
                                                      panel.height -
                                                      _pageMargin);
                                              final movedPanel = panel.copyWith(
                                                  x: newX, y: newY);
                                              if (!_isOverlapping(movedPanel,
                                                  excludePanel: panel)) {
                                                setState(() {
                                                  panel.x = newX;
                                                  panel.y = newY;
                                                });
                                              }
                                            },
                                            child: Transform.scale(
                                              scale: min(scaleX, scaleY),
                                              alignment: Alignment.topLeft,
                                              child: _buildPanelContent(panel),
                                            ),
                                          ),
                                        );
                                      }).toList(),

                                      /*...pages[_currentPage]
                                          .map((panel) => _buildPanelWithResize(
                                              panel, scaleX, scaleY))
                                          .toList(),*/
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 4) Footer – ONLY pages section (make sure your _buildFooter now shows pages strip)
                _buildFooter(),
              ],
            ),

            // 5) Right floating inspector (kept)
            if (selectedPanel != null)
              _buildRightFloatingInspector(selectedPanel!),

            _buildFloatingDrawerWithToggle(
                screenHeight, 150, screenHeight * 0.4),

            // Floating Toggle Icon
            Positioned(
              left: isDrawerOpen ? 150 : 0,
              top: _drawerTopOffset + (screenHeight * 0.4 / 2) - 20,
              child: GestureDetector(
                onTap: () => setState(() => isDrawerOpen = !isDrawerOpen),
                onPanUpdate: (details) {
                  setState(() {
                    _drawerTopOffset += details.delta.dy;
                    _drawerTopOffset = _drawerTopOffset.clamp(
                        0.0, screenHeight - (screenHeight * 0.4));
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Icon(
                    isDrawerOpen
                        ? Icons.arrow_back_ios
                        : Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
/*
            if (selectedPanel != null) _buildFloatingEditButton(),
*/
          ],
        ),
      ),
    );
  }

  // ---------- Autosave ----------
  void _markDirty() {
    _dirty = true;
    _scheduleAutosave(); // debounce
  }

  void _scheduleAutosave(
      [Duration delay = const Duration(milliseconds: 1200)]) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(delay, _flushAutosaveNow);
  }

  Future<void> _flushAutosaveNow() async {
    _autosaveTimer?.cancel();
    if (!_dirty) return;
    _saveState.value = _SaveState.saving;
    try {
      await _saveCurrentProjectToHive(); // writes to Hive
      _dirty = false;
      _lastSavedAt = DateTime.now();
      _saveState.value = _SaveState.saved;
    } catch (e) {
      debugPrint('Autosave failed: $e');
      _saveState.value = _SaveState.error;
    }
  }

  Future<void> _saveCurrentProjectToHive() async {
    final box = Hive.box<ProjectHiveModel>('drafts');
    final updated = currentProject.copyWith(
      pages: pages,
      lastModified: DateTime.now(),
    );
    final hiveModel = toHiveModel(updated);
    await box.put(updated.id, hiveModel);
    currentProject = updated; // keep local in sync
  }

  // Optional: a small “Saved / Saving…” pill for AppBar
  Widget _buildSaveStatusPill() {
    return ValueListenableBuilder<_SaveState>(
      valueListenable: _saveState,
      builder: (_, state, __) {
        Widget icon;
        String text;
        switch (state) {
          case _SaveState.saving:
            icon = const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
            text = 'Saving…';
            break;
          case _SaveState.saved:
            icon = const Icon(Icons.check, size: 16);
            text = 'Saved';
            break;
          case _SaveState.error:
            icon = const Icon(Icons.error_outline, size: 16);
            text = 'Save failed';
            break;
          default:
            icon = const SizedBox(width: 10, height: 10);
            text = '';
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: state == _SaveState.error
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  state == _SaveState.error ? Colors.redAccent : Colors.green,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // end of save

  // ---------- Menu Drawer ----------
// 2) Overflow menu widget
  Widget _buildOverflowMenu() {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu),
      splashRadius: 22,
      onSelected: _onMenuSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuAction.export,
          child: _menuRow(Icons.download, 'Export'),
        ),
        PopupMenuItem(
          value: _MenuAction.preview,
          child: _menuRow(Icons.remove_red_eye, 'Preview'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.toggleMargins,
          child: _menuRow(
            _showPageMargins ? Icons.pages_outlined : Icons.pages,
            _showPageMargins ? 'Hide Margin' : 'Show Margin',
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.toggleGrid,
          child: _menuRow(
            _showGrid ? Icons.grid_off : Icons.grid_on,
            _showGrid ? 'Hide Grid' : 'Show Grid',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.layouts,
          child: _menuRow(Icons.dashboard_customize, 'Layouts'),
        ),
        PopupMenuItem(
          value: _MenuAction.addPage,
          child: _menuRow(Icons.add_box, 'Add Page'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
    );
  }

// 3) Handle selection
  void _onMenuSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.export:
        _showExportOptions();
        break;
      case _MenuAction.preview:
        _showAllPagesPreview();
        break;
      case _MenuAction.toggleMargins:
        _mutate(() => _showPageMargins = !_showPageMargins);
        break;
      case _MenuAction.toggleGrid:
        _mutate(() => _showGrid = !_showGrid);
        break;
      case _MenuAction.layouts:
        _showLayoutTemplates();
        break;
      case _MenuAction.addPage:
        _addPage();
        break;
    }
  }

// 4) Simple row for icon + text in menu
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

  // ---------- Menu Drawer ----------

  //---------- AutoSave functionality ----------

  // ---------- Page Ra_arrangement ----------

  Widget _buildReorderablePageThumb(int index) {
    return LongPressDraggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: _buildPageThumbnail(index)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildPageThumbnail(index),
      ),
      onDragStarted: () => setState(() => _draggingPageIndex = index),
      onDraggableCanceled: (_, __) => setState(() {
        _draggingPageIndex = null;
        _hoveredPageIndex = null;
      }),
      onDragEnd: (_) => setState(() {
        _draggingPageIndex = null;
        _hoveredPageIndex = null;
      }),
      child: DragTarget<int>(
        onWillAccept: (from) {
          setState(() => _hoveredPageIndex = index);
          return from != index;
        },
        onLeave: (_) => setState(() => _hoveredPageIndex = null),
        onAccept: (from) {
          _reorderPages(from, index); // insert BEFORE this index
          setState(() {
            _hoveredPageIndex = null;
            _draggingPageIndex = null;
          });
        },
        builder: (context, _, __) {
          return GestureDetector(
            onTap: () => _switchPage(index),
            child: _buildPageThumbnail(index),
          );
        },
      ),
    );
  }

  Widget _buildEndDropTarget() {
    final isHoverEnd = _hoveredPageIndex == pages.length;
    return DragTarget<int>(
      onWillAccept: (_) {
        setState(() => _hoveredPageIndex = pages.length);
        return true;
      },
      onLeave: (_) => setState(() => _hoveredPageIndex = null),
      onAccept: (from) {
        _reorderPages(from, pages.length); // append to end
        setState(() => _hoveredPageIndex = null);
      },
      builder: (context, _, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          width: 64,
          height: 112,
          decoration: BoxDecoration(
            color: isHoverEnd ? Colors.orange.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHoverEnd ? Colors.orange : Colors.black12,
              style: BorderStyle.solid,
              width: isHoverEnd ? 2 : 1,
            ),
          ),
          child: const Center(
            child: Icon(Icons.add, size: 20),
          ),
        );
      },
    );
  }

  void _reorderPages(int from, int to) {
    if (from == to) return;

    setState(() {
      // If user drops onto the final "add to end" zone, `to` can equal pages.length
      final removed = pages.removeAt(from);
      final insertIndex = (to > from) ? to - 1 : to;
      final safeIndex = insertIndex.clamp(0, pages.length);
      pages.insert(safeIndex, removed);

      // Keep current page selection reasonable after move
      var cur = _currentPage;
      if (cur == from) {
        cur = safeIndex;
      } else if (from < cur && to - 1 >= cur) {
        cur -= 1; // dragged a page up past the current page
      } else if (from > cur && to <= cur) {
        cur += 1; // dragged a page down before the current page
      }
      _currentPage = cur.clamp(0, pages.length - 1);
      currentPageIndex = _currentPage;

      currentProject = currentProject.copyWith(
        pages: pages,
        lastModified: DateTime.now(),
      );
    });
    _markDirty();
  }

  Widget _buildPageThumbnail(int pageIndex) {
    // small portrait preview
    const double thumbW = 70;
    const double thumbH = 80;

    final wScale = thumbW / _canvasWidth;
    final hScale = thumbH / _canvasHeight;

    final isActive = _currentPage == pageIndex;
    final isHover = _hoveredPageIndex == pageIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? Colors.blue
              : (isHover ? Colors.orange : Colors.black12),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          if (isActive)
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: thumbW,
            height: thumbH,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // draw light panel boxes as a hint of layout
                ...pages[pageIndex].map((p) {
                  final l = p.x * wScale;
                  final t = p.y * hScale;
                  final w = (p.width * wScale).clamp(1.0, thumbW);
                  final h = (p.height * hScale).clamp(1.0, thumbH);
                  return Positioned(
                    left: l,
                    top: t,
                    width: w,
                    height: h,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        border:
                            Border.all(color: Colors.grey.shade600, width: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pageIndex + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ---------- Page Ra_arrangement ----------

  // ---------- Floating Inspector (RIGHT) ----------
  Widget _buildRightFloatingInspector(LayoutPanel panel) {
    final double maxW = _canvasWidth - 2 * _pageMargin;
    final double maxH = _canvasHeight - 2 * _pageMargin;
    final theme = Theme.of(context);
    final double aspect = panel.width > 0 ? (panel.height / panel.width) : 1.0;

    return Positioned(
      right: 16,
      top: _inspectorTop,
      child: GestureDetector(
        onPanUpdate: (d) {
          final screenH = MediaQuery.of(context).size.height;
          setState(() {
            _inspectorTop += d.delta.dy;
            _inspectorTop = _inspectorTop.clamp(80.0, screenH - 260.0);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6)),
              ],
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    color: Colors.blue.shade50,
                    border: const Border(
                        bottom: BorderSide(color: Color(0x11000000))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          color: Colors.blue.shade400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          panel.id.isNotEmpty ? panel.id : 'Panel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: _inspectorCollapsed ? 'Expand' : 'Collapse',
                        icon: Icon(_inspectorCollapsed
                            ? Icons.unfold_more
                            : Icons.unfold_less),
                        onPressed: () => setState(
                            () => _inspectorCollapsed = !_inspectorCollapsed),
                      ),
                    ],
                  ),
                ),

                if (!_inspectorCollapsed) ...[
                  // size + lock
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Text(
                            'W: ${panel.width.toInt()}  H: ${panel.height.toInt()}',
                            style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setState(() => _lockAspect = !_lockAspect),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _lockAspect
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _lockAspect ? Colors.blue : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(_lockAspect ? Icons.lock : Icons.lock_open,
                                    size: 16,
                                    color: _lockAspect
                                        ? Colors.blue
                                        : Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  'Lock',
                                  style: TextStyle(
                                    color: _lockAspect
                                        ? Colors.blue
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Width slider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: const [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('Width',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Slider(
                      min: _minPanelSize,
                      max: maxW,
                      value: panel.width.clamp(_minPanelSize, maxW),
                      onChanged: (v) {
                        double newW = v;
                        double newH =
                            _lockAspect ? (newW * aspect) : panel.height;
                        newH = newH.clamp(_minPanelSize, maxH);

                        double newX = panel.x.clamp(
                            _pageMargin, _canvasWidth - newW - _pageMargin);
                        double newY = panel.y.clamp(
                            _pageMargin, _canvasHeight - newH - _pageMargin);

                        _applyResize(panel,
                            x: newX, y: newY, width: newW, height: newH);
                      },
                    ),
                  ),

                  // Height slider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: const [
                        Icon(Icons.swap_vert, size: 18),
                        SizedBox(width: 8),
                        Text('Height',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Slider(
                      min: _minPanelSize,
                      max: maxH,
                      value: panel.height.clamp(_minPanelSize, maxH),
                      onChanged: (v) {
                        double newH = v;
                        double newW =
                            _lockAspect ? (newH / aspect) : panel.width;
                        newW = newW.clamp(_minPanelSize, maxW);

                        double newY = panel.y.clamp(
                            _pageMargin, _canvasHeight - newH - _pageMargin);
                        double newX = panel.x.clamp(
                            _pageMargin, _canvasWidth - newW - _pageMargin);

                        _applyResize(panel,
                            x: newX, y: newY, width: newW, height: newH);
                      },
                    ),
                  ),

                  // Presets
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetChip('½ width', () {
                          final targetW = ((_canvasWidth - 3 * _pageMargin) / 2)
                              .clamp(_minPanelSize, maxW);
                          _applyResize(panel, width: targetW);
                        }),
                        _presetChip('⅓ width', () {
                          final targetW = ((_canvasWidth - 4 * _pageMargin) / 3)
                              .clamp(_minPanelSize, maxW);
                          _applyResize(panel, width: targetW);
                        }),
                        _presetChip('Square', () {
                          final side = min(maxW, maxH)
                              .clamp(_minPanelSize, double.infinity);
                          _applyResize(panel, width: side, height: side);
                        }),
                        _presetChip('Fit width', () {
                          final targetW = (_canvasWidth - 2 * _pageMargin)
                              .clamp(_minPanelSize, maxW);
                          _applyResize(panel, width: targetW);
                        }),
                        _presetChip('Fit height', () {
                          final targetH = (_canvasHeight - 2 * _pageMargin)
                              .clamp(_minPanelSize, maxH);
                          _applyResize(panel, height: targetH);
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Centralized resize apply with clamp + overlap check
  void _applyResize(
    LayoutPanel panel, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    final double maxW = _canvasWidth - 2 * _pageMargin;
    final double maxH = _canvasHeight - 2 * _pageMargin;

    double newW = (width ?? panel.width).clamp(_minPanelSize, maxW);
    double newH = (height ?? panel.height).clamp(_minPanelSize, maxH);

    double newX =
        (x ?? panel.x).clamp(_pageMargin, _canvasWidth - newW - _pageMargin);
    double newY =
        (y ?? panel.y).clamp(_pageMargin, _canvasHeight - newH - _pageMargin);

    final resized = panel.copyWith(x: newX, y: newY, width: newW, height: newH);
    if (!_isOverlapping(resized, excludePanel: panel)) {
      _mutate(() {
        final idx = pages[_currentPage].indexWhere((p) => p.id == panel.id);
        if (idx != -1) {
          pages[_currentPage][idx] = resized;
          if (selectedPanel?.id == panel.id) selectedPanel = resized;
        }
      });
    }
  }

  void _addPage() {
    _mutate(() {
      /*final newPage = [
        LayoutPanel(
          id: DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),
          width: _canvasWidth * 0.3,
          height: _canvasHeight * 0.2,
          x: _pageMargin,
          y: _pageMargin,
          customText: 'Page ${currentProject.pages.length + 1} Panel',
          backgroundColor: Colors.white,
        ),
      ];*/
      final newPage = <LayoutPanel>[];

      currentProject = currentProject.copyWith(
        pages: [...currentProject.pages, newPage],
        lastModified: DateTime.now(),
      );
      pages = List.from(currentProject.pages);
      currentPageIndex = pages.length - 1;
      _currentPage = currentPageIndex;
    });
  }

  void _toggleDrawer(bool open) {
    setState(() => isDrawerOpen = open);
  }

  void _editSelectedPanel() async {
    if (selectedPanel == null) return;
    final actualPanel =
    pages[_currentPage].firstWhere((p) => p.id == selectedPanel!.id);

    final panelForEditing = actualPanel.toComicPanel();

    final updatedPanel = await Navigator.push<ComicPanel>(
      context,
      MaterialPageRoute(
        builder: (context) => PanelEditScreen(
          panel: panelForEditing,
          panelOffset: Offset(actualPanel.x, actualPanel.y),
          panelSize: Size(actualPanel.width, actualPanel.height),
          onAutosave: (p) {
            // 🔴 IMPORTANT: write-through to your project model on every autosave
            _mutate(() {
              final index = pages[_currentPage]
                  .indexWhere((pl) => pl.id == actualPanel.id);
              if (index != -1) {
                pages[_currentPage][index] =
                    actualPanel.updateFromComicPanel(p);
                selectedPanel = pages[_currentPage][index];

                final updatedPages =
                List<List<LayoutPanel>>.from(currentProject.pages);
                updatedPages[_currentPage] =
                List<LayoutPanel>.from(pages[_currentPage]);

                currentProject = currentProject.copyWith(
                  pages: updatedPages,
                  lastModified: DateTime.now(),
                );
              }
            });
          },
        ),
      ),
    );

    // User tapped Save: also apply final returned panel
    if (updatedPanel != null) {
      _mutate(() {
        final index = pages[_currentPage]
            .indexWhere((p) => p.id == selectedPanel!.id);
        if (index != -1) {
          pages[_currentPage][index] =
              actualPanel.updateFromComicPanel(updatedPanel);
          selectedPanel = pages[_currentPage][index];

          final updatedPages =
          List<List<LayoutPanel>>.from(currentProject.pages);
          updatedPages[_currentPage] =
          List<LayoutPanel>.from(pages[_currentPage]);

          currentProject = currentProject.copyWith(
            pages: updatedPages,
            lastModified: DateTime.now(),
          );
        }
      });
    }
  }


/*
  void _editSelectedPanel() async {
    if (selectedPanel == null) return;
    final actualPanel =
        pages[_currentPage].firstWhere((p) => p.id == selectedPanel!.id);
    for (int i = 0; i < actualPanel.elements.length; i++) {
      final element = actualPanel.elements[i];
    }
    var panelForEditing = actualPanel.toComicPanel();

    final updatedPanel = await Navigator.push<ComicPanel>(
      context,
      MaterialPageRoute(
        builder: (context) => PanelEditScreen(
          panel: panelForEditing,
          panelOffset: Offset(actualPanel.x, actualPanel.y),
          panelSize: Size(actualPanel.width, actualPanel.height),
          onAutosave: (p) {
            setState(() => panelForEditing = p);          // keep parent model in sync
            // also persist to your DB if you have one
            // await repo.save(p);
          },
        ),
      ),
    );

    if (updatedPanel != null) {
      _mutate(() {
        final index = pages[_currentPage].indexWhere(
          (p) => p.id == selectedPanel!.id,
        );
        if (index != -1) {
          pages[_currentPage][index] =
              actualPanel.updateFromComicPanel(updatedPanel);
          selectedPanel = pages[_currentPage][index];
          final updatedPages =
              List<List<LayoutPanel>>.from(currentProject.pages);
          updatedPages[_currentPage] =
              List<LayoutPanel>.from(pages[_currentPage]);
          currentProject = currentProject.copyWith(
            pages: updatedPages,
            lastModified: DateTime.now(),
          );
        }
      });
    }
  }
*/

  void _saveAsDraft() async {
    final box = Hive.box<ProjectHiveModel>('drafts');
    final updatedProject = currentProject.copyWith(
      pages: pages,
      lastModified: DateTime.now(),
    );
    for (int pageIndex = 0;
        pageIndex < updatedProject.pages.length;
        pageIndex++) {
      final page = updatedProject.pages[pageIndex];
      for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
        final panel = page[panelIndex];
        for (int elementIndex = 0;
            elementIndex < panel.elements.length;
            elementIndex++) {
          final element = panel.elements[elementIndex];
        }
      }
    }
    final hiveModel = toHiveModel(updatedProject);
    await box.put(updatedProject.id, hiveModel);
    currentProject = updatedProject;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved the project for later!')),
    );
  }

  void _deleteSelectedPanel() {
    if (selectedPanel != null) {
      _mutate(() {
        pages[_currentPage].remove(selectedPanel);
        selectedPanel = null;
      });
    }
  }

  void _addSinglePanel() {
    final panelWidth =
        (_canvasWidth - (_pageMargin * 2)) / 2; // Two panels per row
    final panelHeight = _canvasHeight * 0.25;

    final newPanel = LayoutPanel(
      // id: "Panel_${DateTime.now().microsecondsSinceEpoch}", // Unique ID always
      id: "Panel ${pages[_currentPage].length + 1}",
      width: panelWidth,
      height: panelHeight,
      x: _pageMargin,
      y: _pageMargin,
      backgroundColor: Colors.white,
    );

    Offset? freePosition = _findFreePosition(newPanel);

    if (freePosition == null) {
      // No space available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No more space on this page. Add a new page."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    newPanel.x = freePosition.dx;
    newPanel.y = freePosition.dy;

    _mutate(() {
      pages[_currentPage].add(newPanel);
    });
  }

  bool get _canAddMorePanels {
    final panelWidth = (_canvasWidth - (_pageMargin * 2)) / 2;
    final panelHeight = _canvasHeight * 0.25;
    final testPanel = LayoutPanel(
      id: 'test',
      width: panelWidth,
      height: panelHeight,
      x: 0,
      y: 0,
      backgroundColor: Colors.white,
    );
    return _findFreePosition(testPanel) != null;
  }

  Offset? _findFreePosition(LayoutPanel panel) {
    const double rowSpacing = 20.0; // space between rows
    const int panelsPerRow = 2;

    final double horizontalSpacing = 0;
    final double panelWidth = panel.width;
    final double panelHeight = panel.height;

    final double maxX = _canvasWidth - _pageMargin - panelWidth;
    final double maxY = _canvasHeight - _pageMargin - panelHeight;

    for (double y = _pageMargin; y <= maxY; y += panelHeight + rowSpacing) {
      for (int i = 0; i < panelsPerRow; i++) {
        double x = _pageMargin + i * (panelWidth + horizontalSpacing);
        if (x > maxX) break;

        final testPanel = panel.copyWith(x: x, y: y);
        if (!_isOverlapping(testPanel)) {
          return Offset(x, y);
        }
      }
    }

    return null;
  }

/*  void _switchPage(int index) {
    setState(() {
      _currentPage = index;
      selectedPanel = null;
    });
  }*/

  // ---------- change this for Page Ra_arrangement ----------
  void _switchPage(int index) {
    setState(() {
      _currentPage = index;
      currentPageIndex = index; // keep this synced
      selectedPanel = null;
    });
  }

  // ---------- Page Ra_arrangement ----------

  void _showAllPagesPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllPagesPreviewScreen(
          pages: pages,
          projectName: currentProject.name,
          pageFormat: _selectedPageFormat,
        ),
      ),
    );
  }

  void _showLayoutTemplates() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Layout Templates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        // remove the text showing the  page format',
                        'Optimized for format',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildLayoutTemplate(
                      'Single Column',
                      'Full-width layout',
                      Icons.view_agenda,
                      Colors.blue,
                      _applySingleColumnLayout,
                    ),
                    _buildLayoutTemplate(
                      'Two Columns',
                      'Side-by-side panels',
                      Icons.view_column,
                      Colors.green,
                      _applyTwoColumnLayout,
                    ),
                    _buildLayoutTemplate(
                      'Three Columns',
                      'Triple column layout',
                      Icons.view_week,
                      Colors.orange,
                      _applyThreeColumnLayout,
                    ),
                    _buildLayoutTemplate(
                      'Two Rows',
                      'Top and bottom panels',
                      Icons.view_day,
                      Colors.brown,
                      _applyTwoRowLayout,
                    ),
                    _buildLayoutTemplate(
                      'Grid 2x2',
                      'Four equal panels',
                      Icons.grid_4x4,
                      Colors.purple,
                      _applyGrid2x2Layout,
                    ),
                    _buildLayoutTemplate(
                      'Header + Content',
                      'Title with body panels',
                      Icons.article,
                      Colors.red,
                      _applyHeaderContentLayout,
                    ),
                    _buildLayoutTemplate(
                      'Magazine Style',
                      'Mixed panel sizes',
                      Icons.auto_stories,
                      Colors.teal,
                      _applyMagazineLayout,
                    ),
                    _buildLayoutTemplate(
                      'Comic Strip',
                      'Horizontal sequence',
                      Icons.movie_filter,
                      Colors.indigo,
                      _applyComicStripLayout,
                    ),
                    _buildLayoutTemplate(
                      'Clear All',
                      'Remove all panels',
                      Icons.clear_all,
                      Colors.grey,
                      () {
                        setState(() {
                          pages[_currentPage].clear();
                          selectedPanel = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayoutTemplate(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          onTap();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applySingleColumnLayout() {
    final contentWidth = _canvasWidth - (2 * _pageMargin);
    final panelHeight = (_canvasHeight - (4 * _pageMargin)) / 3;

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Header Panel",
          x: _pageMargin,
          y: _pageMargin,
          width: contentWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Content Panel",
          x: _pageMargin,
          y: _pageMargin * 2 + panelHeight,
          width: contentWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Footer Panel",
          x: _pageMargin,
          y: _pageMargin * 3 + panelHeight * 2,
          width: contentWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyTwoColumnLayout() {
    final contentWidth = _canvasWidth - (3 * _pageMargin);
    final panelWidth = contentWidth / 2;
    final panelHeight = _canvasHeight - (2 * _pageMargin);

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Left Column",
          x: _pageMargin,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Right Column",
          x: _pageMargin * 2 + panelWidth,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyThreeColumnLayout() {
    final contentWidth = _canvasWidth - (4 * _pageMargin);
    final panelWidth = contentWidth / 3;
    final panelHeight = _canvasHeight - (2 * _pageMargin);

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Column 1",
          x: _pageMargin,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Column 2",
          x: _pageMargin * 2 + panelWidth,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Column 3",
          x: _pageMargin * 3 + panelWidth * 2,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyGrid2x2Layout() {
    final contentWidth = _canvasWidth - (3 * _pageMargin);
    final contentHeight = _canvasHeight - (3 * _pageMargin);
    final panelWidth = contentWidth / 2;
    final panelHeight = contentHeight / 2;

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Top Left",
          x: _pageMargin,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Top Right",
          x: _pageMargin * 2 + panelWidth,
          y: _pageMargin,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Bottom Left",
          x: _pageMargin,
          y: _pageMargin * 2 + panelHeight,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Bottom Right",
          x: _pageMargin * 2 + panelWidth,
          y: _pageMargin * 2 + panelHeight,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyHeaderContentLayout() {
    final contentWidth = _canvasWidth - (2 * _pageMargin);
    final headerHeight = _canvasHeight * 0.2;
    final contentHeight = _canvasHeight - headerHeight - (3 * _pageMargin);

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Header",
          x: _pageMargin,
          y: _pageMargin,
          width: contentWidth,
          height: headerHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Main Content",
          x: _pageMargin,
          y: _pageMargin * 2 + headerHeight,
          width: contentWidth,
          height: contentHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyComicStripLayout() {
    final contentWidth = _canvasWidth - (4 * _pageMargin);
    final panelWidth = contentWidth / 3;
    final panelHeight = _canvasHeight * 0.6;
    final startY = (_canvasHeight - panelHeight) / 2;

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Panel 1",
          x: _pageMargin,
          y: startY,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Panel 2",
          x: _pageMargin * 2 + panelWidth,
          y: startY,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Panel 3",
          x: _pageMargin * 3 + panelWidth * 2,
          y: startY,
          width: panelWidth,
          height: panelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyTwoRowLayout() {
    final contentWidth = _canvasWidth - (3 * _pageMargin);
    final topPanelHeight = _canvasHeight * 0.4;
    final bottomPanelHeight =
        _canvasHeight - topPanelHeight - (3 * _pageMargin);

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Top Panel",
          x: _pageMargin,
          y: _pageMargin,
          width: contentWidth,
          height: topPanelHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Bottom Panel",
          x: _pageMargin,
          y: topPanelHeight + (2 * _pageMargin),
          width: contentWidth,
          height: bottomPanelHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  void _applyMagazineLayout() {
    final contentWidth = _canvasWidth - (3 * _pageMargin);
    final leftPanelWidth = contentWidth * 0.6;
    final rightPanelWidth = contentWidth * 0.4;
    final topRightHeight = _canvasHeight * 0.3;
    final bottomRightHeight =
        _canvasHeight - topRightHeight - (3 * _pageMargin);

    _mutate(() {
      pages[_currentPage] = [
        LayoutPanel(
          id: "Main Article",
          x: _pageMargin,
          y: _pageMargin,
          width: leftPanelWidth,
          height: _canvasHeight - (2 * _pageMargin),
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Sidebar Top",
          x: _pageMargin + leftPanelWidth + _pageMargin,
          // corrected here
          y: _pageMargin,
          width: rightPanelWidth,
          height: topRightHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Sidebar Bottom",
          x: _pageMargin + leftPanelWidth + _pageMargin,
          // same fix
          y: _pageMargin + topRightHeight + _pageMargin,
          width: rightPanelWidth,
          height: bottomRightHeight,
          backgroundColor: Colors.white,
        ),
      ];
      selectedPanel = null;
    });
  }

  Widget _buildPanelContent(LayoutPanel panel) {
    return Container(
      width: panel.width,
      height: panel.height,
      decoration: BoxDecoration(
        border: Border.all(
          color: selectedPanel == panel
              ? Colors.blue
              : Colors.grey.withOpacity(0.3),
          width: selectedPanel == panel ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: selectedPanel == panel ? 6 : 2,
            offset: Offset(0, selectedPanel == panel ? 3 : 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: panel.previewImage != null
            ? Image.memory(
                panel.previewImage!,
                fit: BoxFit.cover,
                width: panel.width,
                height: panel.height,
              )
            : _buildLivePanelContent(panel),
      ),
    );
  }

  Widget _buildLivePanelContent(LayoutPanel panel) {
    if (kDebugMode) {
      print("Panel: ${panel.label} ID: ${panel.id}");
    }
    return Container(
      color: panel.backgroundColor,
      child: Stack(
        children: [
          if (panel.elements.isEmpty && panel.customText == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /* Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 30,
                    color: Colors.grey[400],
                  ),*/
                  const SizedBox(height: 8),
                  Text(
                    panel.id ?? 'Empty Panel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  /* const SizedBox(height: 4),
                  Text(
                    'Tap to select',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),*/
                ],
              ),
            ),
          if (panel.customText != null)
            Center(
              child: Text(
                panel.customText!,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageMarginsOverlay() {
    if (!_showPageMargins) return Container();

    return CustomPaint(
      size: Size(_canvasWidth, _canvasHeight),
      painter: PageMarginsPainter(
        marginSize: _pageMargin,
        pageWidth: _canvasWidth,
        pageHeight: _canvasHeight,
      ),
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(
      size: Size(_canvasWidth, _canvasHeight),
      painter: GridPainter(),
    );
  }

  Widget _buildFloatingEditButton() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).size.height * 0.4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _editSelectedPanel,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 28),
                  SizedBox(height: 6),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    selectedPanel!.id,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); //
    _autosaveTimer?.cancel();
    _flushAutosaveNow();
    Navigator.of(context).pop(currentProject); // your existing line
    super.dispose();
  }

  bool _isOverlapping(LayoutPanel newPanel, {LayoutPanel? excludePanel}) {
    return pages[_currentPage].any((panel) {
      if (panel == excludePanel) return false;
      return !(newPanel.x + newPanel.width <= panel.x ||
          newPanel.x >= panel.x + panel.width ||
          newPanel.y + newPanel.height <= panel.y ||
          newPanel.y >= panel.y + panel.height);
    });
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          /*     const SizedBox(width: 8),
          _buildSaveStatusPill(), // status*/
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: Icons.download,
            label: 'Export',
            onPressed: _showExportOptions,
          ),
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: Icons.remove_red_eye,
            label: 'Preview',
            onPressed: _showAllPagesPreview,
          ),
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: _showPageMargins ? Icons.pages_outlined : Icons.pages,
            label: _showPageMargins ? 'Hide Margin' : 'Show Margin',
            onPressed: () {
              _mutate(() {
                _showPageMargins = !_showPageMargins;
              });
            },
          ),
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: _showGrid ? Icons.grid_off : Icons.grid_on,
            label: _showGrid ? 'Hide Grid' : 'Show Grid',
            onPressed: () {
              _mutate(() {
                _showGrid = !_showGrid;
              });
            },
          ),
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: Icons.dashboard_customize,
            label: 'Layouts',
            onPressed: _showLayoutTemplates,
          ),
          SizedBox(width: 8),
          _buildAppBarButton(
            icon: Icons.add_box,
            label: 'Add Page',
            onPressed: _addPage,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  _buildDraggablePanel(
      {required MaterialColor color,
      required String label,
      required double width,
      required double height}) {
    final layoutPanel = LayoutPanel(
      id: '$label ${pages[_currentPage].length + 1}',
      label: label,
      width: width,
      height: height,
      x: 0,
      y: 0,
      backgroundColor: Colors.white,
      customText: label,
    );
    return Draggable<LayoutPanel>(
      onDragStarted: () {
        if (isDrawerOpen) {
          setState(() {
            isDrawerOpen = false;
          });
        }
      },
      data: layoutPanel,
      feedback: Material(
        color: Colors.transparent,
        child: _buildPanelPreview(label, color, width, height, scale: 0.2),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildPanelPreview(label, color, width, height, scale: 0.25),
      ),
      child: _buildPanelPreview(label, color, width, height, scale: 0.25),
    );
  }

  Widget _buildPanelPreview(
    String label,
    Color color,
    double width,
    double height, {
    double scale = 1.0,
  }) {
    final visualWidth = width * scale;
    final visualHeight = height * scale;

    return Container(
      width: visualWidth.clamp(60.0, 140.0),
      height: visualHeight.clamp(40.0, 120.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDrawerToggle() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: isDrawerOpen ? 150 : 0,
      child: GestureDetector(
        onTap: () => _toggleDrawer(!isDrawerOpen),
        child: Container(
          width: 30,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(
            isDrawerOpen ? Icons.arrow_left : Icons.arrow_right,
            size: 20,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPages() {
    return Container(
      color: Colors.grey.shade200,
      child: Row(
        children: [
          Expanded( // ensures the pager stays centered regardless of future widgets
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Pages:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0 ? () => _switchPage(_currentPage - 1) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentPage + 1} of ${pages.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < pages.length - 1
                        ? () => _switchPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- change this for Page Ra_arrangement ----------
/*
  Widget _buildFooter() {
    return Container(
      color: Colors.grey.shade200,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _canAddMorePanels ? _addSinglePanel : null,
                  icon: Icon(Icons.add, size: 18),
                  label: Text("Add Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canAddMorePanels ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: selectedPanel != null ? _editSelectedPanel : null,
                  icon: Icon(Icons.edit, size: 18),
                  label: Text("Edit Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedPanel != null ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      selectedPanel != null ? _deleteSelectedPanel : null,
                  icon: Icon(Icons.delete, size: 18),
                  label: Text("Delete Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedPanel != null ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showLayoutTemplates,
                  icon: Icon(Icons.dashboard_customize, size: 18),
                  label: Text("Layout Templates"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _saveAsDraft();
                  },
                  icon: Icon(Icons.save),
                  label: Text("Save"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: pages.length > 1
                      ? () {
                    _mutate(() {
                            pages.removeAt(_currentPage);
                            if (_currentPage > 0) _currentPage--;
                            currentProject = currentProject.copyWith(
                              pages: pages,
                              lastModified: DateTime.now(),
                            );
                          });
                        }
                      : null,
                  icon: Icon(Icons.delete_forever),
                  label: Text("Delete Page"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        pages.length > 1 ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
*/

  Widget _buildFooter() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPages(),
          const SizedBox(height: 2),

          // === Re-order-able thumbnails strip (toggle visibility) ===
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _showReorderStrip
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pages.length + 1, // include the end drop target
                itemBuilder: (context, i) {
                  if (i == pages.length) return _buildEndDropTarget();
                  return _buildReorderablePageThumb(i);
                },
              ),
            ),
            secondChild: const SizedBox.shrink(), // hidden state
          ),

          // (Optional) small hint when visible
          if (_showReorderStrip) ...[
            const SizedBox(height: 4),
            const Text(
              'Drag thumbnails to reorder pages',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageActionButtons() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // === Your original buttons row ===
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _canAddMorePanels ? _addSinglePanel : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canAddMorePanels ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: selectedPanel != null ? _editSelectedPanel : null,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedPanel != null ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      selectedPanel != null ? _deleteSelectedPanel : null,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text("Delete Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedPanel != null ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showLayoutTemplates,
                  icon: const Icon(Icons.dashboard_customize, size: 18),
                  label: const Text("Layout Templates"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _saveAsDraft,
                  icon: const Icon(Icons.save),
                  label: const Text("Save"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: pages.length > 1
                      ? () {
                          _mutate(() {
                            pages.removeAt(_currentPage);
                            if (_currentPage > 0) _currentPage--;
                            currentPageIndex = _currentPage;
                            currentProject = currentProject.copyWith(
                              pages: pages,
                              lastModified: DateTime.now(),
                            );
                          });
                        }
                      : null,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete Page"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        pages.length > 1 ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- change this for Page Ra_arrangement ----------

  void _showExportOptions() {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await _generatePdfFromWidget(),
    );
  }

  Future<Uint8List> _generatePdfFromWidget() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Preview widget not found");

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final decoded = await decodeImageFromList(pngBytes);
      print("Image size: ${decoded.width} x ${decoded.height}");

      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(pngBytes);

      final pageSize = PdfPageFormat(
        _canvasWidth,
        _canvasHeight,
        marginAll: 0,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageSize, // Use A4 page format
          build: (context) => pw.Center(
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.cover,
            ),
          ),
        ),
      );

      return pdf.save();
    } catch (e) {
      print("Error generating PDF: $e");
      rethrow;
    }
  }

  Widget _buildFloatingDrawerWithToggle(
    double screenHeight,
    double drawerWidth,
    double drawerHeight,
  ) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      left: isDrawerOpen ? 0 : -drawerWidth,
      top: _drawerTopOffset.clamp(0.0, screenHeight - drawerHeight),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _drawerTopOffset += details.delta.dy;
            _drawerTopOffset =
                _drawerTopOffset.clamp(0.0, screenHeight - drawerHeight);
          });
        },
        child: Stack(
          children: [
            Material(
              elevation: 6,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Container(
                width: drawerWidth,
                height: drawerHeight,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                padding: EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Created Panels',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      _buildDraggablePanel(
                        color: Colors.red,
                        label: 'Wide',
                        width: _canvasWidth - 2 * _pageMargin,
                        height: _canvasHeight * 0.2,
                      ),
                      SizedBox(height: 12),
                      _buildDraggablePanel(
                        color: Colors.teal,
                        label: 'Two Half',
                        width: (_canvasWidth - 2 * _pageMargin) / 2,
                        height: _canvasHeight * 0.2,
                      ),
                      SizedBox(height: 12),
                      _buildDraggablePanel(
                        color: Colors.green,
                        label: 'Tall',
                        width: _canvasWidth * 0.35,
                        height: _canvasHeight * 0.5,
                      ),
                      SizedBox(height: 12),
                      _buildDraggablePanel(
                        color: Colors.orange,
                        label: 'Square',
                        width: _canvasWidth * 0.4,
                        height: _canvasWidth * 0.4,
                      ),
                      SizedBox(height: 12),
                      _buildDraggablePanel(
                        color: Colors.purple,
                        label: 'Small',
                        width: _canvasWidth * 0.25,
                        height: _canvasHeight * 0.12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======= Your existing panel builder with edge handles (unchanged except inspector stays) =======
  Widget _buildPanelWithResize(
      LayoutPanel panel, double scaleX, double scaleY) {
    final viewScale = min(scaleX, scaleY);

    return Positioned(
      left: panel.x * scaleX,
      top: panel.y * scaleY,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPanel = (selectedPanel?.id == panel.id)
                ? null
                : pages[_currentPage].firstWhere((p) => p.id == panel.id);
          });
        },
        onPanUpdate: (details) {
          double newX = panel.x + (details.delta.dx / scaleX);
          double newY = panel.y + (details.delta.dy / scaleY);

          if (_snapToGrid) {
            newX = (newX / 20).round() * 20.0;
            newY = (newY / 20).round() * 20.0;
          }

          newX =
              newX.clamp(_pageMargin, _canvasWidth - panel.width - _pageMargin);
          newY = newY.clamp(
              _pageMargin, _canvasHeight - panel.height - _pageMargin);

          final moved = panel.copyWith(x: newX, y: newY);
          if (!_isOverlapping(moved, excludePanel: panel)) {
            setState(() {
              final idx =
                  pages[_currentPage].indexWhere((p) => p.id == panel.id);
              if (idx != -1) {
                pages[_currentPage][idx] = moved;
                if (selectedPanel?.id == panel.id) selectedPanel = moved;
              }
            });
          }
        },
        child: Transform.scale(
          scale: viewScale,
          alignment: Alignment.topLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: panel.width,
                height: panel.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (selectedPanel?.id == panel.id)
                        ? Colors.blue
                        : Colors.grey.withOpacity(0.3),
                    width: (selectedPanel?.id == panel.id) ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: panel.previewImage != null
                      ? Image.memory(panel.previewImage!, fit: BoxFit.cover)
                      : _buildLivePanelContent(panel),
                ),
              ),
              if (selectedPanel?.id == panel.id) ...[
                _edgeHandle(panel, viewScale, Axis.horizontal, isStart: true),
                _edgeHandle(panel, viewScale, Axis.horizontal, isStart: false),
                _edgeHandle(panel, viewScale, Axis.vertical, isStart: true),
                _edgeHandle(panel, viewScale, Axis.vertical, isStart: false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelSizeControls(LayoutPanel panel, double viewScale) {
    /* not used now */ return const SizedBox.shrink();
  }

  Widget _edgeHandle(
    LayoutPanel panel,
    double viewScale,
    Axis axis, {
    required bool isStart,
  }) {
    const double barThickness = 6.0;
    const double hitThickness = 56.0;
    const double inset = 6.0;

    if (axis == Axis.horizontal) {
      return Positioned(
        left: isStart ? -hitThickness / 2 : panel.width - hitThickness / 2,
        top: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final dx = details.delta.dx / viewScale;
            double newX = panel.x, newW = panel.width;

            if (isStart) {
              newX = panel.x + dx;
              newW = panel.width - dx;
            } else {
              newW = panel.width + dx;
            }

            newW = max(newW, _minPanelSize);
            newX = newX.clamp(_pageMargin, _canvasWidth - newW - _pageMargin);

            if (_snapToGrid) {
              newX = (newX / 20).round() * 20.0;
              newW = (newW / 20).round() * 20.0;
            }

            final resized = panel.copyWith(x: newX, width: newW);
            if (!_isOverlapping(resized, excludePanel: panel)) {
              _mutate(() {
                final idx =
                    pages[_currentPage].indexWhere((p) => p.id == panel.id);
                if (idx != -1) {
                  pages[_currentPage][idx] = resized;
                  if (selectedPanel?.id == panel.id) selectedPanel = resized;
                }
              });
            }
          },
          child: SizedBox(
            width: hitThickness,
            height: panel.height,
            child: Center(
              child: Container(
                width: barThickness,
                height: panel.height - inset * 2,
                /*decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                ),*/
              ),
            ),
          ),
        ),
      );
    } else {
      return Positioned(
        top: isStart ? -hitThickness / 2 : panel.height - hitThickness / 2,
        left: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final dy = details.delta.dy / viewScale;
            double newY = panel.y, newH = panel.height;

            if (isStart) {
              newY = panel.y + dy;
              newH = panel.height - dy;
            } else {
              newH = panel.height + dy;
            }

            newH = max(newH, _minPanelSize);
            newY = newY.clamp(_pageMargin, _canvasHeight - newH - _pageMargin);

            if (_snapToGrid) {
              newY = (newY / 20).round() * 20.0;
              newH = (newH / 20).round() * 20.0;
            }

            final resized = panel.copyWith(y: newY, height: newH);
            if (!_isOverlapping(resized, excludePanel: panel)) {
              _mutate(() {
                final idx =
                    pages[_currentPage].indexWhere((p) => p.id == panel.id);
                if (idx != -1) {
                  pages[_currentPage][idx] = resized;
                  if (selectedPanel?.id == panel.id) selectedPanel = resized;
                }
              });
            }
          },
          // child: SizedBox(
          //   width: panel.width,
          //   height: hitThickness,
          //   child: Center(
          //     child: Container(
          //       height: barThickness,
          //       width: panel.width - inset * 2,
          //       decoration: BoxDecoration(
          //         color: Colors.blue.withOpacity(0.6),
          //         borderRadius: BorderRadius.circular(3),
          //       ),
          //     ),
          //   ),
          // ),
        ),
      );
    }
  }

  Widget _buildReorderToggleAction() {
    final canReorder = pages.length > 1;
    final label = _showReorderStrip ? 'Hide Reorder' : 'Reorder Pages';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: canReorder ? label : 'Need at least 2 pages',
        child: TextButton.icon(
          icon: const Icon(Icons.pages, size: 20),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: canReorder ? Colors.white : Colors.white54,
            backgroundColor: _showReorderStrip
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: canReorder
              ? () {
            setState(() {
              _showReorderStrip = !_showReorderStrip;
              _draggingPageIndex = null; // clear any drag state
              _hoveredPageIndex = null;
            });
          }
              : null,
        ),
      ),
    );
  }
}
