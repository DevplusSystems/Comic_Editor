import 'dart:io';
import 'dart:ui';

import 'package:comic_editor/project_hive_model.dart';
import 'package:comic_editor/project_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';

import 'Resizeable/GridPainter.dart';
import 'PreviewPdf/PageMarginsPainter.dart';
import 'PanelEditScreen.dart';
import 'PanelModel/PanelElementModel.dart';
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
        /*'Letter': Size(LETTER_WIDTH * DISPLAY_SCALE, LETTER_HEIGHT * DISPLAY_SCALE),
    'Legal': Size(LEGAL_WIDTH * DISPLAY_SCALE, LEGAL_HEIGHT * DISPLAY_SCALE),*/
      };

  static double get aspectRatioA4 => A4_WIDTH / A4_HEIGHT;

  static double get aspectRatioLetter => LETTER_WIDTH / LETTER_HEIGHT;

  static double get aspectRatioLegal => LEGAL_WIDTH / LEGAL_HEIGHT;
}

class PanelLayoutEditorScreen extends StatefulWidget {
  final Project project;

  const PanelLayoutEditorScreen({super.key, required this.project});

  @override
  State<PanelLayoutEditorScreen> createState() =>
      _PanelLayoutEditorScreenState();
}

class _PanelLayoutEditorScreenState extends State<PanelLayoutEditorScreen> {
  late Project currentProject;
  int currentPageIndex = 0;
  bool _isExporting = false;
  bool isDrawerOpen = false;
  List<List<LayoutPanel>> pages = [[]];
  int _currentPage = 0;
  LayoutPanel? selectedPanel;
  final GlobalKey _canvasKey = GlobalKey();
  bool _showGrid = false;
  bool _snapToGrid = false;

  // PDF Page Settings
  String _selectedPageFormat = 'A4';
  bool _showPageMargins = true;
  double _pageMargin = 10.0;

  late List<GlobalKey> _pageKeys;


/*  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    pages = List.from(widget.project.pages);
  }*/
  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    pages = List.from(widget.project.pages);

    // Add debugging
    print('=== PanelLayoutEditorScreen INIT ===');
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

  // Get current page dimensions based on selected format
  Size get _currentPageSize => PDFPageFormat.formats[_selectedPageFormat]!;

  double get _canvasWidth => _currentPageSize.width;
  double get _canvasHeight => _currentPageSize.height;

  List<LayoutPanel> get currentPagePanels =>
      currentProject.pages.isNotEmpty ? currentProject.pages[currentPageIndex] : [];

  void _addPage() {
    setState(() {
      final newPage = [
        LayoutPanel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          width: _canvasWidth * 0.3,
          height: _canvasHeight * 0.2,
          x: _pageMargin,
          y: _pageMargin,
          customText: 'Page ${currentProject.pages.length + 1} Panel',
          backgroundColor: Colors.white,
        ),
      ];
      currentProject = currentProject.copyWith(
        pages: [...currentProject.pages, newPage],
        lastModified: DateTime.now(),
      );
      pages = List.from(currentProject.pages);
      currentPageIndex = pages.length - 1;
      _currentPage = currentPageIndex;
    });
  }

  void _deletePanel(LayoutPanel panel) {
    setState(() {
      final updatedPages = List<List<LayoutPanel>>.from(currentProject.pages);
      updatedPages[currentPageIndex].removeWhere((p) => p.id == panel.id);
      currentProject = currentProject.copyWith(
        pages: updatedPages,
        lastModified: DateTime.now(),
      );
    });
  }

  void _toggleDrawer(bool open) {
    setState(() => isDrawerOpen = open);
  }


  void _editSelectedPanel() async {
    if (selectedPanel == null) return;

    print('=== EDITING SELECTED PANEL ===');
    print('Selected panel ID: ${selectedPanel!.id}');

    // CRITICAL FIX: Always get the panel from the pages array, not selectedPanel
    final actualPanel = pages[_currentPage].firstWhere((p) => p.id == selectedPanel!.id);

    print('Selected panel elements count: ${selectedPanel!.elements.length}');
    print('Actual panel elements count: ${actualPanel.elements.length}');
    print('Are they the same object? ${identical(selectedPanel, actualPanel)}');

    // Debug each element in actual panel
    for (int i = 0; i < actualPanel.elements.length; i++) {
      final element = actualPanel.elements[i];
      print('Actual panel element $i: ${element.toString()}');
    }

    // Use actualPanel instead of selectedPanel for conversion
    final panelForEditing = actualPanel.toComicPanel();
    print('Comic panel created with ${panelForEditing.elements.length} elements');

    final updatedPanel = await Navigator.push<ComicPanel>(
      context,
      MaterialPageRoute(
        builder: (context) => PanelEditScreen(
          panel: panelForEditing,
          panelOffset: Offset(actualPanel.x, actualPanel.y),
        ),
      ),
    );

    if (updatedPanel != null) {
      print('=== PANEL UPDATED ===');
      print('Updated panel elements count: ${updatedPanel.elements.length}');

      setState(() {
        final index = pages[_currentPage].indexWhere(
              (p) => p.id == selectedPanel!.id,
        );
        if (index != -1) {
          // Update the panel in the pages array
          pages[_currentPage][index] = actualPanel.updateFromComicPanel(updatedPanel);

          // Update selectedPanel to point to the updated panel
          selectedPanel = pages[_currentPage][index];

          // Update currentProject
          final updatedPages = List<List<LayoutPanel>>.from(currentProject.pages);
          updatedPages[_currentPage] = List<LayoutPanel>.from(pages[_currentPage]);
          currentProject = currentProject.copyWith(
            pages: updatedPages,
            lastModified: DateTime.now(),
          );

          print('Panel updated successfully with ${pages[_currentPage][index].elements.length} elements');
        }
      });
    }
  }

// Update your _saveAsDraft method with better debugging
  void _saveAsDraft() async {

    final box = Hive.box<ProjectHiveModel>('drafts');
    final updatedProject = currentProject.copyWith(
      pages: pages,
      lastModified: DateTime.now(),
    );

    print('Project pages count: ${updatedProject.pages.length}');
    for (int pageIndex = 0; pageIndex < updatedProject.pages.length; pageIndex++) {
      final page = updatedProject.pages[pageIndex];
      print('Page $pageIndex has ${page.length} panels');
      for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
        final panel = page[panelIndex];
        print('Panel $panelIndex (${panel.id}) has ${panel.elements.length} elements');
        for (int elementIndex = 0; elementIndex < panel.elements.length; elementIndex++) {
          final element = panel.elements[elementIndex];
          print('  Element $elementIndex: ${element.type} - ${element.value}');
        }
      }
    }

    final hiveModel = toHiveModel(updatedProject);
    await box.put(updatedProject.id, hiveModel);

    // Update current project reference
    currentProject = updatedProject;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved to local storage!')),
    );
  }

/*
  void _editSelectedPanel() async {
    if (selectedPanel == null) return;
    final panelForEditing = selectedPanel!.toComicPanel();
    final updatedPanel = await Navigator.push<ComicPanel>(
      context,
      MaterialPageRoute(
        builder: (context) => PanelEditScreen(
          panel: panelForEditing,
          panelOffset: Offset(selectedPanel!.x, selectedPanel!.y),
        ),
      ),
    );
    if (updatedPanel != null) {
      setState(() {
        final index = pages[_currentPage].indexWhere(
              (p) => p.id == selectedPanel!.id,
        );
        if (index != -1) {
          pages[_currentPage][index] = selectedPanel!.updateFromComicPanel(updatedPanel);
        }
      });
    }
  }
*/

  void _deleteSelectedPanel() {
    if (selectedPanel != null) {
      setState(() {
        pages[_currentPage].remove(selectedPanel);
        selectedPanel = null;
      });
    }
  }

  void _addSinglePanel() {
    final newPanel = LayoutPanel(
      id: "Panel ${pages[_currentPage].length + 1}",
      width: _canvasWidth * 0.25,
      height: _canvasHeight * 0.2,
      x: _pageMargin,
      y: _pageMargin,
      backgroundColor: Colors.white,
    );

    Offset? freePosition = _findFreePosition(newPanel);
    if (freePosition != null) {
      newPanel.x = freePosition.dx;
      newPanel.y = freePosition.dy;
    }

    setState(() {
      pages[_currentPage].add(newPanel);
    });
  }

  Offset? _findFreePosition(LayoutPanel panel) {
    final maxX = _canvasWidth - panel.width - _pageMargin;
    final maxY = _canvasHeight - panel.height - _pageMargin;

    for (double y = _pageMargin; y < maxY; y += 50) {
      for (double x = _pageMargin; x < maxX; x += 50) {
        final testPanel = panel.copyWith(x: x, y: y);
        if (!_isOverlapping(testPanel)) {
          return Offset(x, y);
        }
      }
    }
    return null;
  }

  void _switchPage(int index) {
    setState(() {
      _currentPage = index;
      selectedPanel = null;
    });
  }

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

  void _showPageFormatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PDF Page Format',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...PDFPageFormat.formats.entries.map((entry) {
              final format = entry.key;
              final size = entry.value;
              return ListTile(
                leading: Icon(
                  Icons.description,
                  color:
                      _selectedPageFormat == format ? Colors.blue : Colors.grey,
                ),
                title: Text(format),
                subtitle:
                    Text('${size.width.toInt()} × ${size.height.toInt()} pts'),
                trailing: _selectedPageFormat == format
                    ? Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedPageFormat = format;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const Divider(),
            SwitchListTile(
              title: Text('Show Page Margins'),
              subtitle: Text('Display printable area guides'),
              value: _showPageMargins,
              onChanged: (value) {
                setState(() {
                  _showPageMargins = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

/*  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Current format: $_selectedPageFormat',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Export as PNG'),
              subtitle: Text('High-resolution $_selectedPageFormat format'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('PNG');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              subtitle: Text('Professional $_selectedPageFormat document'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('PDF');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              subtitle: const Text('Export project data'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('JSON');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAs(String format) async {
    setState(() {
      _isExporting = true;
    });
    try {
      switch (format) {
        case 'PNG':
          await FileExportService.exportAllPagesAsPNG(
            context: context,
            pages: pages,
            projectName: currentProject.name,
            canvasWidth: _canvasWidth,
            canvasHeight: _canvasHeight,
            pageFormat: _selectedPageFormat,
          );
          break;
        case 'PDF':
          await FileExportService.exportAllPagesAsPDF(
            context: context,
            pages: pages,
            projectName: currentProject.name,
            canvasWidth: _canvasWidth,
            canvasHeight: _canvasHeight,
            pageFormat: _selectedPageFormat,
          );
          break;
        case 'JSON':
          await FileExportService.exportProjectAsJSON(
            context: context,
            project: currentProject.copyWith(pages: pages),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }*/

  void _exportCurrentPageAsPNG() async {
    setState(() {
      _isExporting = true;
    });
    try {
      await FileExportService.exportAllPagesAsPNG(
        context: context,
        pages: [pages[_currentPage]],
        projectName: '${currentProject.name}_page_${_currentPage + 1}',
        canvasWidth: _canvasWidth,
        canvasHeight: _canvasHeight,
        pageFormat: _selectedPageFormat,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
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
                        'PDF Layout Templates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Optimized for $_selectedPageFormat format',
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
/*
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
*/

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

  // PDF-optimized layout templates
  void _applySingleColumnLayout() {
    final contentWidth = _canvasWidth - (2 * _pageMargin);
    final panelHeight = (_canvasHeight - (4 * _pageMargin)) / 3;

    setState(() {
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

    setState(() {
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

    setState(() {
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

    setState(() {
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

    setState(() {
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

    setState(() {
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
    final bottomPanelHeight = _canvasHeight - topPanelHeight - (3 * _pageMargin);

    setState(() {
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

    setState(() {
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
          x: _pageMargin + leftPanelWidth + _pageMargin, // ✅ corrected here
          y: _pageMargin,
          width: rightPanelWidth,
          height: topRightHeight,
          backgroundColor: Colors.white,
        ),
        LayoutPanel(
          id: "Sidebar Bottom",
          x: _pageMargin + leftPanelWidth + _pageMargin, // ✅ same fix
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double padding = 16;
    final double panelWidthLeft = screenWidth * 0.45;
    final double panelWidthRight = screenWidth * 0.45;
    final double panelHeightTall = (screenHeight - 3 * padding) / 2;
    final double panelHeightSmall = (screenHeight - 4 * padding) / 3;

    return Scaffold(
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
                            color: Colors.grey[200],
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
                                if (!_isOverlapping(newPanel)) {
                                  setState(() {
                                    pages[_currentPage].add(newPanel);
                                  });
                                }
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
                                            'Empty $_selectedPageFormat Page',
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
                                          Text(
                                            '${_canvasWidth.toInt()} × ${_canvasHeight.toInt()} pts',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
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
                                          final movedPanel =
                                              panel.copyWith(x: newX, y: newY);
                                          if (!_isOverlapping(movedPanel,
                                              excludePanel: panel)) {
                                            setState(() {
                                              panel.x = newX;
                                              panel.y = newY;
                                            });
                                          }
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
                _buildFooter(),
              ],
            ),
            _buildDrawer(screenWidth, screenHeight, padding, panelWidthLeft,
                panelWidthRight, panelHeightTall, panelHeightSmall),
            _buildDrawerToggle(),
            if (selectedPanel != null) _buildFloatingEditButton(),
          ],
        ),
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
    Navigator.of(context).pop(currentProject);
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
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
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
                Text(
                  '$_selectedPageFormat Format',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          _buildAppBarButton(
            icon: Icons.settings,
            label: 'Page Format',
            onPressed: _showPageFormatOptions,
          ),
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
            icon: _showGrid ? Icons.grid_off : Icons.grid_on,
            label: _showGrid ? 'Hide Grid' : 'Show Grid',
            onPressed: () {
              setState(() {
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

  Widget _buildDrawer(
      double screenWidth,
      double screenHeight,
      double padding,
      double panelWidthLeft,
      double panelWidthRight,
      double panelHeightTall,
      double panelHeightSmall) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      left: isDrawerOpen ? 0 : -150,
      top: 0,
      bottom: 0,
      child: Container(
        width: 150,
        color: Colors.blueGrey.shade100,
        padding: EdgeInsets.only(top: 60, left: 8, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('PDF Panels', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _buildDraggablePanel(Colors.red, 'Header', 0, 0, _canvasWidth * 0.3,
                _canvasHeight * 0.15),
            SizedBox(height: 10),
            _buildDraggablePanel(Colors.green, 'Content', 0, 0,
                _canvasWidth * 0.25, _canvasHeight * 0.2),
            SizedBox(height: 10),
            _buildDraggablePanel(Colors.blue, 'Sidebar', 0, 0,
                _canvasWidth * 0.2, _canvasHeight * 0.3),
            SizedBox(height: 10),
            _buildDraggablePanel(Colors.orange, 'Footer', 0, 0,
                _canvasWidth * 0.3, _canvasHeight * 0.1),
            SizedBox(height: 10),
            _buildDraggablePanel(Colors.purple, 'Image', 0, 0,
                _canvasWidth * 0.25, _canvasHeight * 0.25),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
          const Spacer(),
          Text(
            '$_selectedPageFormat',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
         /* Row(
            children: [
              Checkbox(
                value: _snapToGrid,
                onChanged: (value) {
                  setState(() {
                    _snapToGrid = value ?? false;
                  });
                },
              ),
              Text('Snap to Grid', style: TextStyle(fontSize: 12)),
            ],
          ),*/
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.grey.shade200,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addSinglePanel,
                  icon: Icon(Icons.add, size: 18),
                  label: Text("Add Panel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showLayoutTemplates,
                  icon: Icon(Icons.dashboard_customize, size: 18),
                  label: Text("PDF Templates"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _exportCurrentPageAsPNG,
                  icon: Icon(Icons.photo_camera, size: 18),
                  label: Text("Export Page"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  label: Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedPanel != null ? Colors.red : Colors.grey,
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
                  label: Text("Save as Draft"),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: pages.length > 1
                      ? () {
                          setState(() {
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
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (selectedPanel != null)
                Text(
                  'Selected: ${selectedPanel!.id}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              if (selectedPanel == null)
                Text(
                  'No panel selected',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              Text(
                '${pages[_currentPage].length} panel${pages[_currentPage].length != 1 ? 's' : ''} • $_selectedPageFormat',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

/*
  void _saveAsDraft() async {
    final box = Hive.box<ProjectHiveModel>('drafts');
    final updatedProject = currentProject.copyWith(
      pages: pages,
      lastModified: DateTime.now(),
    );
    final hiveModel = toHiveModel(updatedProject);
    await box.put(updatedProject.id, hiveModel);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved to local storage!')),
    );
  }
*/

  Widget _buildDraggablePanel(Color color, String label, double xx, double yy,
      double width, double height) {
    return Draggable<LayoutPanel>(
      data: LayoutPanel(
        id: label,
        width: width,
        height: height,
        x: xx,
        y: yy,
        backgroundColor: Colors.white,
      ),
      feedback: Container(
        width: width * 0.3,
        height: height * 0.3,
        decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10),
            ),
          ),
        ),
      ),
      child: Container(
        width: 100,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await _generatePdfFromWidget(),
    );
  }
  Future<Uint8List> _generatePdfFromWidget() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Preview widget not found");

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();


      final decoded = await decodeImageFromList(pngBytes);
      print("🖼️ Image size: ${decoded.width} x ${decoded.height}");

      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4, // ✅ Set A4 explicitly
          build: (context) => pw.Center(
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.cover, // or contain/fitHeight
              width: PdfPageFormat.a4.width,
              height: PdfPageFormat.a4.height,
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




  /*Future<Uint8List> generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text("Hello PDF!", style: pw.TextStyle(fontSize: 40)),
        ),
      ),
    );

    return pdf.save();
  }*/
}

/*
Widget _buildExportOption({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _exportCurrentPage() async {
  await FileExportService.exportCurrentPageAsPNG(
    context: context,
    canvasKey: _canvasKey,
    projectName: currentProject.name,
    pageNumber: _currentPage + 1,
  );
}

Future<void> _exportAllPages() async {
  await FileExportService.exportAllPagesAsPNG(
    context: context,
    pages: pages,
    projectName: currentProject.name,
  );
}

Future<void> _exportAsPDF() async {
  await FileExportService.exportAsPDF(
    context: context,
    pages: pages,
    projectName: currentProject.name,
  );
}

Future<void> _exportProject() async {
  await FileExportService.exportProjectData(
    context: context,
    project: currentProject.copyWith(pages: pages),
  );
}
*/
