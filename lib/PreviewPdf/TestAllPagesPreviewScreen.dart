import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../PanelLayoutEditorScreen.dart';
import '../PanelModel/Project.dart';


class TestAllPagesPreviewScreen extends StatefulWidget {
  final List<List<LayoutPanel>> pages;
  final String projectName;
  final String pageFormat;

  const TestAllPagesPreviewScreen({
    required this.pages,
    required this.projectName,
    required this.pageFormat,
  });

  @override
  _TestAllPagesPreviewScreenState createState() => _TestAllPagesPreviewScreenState();
}

class _TestAllPagesPreviewScreenState extends State<TestAllPagesPreviewScreen> {
  PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    _pageKeys = List.generate(widget.pages.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    final pageSize = PDFPageFormat.formats[widget.pageFormat]!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.projectName} - ${widget.pageFormat} Preview'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _showExportOptions,
            tooltip: 'Export All Pages',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black,
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page ${_currentPageIndex + 1} of ${widget.pages.length} • ${widget.pageFormat}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              itemCount: widget.pages.length,
              itemBuilder: (context, pageIndex) {
                final page = widget.pages[pageIndex];
                return RepaintBoundary(
                  key: _pageKeys[pageIndex],
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: pageSize.width / pageSize.height,
                        child: Stack(
                          children: [
                            if (page.isEmpty)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Empty ${widget.pageFormat} Page',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...page.map((panel) {
                              return Positioned(
                                left: panel.x,
                                top: panel.y,
                                child: Container(
                                  width: panel.width,
                                  height: panel.height,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
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
                                        : Container(
                                      color: panel.backgroundColor,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 30,
                                              color: Colors.grey[400],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              panel.id,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontWeight:
                                                FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.black,
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPageIndex > 0
                      ? () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                  icon: Icon(Icons.arrow_back),
                  label: Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                  label: Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _currentPageIndex < widget.pages.length - 1
                      ? () {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                  icon: Icon(Icons.arrow_forward),
                  label: Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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
    final pageSize = PDFPageFormat.formats['A4']!; // use actual A4 size
    for (int i = 0; i < widget.pages.length; i++) {
      final repaintBoundary = GlobalKey();

      final widgetToRender = Material(
        type: MaterialType.transparency,
        child: Center(
          child: RepaintBoundary(
            key: repaintBoundary,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: pageSize.width / pageSize.height,
                  child: Stack(
                    children: [
                      if (widget.pages[i].isEmpty)
                        Center(child: Text("Empty Page")),
                      ...widget.pages[i].map((panel) {
                        return Positioned(
                          left: panel.x,
                          top: panel.y,
                          child: Container(
                            width: panel.width,
                            height: panel.height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: panel.previewImage != null
                                ? Image.memory(
                              panel.previewImage!,
                              fit: BoxFit.cover,
                              width: panel.width,
                              height: panel.height,
                            )
                                : Container(
                              color: panel.backgroundColor,
                              child: Center(child: Text(panel.id)),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final imageBytes = await _renderWidgetToImage(widgetToRender);
      final imageProvider = pw.MemoryImage(imageBytes);


      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero, // ✅ remove all margins
          build: (context) => pw.Container(
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.fill, // ✅ stretch image to fill entire A4 page
            ),
          ),
        ),
      );

    }

    return pdf.save();
  }
  Future<Uint8List> _renderWidgetToImage(Widget widget) async {
    final repaintKey = GlobalKey();

    final overlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: RepaintBoundary(
            key: repaintKey,
            child: widget,
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    if (overlay == null) throw Exception("Overlay not found");

    overlay.insert(overlayEntry);

    await Future.delayed(Duration(milliseconds: 300));
    await WidgetsBinding.instance.endOfFrame;

    RenderRepaintBoundary? boundary;
    int retries = 0;
    while (retries < 10) {
      await Future.delayed(Duration(milliseconds: 100));
      boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) break;
      retries++;
    }

    if (boundary == null || boundary.debugNeedsPaint) {
      overlayEntry.remove();
      throw Exception("Widget is not fully painted.");
    }

    final image = await boundary.toImage(pixelRatio: 5.0); // 👈 Use high resolution
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final decoded = await decodeImageFromList(pngBytes);
    print("🖼️ Rendered image size: ${decoded.width} x ${decoded.height}");

    overlayEntry.remove();

    return byteData!.buffer.asUint8List();
  }

}
