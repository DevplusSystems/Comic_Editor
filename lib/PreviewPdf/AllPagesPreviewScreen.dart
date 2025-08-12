import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../PanelModel/Project.dart';
import '../TestPanelLayoutEditorScreen.dart';
import 'PDFPageFormat.dart';


class AllPagesPreviewScreen extends StatefulWidget {
  final List<List<LayoutPanel>> pages;
  final String projectName;
  final String pageFormat;

  const AllPagesPreviewScreen({
    required this.pages,
    required this.projectName,
    required this.pageFormat,
  });

  @override
  _AllPagesPreviewScreenState createState() => _AllPagesPreviewScreenState();
}

class _AllPagesPreviewScreenState extends State<AllPagesPreviewScreen> {
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
        title: Text('${widget.projectName} - Preview'),
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
/*
                  'Page ${_currentPageIndex + 1} of ${widget.pages.length} • ${widget.pageFormat}',
*/
                  'Page ${_currentPageIndex + 1} of ${widget.pages.length} ',
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
/*
                                      'Empty ${widget.pageFormat} Page',
*/
                                      'Empty Page',
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

    for (int i = 0; i < _pageKeys.length; i++) {
      final boundary =
      _pageKeys[i].currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) continue;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final imageProvider = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(imageProvider),
          ),
        ),
      );
    }

    return pdf.save();
  }
}
