import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'DragSpeechBubbleComponents.dart';
import 'DragSpeechBubbleData.dart';
import 'SpeechBubblePainterWithText.dart';

class DragSpeechBubbleEditDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const DragSpeechBubbleEditDialog({
    super.key,
    required this.initialData,
  });

  @override
  State<DragSpeechBubbleEditDialog> createState() =>
      _DragSpeechBubbleEditDialogState();
}

class _DragSpeechBubbleEditDialogState
    extends State<DragSpeechBubbleEditDialog> {
  // Keep preview size constant so PNG == preview
  static const Size _previewSize = Size(300, 260);

  // IMPORTANT: must match the painter’s margin.
  static const double kOuterMargin = 10.0;

  Offset _tailOffset = const Offset(150, 180);
  Color _bubbleColor = Colors.white;
  Color _borderColor = Colors.black;
  Color _textColor = Colors.black;
  double _fontSize = 16;
  double _borderWidth = 2.0;
  double _padding = 12.0;
  String _fontFamily = 'Roboto';
  FontStyle _fontStyle = FontStyle.normal;
  FontWeight _fontWeight = FontWeight.normal;
  DragBubbleShape _bubbleShape = DragBubbleShape.rectangle;

  late final TextEditingController _textController;

  final List<String> _fontFamilies = const [
    'Roboto',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Comic Sans MS',
    'Impact',
    'Verdana',
  ];

  // ===== Geometry helpers (MUST mirror the painter) =====
  Rect _bubbleRect(Size size) => Rect.fromLTWH(
        kOuterMargin + _padding,
        kOuterMargin + _padding,
        size.width - 2 * (kOuterMargin + _padding),
        size.height - 2 * (kOuterMargin + _padding),
      );

  Offset _clampToRect(Offset p, Rect r) =>
      Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));

  // Project a point to the nearest edge of rect
  Offset _projectToNearestEdge(Rect r, Offset p) {
    final dxL = (p.dx - r.left).abs();
    final dxR = (p.dx - r.right).abs();
    final dyT = (p.dy - r.top).abs();
    final dyB = (p.dy - r.bottom).abs();

    if (dyT <= dyB && dyT <= dxL && dyT <= dxR) {
      return Offset(p.dx.clamp(r.left, r.right), r.top); // top
    } else if (dyB <= dxL && dyB <= dxR) {
      return Offset(p.dx.clamp(r.left, r.right), r.bottom); // bottom
    } else if (dxL <= dxR) {
      return Offset(r.left, p.dy.clamp(r.top, r.bottom)); // left
    } else {
      return Offset(r.right, p.dy.clamp(r.top, r.bottom)); // right
    }
  }

  Offset _normOnRect(Rect r, Offset projected) => Offset(
        (projected.dx - r.left) / r.width,
        (projected.dy - r.top) / r.height,
      );

  @override
  void initState() {
    super.initState();
    _textController =
        TextEditingController(text: widget.initialData['text'] ?? 'Hello!');
    _bubbleColor = widget.initialData['bubbleColor'] ?? Colors.white;
    _borderColor = widget.initialData['borderColor'] ?? Colors.black;
    _textColor = widget.initialData['textColor'] ?? Colors.black;
    _fontSize = (widget.initialData['fontSize'] as num?)?.toDouble() ?? 16.0;
    _borderWidth =
        (widget.initialData['borderWidth'] as num?)?.toDouble() ?? 2.0;
    _bubbleShape =
        widget.initialData['bubbleShape'] ?? DragBubbleShape.rectangle;
    _fontFamily = widget.initialData['fontFamily'] ?? 'Roboto';
    _fontWeight = widget.initialData['fontWeight'] ?? FontWeight.normal;
    _fontStyle = widget.initialData['fontStyle'] ?? FontStyle.normal;
    _padding = (widget.initialData['padding'] as num?)?.toDouble() ?? 12.0;

    // Tail from initial data if given; else start at exact bottom-center
    final initialOffset = widget.initialData['tailOffset'] as Offset?;
    final initialNorm = widget.initialData['tailNorm']; // Map? {dx,dy}

    final rect = _bubbleRect(_previewSize);

    if (initialOffset != null) {
      _tailOffset = _clampToRect(initialOffset, rect);
    } else if (initialNorm is Map) {
      final abs = Offset(
        rect.left + (initialNorm['dx'] as num).toDouble() * rect.width,
        rect.top + (initialNorm['dy'] as num).toDouble() * rect.height,
      );
      _tailOffset = _clampToRect(abs, rect);
    } else {
      _tailOffset = Offset(rect.center.dx, rect.bottom); // bottom-center
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = _bubbleRect(_previewSize);

// Determine which edge tailOffset is on and nudge the handle slightly inward
    Offset inward;
    if ((_tailOffset.dy - rect.top).abs() < 1.0) {
      inward = const Offset(0, 1); // top edge
    } else if ((_tailOffset.dy - rect.bottom).abs() < 1.0) {
      inward = const Offset(0, -1); // bottom edge
    } else if ((_tailOffset.dx - rect.left).abs() < 1.0) {
      inward = const Offset(1, 0); // left edge
    } else {
      inward = const Offset(-1, 0); // right edge
    }

    final double nudge = (_borderWidth / 2) + 2; // move inside bubble
    final Offset handleCenter = _tailOffset + inward * nudge;

    return AlertDialog(
      title: const Text('Edit Speech Bubble'),
      content: SizedBox(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ==== Preview with draggable tail ====
              SizedBox(
                width: 500,
                height: 200,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: _previewSize,
                      painter: SpeechBubblePainterWithText(
                        DragSpeechBubbleData(
                          text: _textController.text,
                          bubbleColor: _bubbleColor,
                          borderColor: _borderColor,
                          borderWidth: _borderWidth,
                          bubbleShape: _bubbleShape,
                          tailOffset: _tailOffset,
                          // anchor on edge
                          tailNorm: null,
                          // painter uses anchor here
                          padding: _padding,
                          fontSize: _fontSize,
                          textColor: _textColor,
                          fontFamily: _fontFamily,
                          fontWeight: _fontWeight,
                          fontStyle: _fontStyle,
                        ),
                      ),
                    ),

                    // === Red handle at the *actual tail tip* ===
                    if (_bubbleShape != DragBubbleShape.shout)
                      Positioned(
                        left: handleCenter.dx - 10,
                        top: handleCenter.dy - 10,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              final unclamped = _tailOffset + details.delta;
                              _tailOffset = _clampToRect(unclamped, rect);
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ==== Text input ====
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Speech Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // Bubble Shape
              DropdownButtonFormField<DragBubbleShape>(
                value: _bubbleShape,
                decoration: const InputDecoration(
                  labelText: 'Bubble Shape',
                  border: OutlineInputBorder(),
                ),
                items: DragBubbleShape.values.map((s) {
                  final name =
                      s == DragBubbleShape.rectangle ? 'Rectangle' : 'Shout';
                  return DropdownMenuItem(value: s, child: Text(name));
                }).toList(),
                onChanged: (v) => setState(() => _bubbleShape = v!),
              ),
              const SizedBox(height: 16),
              // Colors
              Row(
                children: [
                  Expanded(
                    child: _buildColorPicker(
                      'Bubble Color',
                      _bubbleColor,
                      (c) => setState(() => _bubbleColor = c),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildColorPicker(
                      'Border Color',
                      _borderColor,
                      (c) => setState(() => _borderColor = c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildColorPicker(
                'Text Color',
                _textColor,
                (c) => setState(() => _textColor = c),
              ),
              const SizedBox(height: 16),
              // Font Size
              Row(
                children: [
                  const Text('Font Size: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 8,
                      max: 36,
                      divisions: 28,
                      label: _fontSize.round().toString(),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  Text(_fontSize.round().toString()),
                ],
              ),

              // Border Width
              Row(
                children: [
                  const Text('Border Width: '),
                  Expanded(
                    child: Slider(
                      value: _borderWidth,
                      min: 0,
                      max: 8,
                      divisions: 16,
                      label: _borderWidth.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _borderWidth = v),
                    ),
                  ),
                  Text(_borderWidth.toStringAsFixed(1)),
                ],
              ),

              // Padding
              Row(
                children: [
                  const Text('Padding: '),
                  Expanded(
                    child: Slider(
                      value: _padding,
                      min: 4,
                      max: 24,
                      divisions: 20,
                      label: _padding.round().toString(),
                      onChanged: (v) => setState(() => _padding = v),
                    ),
                  ),
                  Text(_padding.round().toString()),
                ],
              ),

              const SizedBox(height: 16),

              // Font Family
              DropdownButtonFormField<String>(
                value: _fontFamily,
                decoration: const InputDecoration(
                  labelText: 'Font Family',
                  border: OutlineInputBorder(),
                ),
                items: _fontFamilies
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f, style: TextStyle(fontFamily: f)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _fontFamily = v!),
              ),

              const SizedBox(height: 16),

              // Font weight/style
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FontWeight>(
                      value: _fontWeight,
                      decoration: const InputDecoration(
                        labelText: 'Font Weight',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: FontWeight.w300, child: Text('Light')),
                        DropdownMenuItem(
                            value: FontWeight.normal, child: Text('Normal')),
                        DropdownMenuItem(
                            value: FontWeight.w600, child: Text('Semi-Bold')),
                        DropdownMenuItem(
                            value: FontWeight.bold, child: Text('Bold')),
                      ],
                      onChanged: (v) => setState(() => _fontWeight = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<FontStyle>(
                      value: _fontStyle,
                      decoration: const InputDecoration(
                        labelText: 'Font Style',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: FontStyle.normal, child: Text('Normal')),
                        DropdownMenuItem(
                            value: FontStyle.italic, child: Text('Italic')),
                      ],
                      onChanged: (v) => setState(() => _fontStyle = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            // Use the SAME rect as preview
            final rect = _bubbleRect(_previewSize);

            final projectedTail = _projectToNearestEdge(rect, _tailOffset);
            final tailNorm = _normOnRect(rect, projectedTail);
            // Build data for PNG
            final dataForPng = DragSpeechBubbleData(
              text: _textController.text,
              bubbleColor: _bubbleColor,
              borderColor: _borderColor,
              borderWidth: _borderWidth,
              bubbleShape: _bubbleShape,
              tailOffset: projectedTail,
              // projected absolute (preview space)
              tailNorm: tailNorm,
              // normalized (0..1, 0..1)
              padding: _padding,
              fontSize: _fontSize,
              textColor: _textColor,
              fontFamily: _fontFamily,
              fontWeight: _fontWeight,
              fontStyle: _fontStyle,
            );

            // Rasterize + CROP transparent pixels (so bounds == bubble)
            final crop = await _rasterizeBubblePngCropped(
              data: dataForPng,
              logicalSize: _previewSize,
              pixelRatio: 3.0,
            );
            final Uint8List pngBytes = crop['bytes'] as Uint8List;
            final double logicalW = crop['logicalWidth'] as double;
            final double logicalH = crop['logicalHeight'] as double;

            Navigator.pop(context, {
              'text': _textController.text,
              'tailOffset': projectedTail,
              'tailNorm': {'dx': tailNorm.dx, 'dy': tailNorm.dy},
              'bubbleColor': _bubbleColor,
              'borderColor': _borderColor,
              'borderWidth': _borderWidth,
              'textColor': _textColor,
              'fontSize': _fontSize,
              'bubbleShape': _bubbleShape,
              'fontFamily': _fontFamily,
              'fontWeight': _fontWeight,
              'fontStyle': _fontStyle,
              'padding': _padding,
              'width': logicalW, // cropped logical size
              'height': logicalH,
              'pngBytes': pngBytes,
            });
          },
          child: const Text("Apply"),
        ),
      ],
    );
  }

  Widget _buildColorPicker(
      String label, Color currentColor, void Function(Color) onColorChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<Color>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Pick $label'),
                content: SingleChildScrollView(
                  child: BlockPicker(
                    pickerColor: currentColor,
                    onColorChanged: (c) => Navigator.pop(context, c),
                  ),
                ),
              ),
            );
            if (picked != null) onColorChanged(picked);
          },
          child: Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: currentColor,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ===== Rasterize + crop transparent pixels =====
  Future<Map<String, dynamic>> _rasterizeBubblePngCropped({
    required DragSpeechBubbleData data,
    required Size logicalSize, // same as preview
    double pixelRatio = 3.0,
  }) async {
    // 1) Paint to a big image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = SpeechBubblePainterWithText(data);
    painter.paint(canvas, logicalSize);
    final picture = recorder.endRecording();

    final widthPx = (logicalSize.width * pixelRatio).round();
    final heightPx = (logicalSize.height * pixelRatio).round();
    final bigImg = await picture.toImage(widthPx, heightPx);

    // 2) Scan for non-transparent pixels to find tight bounds
    final bd = await bigImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) {
      final fullPng = await bigImg.toByteData(format: ui.ImageByteFormat.png);
      return {
        'bytes': fullPng!.buffer.asUint8List(),
        'logicalWidth': logicalSize.width,
        'logicalHeight': logicalSize.height,
      };
    }

    final bytes = bd.buffer.asUint8List();
    final stride = widthPx * 4;
    int minX = widthPx, minY = heightPx, maxX = -1, maxY = -1;

    for (int y = 0; y < heightPx; y++) {
      int row = y * stride;
      for (int x = 0; x < widthPx; x++) {
        final a = bytes[row + x * 4 + 3]; // RGBA -> A
        if (a != 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      final fullPng = await bigImg.toByteData(format: ui.ImageByteFormat.png);
      return {
        'bytes': fullPng!.buffer.asUint8List(),
        'logicalWidth': logicalSize.width,
        'logicalHeight': logicalSize.height,
      };
    }

    // 3) Crop to tight bounds
    final srcRect = Rect.fromLTWH(
      minX.toDouble(),
      minY.toDouble(),
      (maxX - minX + 1).toDouble(),
      (maxY - minY + 1).toDouble(),
    );

    final cropRecorder = ui.PictureRecorder();
    final cropCanvas = Canvas(cropRecorder);
    cropCanvas.drawImageRect(
      bigImg,
      srcRect,
      Rect.fromLTWH(0, 0, srcRect.width, srcRect.height),
      Paint(),
    );
    final croppedPic = cropRecorder.endRecording();
    final croppedImg = await croppedPic.toImage(
      srcRect.width.toInt(),
      srcRect.height.toInt(),
    );

    final png = await croppedImg.toByteData(format: ui.ImageByteFormat.png);

    return {
      'bytes': png!.buffer.asUint8List(),
      'logicalWidth': srcRect.width / pixelRatio,
      'logicalHeight': srcRect.height / pixelRatio,
    };
  }
}
