import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'Resizeable/GridPainter.dart';
import 'PreviewPdf/PageMarginsPainter.dart';
import 'PanelModel/Project.dart';
import 'PreviewPdf/AllPagesPreviewScreen.dart';
import 'PreviewPdf/file_export_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

// PDF Page Format Constants
class PDFPageFormat {
  static const double A4_WIDTH = 595.0; // A4 width in points
  static const double A4_HEIGHT = 842.0; // A4 height in points
  static const double LETTER_WIDTH = 612.0; // Letter width in points
  static const double LETTER_HEIGHT = 792.0; // Letter height in points
  static const double LEGAL_WIDTH = 612.0; // Legal width in points
  static const double LEGAL_HEIGHT = 1008.0; // Legal height in points

  // Display scaling factor to fit screen
  static const double DISPLAY_SCALE = 0.6;

  static Map<String, Size> get formats => {
        'A4': Size(A4_WIDTH * DISPLAY_SCALE, A4_HEIGHT * DISPLAY_SCALE),
      };

  static double get aspectRatioA4 => A4_WIDTH / A4_HEIGHT;

  static double get aspectRatioLetter => LETTER_WIDTH / LETTER_HEIGHT;

  static double get aspectRatioLegal => LEGAL_WIDTH / LEGAL_HEIGHT;
}

class TestPanelLayoutEditorScreen extends StatefulWidget {
  final Project project;

  const TestPanelLayoutEditorScreen({super.key, required this.project});

  @override
  State<TestPanelLayoutEditorScreen> createState() =>
      _TestPanelLayoutEditorScreenState();
}

class _TestPanelLayoutEditorScreenState extends State<TestPanelLayoutEditorScreen> {
  late Project currentProject;
  int currentPageIndex = 0;
  List<List<LayoutPanel>> pages = [[]];
  int _currentPage = 0;
  LayoutPanel? selectedPanel;
  final GlobalKey _canvasKey = GlobalKey();
  bool _showGrid = false;
  bool _snapToGrid = false;

  // PDF Page Settings
  String _selectedPageFormat = 'A4';
  bool _showPageMargins = false;
  double _pageMargin = 10.0;

  late List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    pages = List.from(widget.project.pages);
    debugPages();
  }

  // Get current page dimensions based on selected format
  Size get _currentPageSize => PDFPageFormat.formats[_selectedPageFormat]!;

  double get _canvasWidth => _currentPageSize.width;
  double get _canvasHeight => _currentPageSize.height;

  List<LayoutPanel> get currentPagePanels =>
      currentProject.pages.isNotEmpty ? currentProject.pages[currentPageIndex] : [];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: GestureDetector(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Center(
                    child: Container(
                      child: RepaintBoundary(
                        // ✅ Added
                        key: _canvasKey,
                        child: Container(
                          width: _canvasWidth,
                          height: _canvasHeight,
                          margin: const EdgeInsets.symmetric(vertical: 14),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                          ),
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
                                  y: (offset.dy - incoming.height / 2).clamp(
                                      _pageMargin,
                                      _canvasHeight -
                                          incoming.height -
                                          _pageMargin),
                                  backgroundColor: Colors.white,
                                );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Stack(
                                children: [
                                  if (_showGrid) _buildGridOverlay(),
                                  _buildPageMarginsOverlay(),
                                  if (pages[_currentPage].isEmpty)
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.description_outlined,
                                            size: 64,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
/*
                                            'Empty $_selectedPageFormat Page',
*/
                                            'Empty  Page',
                                            style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Add panels or choose a layout template',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          /*Text(
                                            '${_canvasWidth.toInt()} × ${_canvasHeight.toInt()} pts',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),*/
                                        ],
                                      ),
                                    ),
                                  ...pages[_currentPage].map((panel) {
                                    return Positioned(
                                      left: panel.x,
                                      top: panel.y,
                                      child: GestureDetector(
                                        /* onTap: () {
                                      setState(() {
                                        selectedPanel = selectedPanel == panel ? null : panel;
                                      });
                                    },*/

                                        onTap: () {
                                          setState(() {
                                            if (selectedPanel == panel) {
                                              selectedPanel = null;
                                            } else {
                                              // CRITICAL FIX: Ensure selectedPanel points to the actual panel in pages array
                                              final actualPanel =
                                              pages[_currentPage]
                                                  .firstWhere((p) =>
                                              p.id == panel.id);
                                              selectedPanel = actualPanel;
                                              print(
                                                  'Selected panel ${actualPanel.id} with ${actualPanel.elements.length} elements');
                                            }
                                          });
                                        },
                                        onPanUpdate: (details) {
                                          double newX =
                                              panel.x + details.delta.dx;
                                          double newY =
                                              panel.y + details.delta.dy;
                                          if (_snapToGrid) {
                                            newX = (newX / 20).round() * 20.0;
                                            newY = (newY / 20).round() * 20.0;
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

                                        },
                                        child: _buildPanelContent(panel),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildPages(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(LayoutPanel panel) {
    return Container(
      width: panel.width,
      height: panel.height,
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
    return Container(
      color: panel.backgroundColor,
      child: Stack(
        children: [
          if (panel.elements.isEmpty && panel.customText == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    panel.id,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
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

  void _switchPage(int index) {
    setState(() {
      _currentPage = index;
      selectedPanel = null;
    });
  }



  @override
  void dispose() {
    Navigator.of(context).pop(currentProject);
    super.dispose();
  }


  Widget _buildAppBar() {
    return Container(
      height: 60,
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              final updatedProject = currentProject.copyWith(
                pages: pages,
                lastModified: DateTime.now(),
              );
              Navigator.pop(context, updatedProject);
            },
            tooltip: 'Back to Projects',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentProject.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                /*Text(
                  '$_selectedPageFormat Format',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),*/
              ],
            ),
          ),
         /* SizedBox(width: 8),
          _buildAppBarButton(
            icon: Icons.download,
            label: 'Export',
            onPressed: _showExportOptions,
          ),*/
        ],
      ),
    );
  }

  Widget _buildPages() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 👈 Centers the Row content
        children: [
          const Text("Pages:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed:
                _currentPage > 0 ? () => _switchPage(_currentPage - 1) : null,
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
         /* const Spacer(),
          Text(
            '$_selectedPageFormat',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),*/
        ],
      ),
    );
  }

  void _showExportOptions() {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await _generatePdfFromWidget(),
    );
  }
  Future<Uint8List> _generatePdfFromWidget() async {
    final pdf = pw.Document();

    for (int i = 0; i < pages.length; i++) {
      final renderedWidget = _buildPageWidget(pages[i]); // 👈 Render each page

      final imageBytes = await _renderWidgetToImage(renderedWidget);
      final imageProvider = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return pdf.save();
  }

  Widget _buildPageWidget(List<LayoutPanel> pagePanels) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: _canvasWidth,
          height: _canvasHeight,
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.all(2),
          color: Colors.grey[200],
          child: Stack(
            children: [
              if (pagePanels.isEmpty)
                Center(
                  child: Text(
/*
                    'Empty $_selectedPageFormat Page',
*/
                    'Empty Page',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ...pagePanels.map((panel) {
                return Positioned(
                  left: panel.x,
                  top: panel.y,
                  child: Container(
                    width: panel.width,
                    height: panel.height,
                    child: panel.previewImage != null
                        ? Image.memory(
                      panel.previewImage!,
                      fit: BoxFit.cover,
                    )
                        : _buildLivePanelContent(panel),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _renderWidgetToImage(Widget widget) async {
    final repaintKey = GlobalKey();

    final overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: widget,
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    await Future.delayed(const Duration(milliseconds: 300));
    await WidgetsBinding.instance.endOfFrame;

    RenderRepaintBoundary? boundary;
    int retries = 0;
    while (retries < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) break;
      retries++;
    }

    if (boundary == null || boundary.debugNeedsPaint) {
      overlayEntry.remove();
      throw Exception("Widget is not fully painted after retries.");
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    overlayEntry.remove();

    return byteData!.buffer.asUint8List();
  }


  void debugPages(){
    // Add debugging
    print('=== TestPanelLayoutEditorScreen INIT ===');
    print('Project: ${currentProject.name}');
    print('Pages count: ${pages.length}');

    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      print('Page $pageIndex: ${page.length} panels');

      for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
        final panel = page[panelIndex];
        print('  Panel $panelIndex (${panel.id}): ${panel.elements.length} elements');

        for (int elementIndex = 0; elementIndex < panel.elements.length; elementIndex++) {
          final element = panel.elements[elementIndex];
          print('    Element $elementIndex: ${element.type} - "${element.value}"');
        }
      }
    }

  }
}