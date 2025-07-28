import 'dart:math' as math;

import 'package:comic_editor/PanelModel/PanelElementModel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:device_info_plus/device_info_plus.dart';


import '../PanelModel/Project.dart';

class FileExportService {
  static const String _appFolderName = 'ComicPanelEditor';
  static const String _exportFolderName = 'Exports';

  // Request proper permissions based on Android version
  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ - Request photos permission for media files
        final photos = await Permission.photos.request();
        final storage = await Permission.storage.request();
        return photos.isGranted || storage.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 - Request manage external storage
        final manageStorage = await Permission.manageExternalStorage.request();
        if (manageStorage.isGranted) return true;

        final storage = await Permission.storage.request();
        return storage.isGranted;
      } else {
        // Android 10 and below
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    return true; // iOS doesn't need explicit permissions for app documents
  }

  // Create proper directory structure
  static Future<Directory> _getExportDirectory() async {
    Directory? baseDirectory;

    if (Platform.isAndroid) {
      try {
        // Try to use external storage first (visible in file manager)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          baseDirectory = Directory('${externalDir.path}/$_appFolderName/$_exportFolderName');
        }
      } catch (e) {
        print('External storage not available: $e');
      }

      // Fallback to app documents directory
      if (baseDirectory == null) {
        final appDir = await getApplicationDocumentsDirectory();
        baseDirectory = Directory('${appDir.path}/$_appFolderName/$_exportFolderName');
      }
    } else {
      // iOS - use documents directory
      final appDir = await getApplicationDocumentsDirectory();
      baseDirectory = Directory('${appDir.path}/$_appFolderName/$_exportFolderName');
    }

    // Create directory if it doesn't exist
    if (!await baseDirectory.exists()) {
      await baseDirectory.create(recursive: true);
    }

    return baseDirectory;
  }

  static List<LayoutPanel> _scaleUpPanelsForExport(
      List<LayoutPanel> panels,
      double displayScale,
      double targetWidth,
      double targetHeight,
      double currentWidth,
      double currentHeight,
      ) {
    if (panels.isEmpty) return panels;

    // 1. Get panel bounds
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final panel in panels) {
      minX = math.min(minX, panel.x);
      minY = math.min(minY, panel.y);
      maxX = math.max(maxX, panel.x + panel.width);
      maxY = math.max(maxY, panel.y + panel.height);
    }

    final layoutWidth = maxX - minX;
    final layoutHeight = maxY - minY;

    // 2. Fit proportionally inside target canvas
    final scaleX = targetWidth / layoutWidth;
    final scaleY = targetHeight / layoutHeight;
    final scale = math.min(scaleX, scaleY);

    // 3. Compute new offset to center
    final scaledWidth = layoutWidth * scale;
    final scaledHeight = layoutHeight * scale;

    // Center the layout regardless of panel positions
    final offsetX = (targetWidth - layoutWidth * scale) / 2 - minX * scale;
    final offsetY = (targetHeight - layoutHeight * scale) / 2 - minY * scale;



    // 4. Transform each panel
    return panels.map((panel) {
      return LayoutPanel(
        id: panel.id,
        x: ((panel.x - minX) * scale) + offsetX,
        y: ((panel.y - minY) * scale) + offsetY,
        width: panel.width * scale,
        height: panel.height * scale,
        backgroundColor: panel.backgroundColor,
        customText: panel.customText,
        previewImage: panel.previewImage,
        elements: panel.elements.map((element) {
          return PanelElementModel(
            id: element.id,
            type: element.type,
            value: element.value,
            offset: Offset(
              element.offset.dx * scale,
              element.offset.dy * scale,
            ),
            width: element.width * scale,
            height: element.height * scale,
            color: element.color,
            fontSize: element.fontSize != null ? element.fontSize! * scale : null,
          );
        }).toList(),
      );
    }).toList();


  }


  static Future<Uint8List> _renderPageAsImage(
      List<LayoutPanel> panels,
      double canvasWidth,
      double canvasHeight, {
        double pixelRatio = 3.0,
      }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    // 1. White background
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), backgroundPaint);

    // 2. Get bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final panel in panels) {
      minX = math.min(minX, panel.x);
      minY = math.min(minY, panel.y);
      maxX = math.max(maxX, panel.x + panel.width);
      maxY = math.max(maxY, panel.y + panel.height);
    }

    final layoutWidth = maxX - minX;
    final layoutHeight = maxY - minY;

    // 3. Scale & Center
    final scale = math.min(canvasWidth / layoutWidth, canvasHeight / layoutHeight);
    final offsetX = (canvasWidth - layoutWidth * scale) / 2;
    final offsetY = (canvasHeight - layoutHeight * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // 4. Draw all panels relative to top-left of layout
    for (final panel in panels) {
      final shiftedPanel = panel.copyWith(
        x: panel.x - minX,
        y: panel.y - minY,
      );
      await _drawPanel(canvas, shiftedPanel);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (canvasWidth * pixelRatio).toInt(),
      (canvasHeight * pixelRatio).toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }


  // Draw individual panel on canvas
  static Future<void> _drawPanel(Canvas canvas, LayoutPanel panel) async {
    // Draw panel background
    final backgroundPaint = Paint()..color = panel.backgroundColor;
    final panelRect = Rect.fromLTWH(panel.x, panel.y, panel.width, panel.height);
    canvas.drawRect(panelRect, backgroundPaint);

    // Draw panel border
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(panelRect, Radius.circular(8)),
        borderPaint
    );

    // Draw panel shadow
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            panelRect.translate(2, 2),
            Radius.circular(8)
        ),
        shadowPaint
    );

    // Draw panel content
    if (panel.previewImage != null) {
      // If panel has preview image, draw it
      final codec = await ui.instantiateImageCodec(panel.previewImage!);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        panelRect,
        Paint(),
      );
    } else {
      // Draw panel text or placeholder
      final textToShow = panel.customText ?? panel.id;
      final textPainter = TextPainter(
        text: TextSpan(
          text: textToShow,
          style: TextStyle(
            color: Colors.black87,
            fontSize: _calculateFontSize(panel.width, panel.height),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: panel.width - 20);

      // Center the text in the panel
      final textOffset = Offset(
        panel.x + (panel.width - textPainter.width) / 2,
        panel.y + (panel.height - textPainter.height) / 2,
      );

      textPainter.paint(canvas, textOffset);
    }

    // Draw panel elements if any
    for (final element in panel.elements) {
      await _drawPanelElement(canvas, element, panel);
    }
  }

  // Draw individual panel elements
  static Future<void> _drawPanelElement(
      Canvas canvas,
      PanelElementModel element,
      LayoutPanel panel
      ) async {
    final elementX = panel.x + element.offset.dx;
    final elementY = panel.y + element.offset.dy;

    switch (element.type) {
      case 'text':
        final textPainter = TextPainter(
          text: TextSpan(
            text: element.value,
            style: TextStyle(
              color: element.color ?? Colors.black,
              fontSize: element.fontSize ?? 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(elementX, elementY));
        break;

      case 'shape':
        final paint = Paint()..color = element.color ?? Colors.black;
        canvas.drawRect(
          Rect.fromLTWH(elementX, elementY, element.width, element.height),
          paint,
        );
        break;

    // Add more element types as needed
    }
  }

  // Calculate appropriate font size based on panel dimensions
  static double _calculateFontSize(double width, double height) {
    final minDimension = width < height ? width : height;
    return (minDimension / 10).clamp(12.0, 24.0);
  }

  // Export all pages as PNG files with proper scaling to actual PDF formats
  static Future<List<String>> exportAllPagesAsPNG({
    required BuildContext context,
    required List<List<LayoutPanel>> pages,
    required String projectName,
    double canvasWidth = 800,
    double canvasHeight = 600,
    String pageFormat = 'A4',
  }) async
  {
    try {
      _showLoadingDialog(context, 'Exporting pages as PNG ($pageFormat format)...');

      // Request permissions
      if (!await _requestPermissions()) {
        Navigator.pop(context);
        _showErrorDialog(context, 'Storage permission is required to export files.');
        return [];
      }

      // Get export directory
      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(projectName);

      List<String> exportedFiles = [];

      // Create project subfolder
      final projectDir = Directory('${exportDir.path}/${sanitizedName}_$timestamp');
      await projectDir.create(recursive: true);

      // Get the display scale factor (0.6 from your code)
      const double displayScale = 0.6;

      // Get current mobile display dimensions (scaled down)
      double currentMobileWidth, currentMobileHeight;
      switch (pageFormat) {
        case 'Letter':
          currentMobileWidth = 612.0 * displayScale;
          currentMobileHeight = 792.0 * displayScale;
          break;
        case 'Legal':
          currentMobileWidth = 612.0 * displayScale;
          currentMobileHeight = 1008.0 * displayScale;
          break;
        case 'A4':
        default:
          currentMobileWidth = 595.0 * displayScale;
          currentMobileHeight = 842.0 * displayScale;
          break;
      }

      // Export each page with proper scaling
      for (int i = 0; i < pages.length; i++) {
        // Scale up the panels from mobile display to actual PDF size
        final scaledPanels = _scaleUpPanelsForExport(
          pages[i],
          displayScale,
          595.0,
          842.0,
          currentMobileWidth,
          currentMobileHeight,
        );
        final pageImage = await _renderPageAsImage(
          scaledPanels,
          595.0,
          842.0,
        );

        final fileName = '${sanitizedName}_page_${i + 1}.png';
        final filePath = '${projectDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pageImage);
        exportedFiles.add(filePath);
      }

      Navigator.pop(context);
      _showMultipleExportSuccessDialog(context, exportedFiles, projectDir.path);
      return exportedFiles;

    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to export pages as PNG: $e');
      return [];
    }
  }

  // Export all pages as a single PDF with proper scaling
  static Future<String?> exportAllPagesAsPDF({
    required BuildContext context,
    required List<List<LayoutPanel>> pages,
    required String projectName,
    double canvasWidth = 800,
    double canvasHeight = 600,
    String pageFormat = 'A4',
  }) async
  {
    try {
      _showLoadingDialog(context, 'Exporting as PDF ($pageFormat format)...');

      // Request permissions
      if (!await _requestPermissions()) {
        Navigator.pop(context);
        _showErrorDialog(context, 'Storage permission is required to export files.');
        return null;
      }

      // Get export directory
      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(projectName);

      final pdf = pw.Document();

      // Get the display scale factor (0.6 from your code)
      const double displayScale = 0.6;

      // Get current mobile display dimensions (scaled down)
      double currentMobileWidth, currentMobileHeight;
      switch (pageFormat) {
        case 'Letter':
          currentMobileWidth = 612.0 * displayScale;
          currentMobileHeight = 792.0 * displayScale;
          break;
        case 'Legal':
          currentMobileWidth = 612.0 * displayScale;
          currentMobileHeight = 1008.0 * displayScale;
          break;
        case 'A4':
        default:
          currentMobileWidth = 595.0 * displayScale;
          currentMobileHeight = 842.0 * displayScale;
          break;
      }

      // Convert each page to PDF with proper scaling
      for (int i = 0; i < pages.length; i++) {
        // Scale up the panels from mobile display to actual PDF size
        final scaledPanels = _scaleUpPanelsForExport(
          pages[i],
          displayScale,
          595.0,
          842.0,
          currentMobileWidth,
          currentMobileHeight,
        );

        final pageImage = await _renderPageAsImage(
          scaledPanels,
          595.0,
          842.0,
        );

        final pdfImage = pw.MemoryImage(pageImage);

        // Determine PDF page format
        pw.PdfPageFormat pdfPageFormat;
        switch (pageFormat) {
          case 'Letter':
            pdfPageFormat = PdfPageFormat.letter;
            break;
          case 'Legal':
            pdfPageFormat = PdfPageFormat.legal;
            break;
          case 'A4':
          default:
            pdfPageFormat = PdfPageFormat.a4;
            break;
        }

        pdf.addPage(
          pw.Page(
            pageFormat: pdfPageFormat,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Container(
                width: double.infinity,
                height: double.infinity,
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.fill,
                ),
              );
            },
          ),
        );
      }

      // Save PDF
      final fileName = '${sanitizedName}_$timestamp.pdf';
      final filePath = '${exportDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      Navigator.pop(context);
      _showExportSuccessDialog(context, filePath, pageFormat: pageFormat);
      return filePath;

    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to export as PDF: $e');
      return null;
    }
  }

  // Export project data as JSON
  static Future<String?> exportProjectAsJSON({
    required BuildContext context,
    required Project project,
  }) async {
    try {
      _showLoadingDialog(context, 'Exporting project data...');

      if (!await _requestPermissions()) {
        Navigator.pop(context);
        _showErrorDialog(context, 'Storage permission is required to export files.');
        return null;
      }

      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(project.name);

      // Create comprehensive project data
      final projectData = {
        'exportInfo': {
          'exportedAt': DateTime.now().toIso8601String(),
          'exportVersion': '1.0',
          'appName': 'Comic Panel Editor',
        },
        'project': {
          'id': project.id,
          'name': project.name,
          'createdAt': project.createdAt.toIso8601String(),
          'lastModified': project.lastModified.toIso8601String(),
          'totalPages': project.pages.length,
        },
        'pages': project.pages.asMap().entries.map((entry) {
          final pageIndex = entry.key;
          final page = entry.value;

          return {
            'pageNumber': pageIndex + 1,
            'panelCount': page.length,
            'panels': page.map((panel) {
              return {
                'id': panel.id,
                'position': {
                  'x': panel.x,
                  'y': panel.y,
                },
                'dimensions': {
                  'width': panel.width,
                  'height': panel.height,
                },
                'content': {
                  'customText': panel.customText,
                  'backgroundColor': '#${panel.backgroundColor.value.toRadixString(16).padLeft(8, '0')}',
                  'hasPreviewImage': panel.previewImage != null,
                },
                'elements': panel.elements.map((element) {
                  return {
                    'id': element.id,
                    'type': element.type,
                    'value': element.value,
                    'dimensions': {
                      'width': element.width,
                      'height': element.height,
                    },
                    'position': {
                      'dx': element.offset.dx,
                      'dy': element.offset.dy,
                    },
                    'style': {
                      'color': element.color != null
                          ? '#${element.color!.value.toRadixString(16).padLeft(8, '0')}'
                          : null,
                      'fontSize': element.fontSize,
                    },
                  };
                }).toList(),
              };
            }).toList(),
          };
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(projectData);

      final fileName = '${sanitizedName}_project_$timestamp.json';
      final filePath = '${exportDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      Navigator.pop(context);
      _showExportSuccessDialog(context, filePath);
      return filePath;

    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to export project data: $e');
      return null;
    }
  }

  // Utility method to sanitize file names
  static String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  // Share exported files
  static Future<void> shareFiles(List<String> filePaths) async {
    try {
      if (filePaths.isNotEmpty) {
        final xFiles = filePaths.map((path) => XFile(path)).toList();
        await Share.shareXFiles(xFiles);
      }
    } catch (e) {
      print('Error sharing files: $e');
    }
  }

  // UI Helper methods
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Export Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showExportSuccessDialog(BuildContext context, String filePath, {String? pageFormat}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File saved to:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 8),
            if (pageFormat != null)
              Text(
                'Format: $pageFormat (Actual Size)',
                style: TextStyle(fontSize: 12, color: Colors.blue[600], fontWeight: FontWeight.bold),
              ),
            SizedBox(height: 4),
            Text(
              'Scaled from mobile view to actual PDF dimensions',
              style: TextStyle(fontSize: 12, color: Colors.green[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              shareFiles([filePath]);
            },
            icon: Icon(Icons.share),
            label: Text('Share'),
          ),
        ],
      ),
    );
  }

  static void _showMultipleExportSuccessDialog(
      BuildContext context,
      List<String> filePaths,
      String directoryPath
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${filePaths.length} files exported to:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                directoryPath,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Scaled from mobile view to actual PDF dimensions',
              style: TextStyle(fontSize: 12, color: Colors.green[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              shareFiles(filePaths);
            },
            icon: Icon(Icons.share),
            label: Text('Share All'),
          ),
        ],
      ),
    );
  }
}