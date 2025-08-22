import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'DragSpeechBubbleComponents.dart';
import 'DragSpeechBubbleData.dart';
import 'SpeechBubblePainterWithText.dart';

class SpeechBubbleEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // same keys you already pass
  final String title; // "Add Speech Bubble" | "Edit Speech Bubble"

  const SpeechBubbleEditorScreen({
    super.key,
    required this.title,
    this.initialData,
  });

  @override
  State<SpeechBubbleEditorScreen> createState() =>
      _SpeechBubbleEditorScreenState();
}

class _SpeechBubbleEditorScreenState extends State<SpeechBubbleEditorScreen> {
  // Export canvas size (logical). The PNG will match this exactly.
  static const double _canvasW = 320;
  static const double _canvasH = 250;

  static const double _handleR = 10; // drag handle radius

  late DragSpeechBubbleData d;
  late final TextEditingController _textCtrl;

  final GlobalKey _previewKey = GlobalKey();

  // dropdown sources
  final List<String> _fontFamilies = const [
    'Roboto',
    'OpenSans',
    'Poppins',
    'NotoSans'
  ];
  final List<FontWeight> _weights = const [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700
  ];
  final List<FontStyle> _styles = const [FontStyle.normal, FontStyle.italic];

  bool _exporting = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(_refitCurrentText); // ensure initial text fits
    });

    final m = widget.initialData ?? {};

    final bubbleColor = (m['bubbleColor'] as Color?) ?? Colors.white;
    final borderColor = (m['borderColor'] as Color?) ?? Colors.black;
    final shape =
        (m['bubbleShape'] as DragBubbleShape?) ?? DragBubbleShape.rectangle;

    final fontSize = (m['fontSize'] as num?)?.toDouble() ?? 16.0;
    final textColor = (m['textColor'] as Color?) ?? Colors.black;
    final fontFamily = (m['fontFamily'] as String?) ?? 'Roboto';
    final fontWeight = (m['fontWeight'] as FontWeight?) ?? FontWeight.w400;
    final fontStyle = (m['fontStyle'] as FontStyle?) ?? FontStyle.normal;
    final padding = (m['padding'] as num?)?.toDouble() ?? 14.0;
    final borderW = (m['borderWidth'] as num?)?.toDouble() ?? 2.0;

    Offset tailOffset =
        m['tailOffset'] as Offset? ?? Offset(_canvasW * .5, _canvasH * .5);
    final tn = (m['tailNorm'] as Map<String, double>?);
    final tailNorm = tn != null
        ? Offset(tn['dx'] ?? .5, tn['dy'] ?? .5)
        : Offset(tailOffset.dx / _canvasW, tailOffset.dy / _canvasH);

    tailOffset =
        _clampToRect(tailOffset, Rect.fromLTWH(0, 0, _canvasW, _canvasH));

    d = DragSpeechBubbleData(
      text: (m['text'] as String?) ?? 'Hello!',
      bubbleColor: bubbleColor,
      borderColor: borderColor,
      borderWidth: borderW,
      bubbleShape: shape,
      fontSize: fontSize,
      textColor: textColor,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      padding: padding,
      tailOffset: tailOffset,
      tailNorm: tailNorm,
    );

    _textCtrl = TextEditingController(text: d.text);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreview();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          /*  TextButton(
            onPressed: () {
              setState(() => d = d.copyWith(text: _textCtrl.text));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Applied')));
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),*/
          /* ElevatedButton(onPressed: _saveAndPop,
            child: const Text('Save'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),*/
          ElevatedButton.icon(
            onPressed: _saveAndPop, // keep enabled
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Save"),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.disabled))
                  return Colors.grey.shade400;
                if (states.contains(WidgetState.pressed)) return Colors.blue;
                return Colors.grey; // default idle
              }),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            ),
          )

          /*TextButton.icon(
            onPressed: _saveAndPop,
            icon: const Icon(Icons.save, color: Colors.black),
            label: const Text('Save', style: TextStyle(color: Colors.black)),
          ),*/
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // preview scales to fit but exports at exact canvas size
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: _previewKey,
                child: SizedBox(
                  width: _canvasW,
                  height: _canvasH,
                  // No background color here -> stays transparent outside the bubble
                  child: _buildPreview(),
                ),
              ),
            ),
          ),
/*
          const Divider(height: 10, thickness: 1),
*/
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Text'),
                  /*  TextField(
                    controller: _textCtrl,
                    onChanged: (v) => setState(() => d = d.copyWith(text: v)),
                    decoration: const InputDecoration(
                      hintText: 'Enter bubble text',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),*/
                  TextField(
                    controller: _textCtrl,
/*
                    style: _currentTextStyle(), // 👈 apply style to the editor text itself
*/
                    inputFormatters: [
                      // a high hard cap just for safety; the real limit is dynamic
                      LengthLimitingTextInputFormatter(2000),
                      BubbleFitFormatter(
                        canvasSize: const Size(_canvasW, _canvasH),
                        getData: () =>
                            d, // read the latest bubble settings each keystroke
                      ),
                    ],
                    onChanged: (v) {
                      // The formatter may have clipped it; read back controller.text
                      final fitted = _textCtrl.text;
                      if (fitted != d.text) {
                        setState(() => d = d.copyWith(text: fitted));
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter bubble text',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Typography:'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Font Family (left)
                      Expanded(
                        child: _labeled(
                          'Font Family',
                          DropdownButton<String>(
                            isExpanded: true,
                            value: d.fontFamily,
                            items: _fontFamilies
                                .map((f) =>
                                    DropdownMenuItem(value: f, child: Text(f)))
                                .toList(),
/*
                            onChanged: (v) => setState(() => d = d.copyWith(fontFamily: v!)),
*/
                            onChanged: (v) => setState(() {
                              d = d.copyWith(fontFamily: v!);
                              _refitCurrentText();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Font Size (right)
                      Expanded(
                        child: _labeled(
                          'Font Size',
                          Slider(
                            min: 10,
                            max: 64,
                            value: d.fontSize,
/*
                            onChanged: (v) => setState(() => d = d.copyWith(fontSize: v)),
*/
                            onChanged: (v) => setState(() {
                              d = d.copyWith(fontSize: v);
                              _refitCurrentText();
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),

                  /*   _sectionTitle('Typography'),
                  _labeled('Font Size', Slider(
                    min: 10, max: 64, value: d.fontSize,
                    onChanged: (v) => setState(() => d = d.copyWith(fontSize: v)),
                  )),*/
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _labeled(
                          'Text Style',
                          DropdownButton<FontStyle>(
                            isExpanded: true,
                            value: d.fontStyle,
                            items: _styles
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s == FontStyle.normal
                                        ? 'Normal'
                                        : 'Italic')))
                                .toList(),
/*
                            onChanged: (v) => setState(() => d = d.copyWith(fontStyle: v!)),
*/
                            // Font style dropdown
                            onChanged: (v) => setState(() {
                              d = d.copyWith(fontStyle: v!);
                              _refitCurrentText();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _labeled(
                          'Weight',
                          DropdownButton<FontWeight>(
                            isExpanded: true,
                            value: d.fontWeight,
                            items: _weights.map((w) {
                              final label = {
                                FontWeight.w300: 'Light',
                                FontWeight.w400: 'Regular',
                                FontWeight.w500: 'Medium',
                                FontWeight.w600: 'Semibold',
                                FontWeight.w700: 'Bold',
                              }[w]!;
                              return DropdownMenuItem(
                                  value: w, child: Text(label));
                            }).toList(),
/*
                            onChanged: (v) => setState(() => d = d.copyWith(fontWeight: v!)),
*/
                            // Font weight dropdown
                            onChanged: (v) => setState(() {
                              d = d.copyWith(fontWeight: v!);
                              _refitCurrentText();
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _colorPickerTile('Text Color', d.textColor,
                          (c) => setState(() => d = d.copyWith(textColor: c))),
                      /*  SizedBox(
                        width: 260,
                        child: _labeled('Family',
                          DropdownButton<String>(
                            isExpanded: true,
                            value: d.fontFamily,
                            items: _fontFamilies.map((f) =>
                                DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (v) => setState(() => d = d.copyWith(fontFamily: v!)),
                          ),
                        ),
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Bubble Style:'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _colorPickerTile(
                          'Fill',
                          d.bubbleColor,
                          (c) =>
                              setState(() => d = d.copyWith(bubbleColor: c))),
                      _colorPickerTile(
                          'Border',
                          d.borderColor,
                          (c) =>
                              setState(() => d = d.copyWith(borderColor: c))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _labeled(
                            'Border Width',
                            Slider(
                              min: 0,
                              max: 12,
                              value: d.borderWidth,
                            /*  onChanged: (v) => setState(
                                  () => d = d.copyWith(borderWidth: v)),*/
                              onChanged: (v) => setState(() {
                                d = d.copyWith(borderWidth: v);
                                _refitCurrentText();
                              }),
                            )),
                      ),
                      /* const SizedBox(width: 8),
                      Expanded(
                        child:  _labeled('Padding', Slider(
                          min: 6, max: 36, value: d.padding,
                          onChanged: (v) => setState(() => d = d.copyWith(padding: v)),

                          onChanged: (v) => setState(() {
  d = d.copyWith(padding: v);
  _refitCurrentText();
}),
                        )),
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Bubble Shape:'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<DragBubbleShape>(
                      segments: const [
                        ButtonSegment(
                            value: DragBubbleShape.rectangle,
                            label: Text('Rectangle')),
                       /* ButtonSegment(
                            value: DragBubbleShape.shout, label: Text('Shout')),*/
                      ],
                      selected: {d.bubbleShape},
                     /* onSelectionChanged: (set) => setState(
                          () => d = d.copyWith(bubbleShape: set.first)),*/
                      onSelectionChanged: (set) => setState(() {
                        d = d.copyWith(bubbleShape: set.first);
                        _refitCurrentText();
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Tail:'),
                  Row(
                    children: [
                      Expanded(
                        child: _labeled(
                          'Tail X',
                          Slider(
                            min: 0,
                            max: 1,
                            value: d.tailOffset.dx / _canvasW,
                            onChanged: (v) {
                              final x = v * _canvasW;
                              final p = Offset(x, d.tailOffset.dy);
                              setState(() => d = d.copyWith(
                                    tailOffset: p,
                                    tailNorm: Offset(
                                        p.dx / _canvasW, p.dy / _canvasH),
                                  ));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _labeled(
                          'Tail Y',
                          Slider(
                            min: 0,
                            max: 1,
                            value: d.tailOffset.dy / _canvasH,
                            onChanged: (v) {
                              final y = v * _canvasH;
                              final p = Offset(d.tailOffset.dx, y);
                              setState(() => d = d.copyWith(
                                    tailOffset: p,
                                    tailNorm: Offset(
                                        p.dx / _canvasW, p.dy / _canvasH),
                                  ));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _resetTailToCenter,
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Center Tail'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetAllToDefaults,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- preview ----------------

  Widget _buildPreview() {
    TextStyle _styleFor(DragSpeechBubbleData dd) => _fontFromFamily(
      family: dd.fontFamily,
      size: dd.fontSize,
      weight: dd.fontWeight,
      style: dd.fontStyle,
      color: dd.textColor,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: SpeechBubblePainterWithText(d, textStyleFor: _styleFor)),
        ),
        if (!_exporting && d.bubbleShape == DragBubbleShape.rectangle) // <—
          Positioned(
            left: d.tailOffset.dx - _handleR,
            top: d.tailOffset.dy - _handleR,
            child: GestureDetector(
              onPanUpdate: (details) {
                final Rect bounds = Rect.fromLTWH(0, 0, _canvasW, _canvasH);
                final Offset next =
                    _clampToRect(d.tailOffset + details.delta, bounds);
                setState(() {
                  d = d.copyWith(
                    tailOffset: next,
                    tailNorm: Offset(next.dx / _canvasW, next.dy / _canvasH),
                  );
                });
              },
              child: Container(
                width: _handleR * 2,
                height: _handleR * 2,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- helpers ----------------

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _colorPickerTile(
      String label, Color color, ValueChanged<Color> onPicked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionTitle('$label:'),
        const SizedBox(width: 6),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showColorPicker(
            title: '$label Color',
            initial: color,
            onApply: onPicked,
          ),
          child: const Text('Pick'),
        ),
      ],
    );
  }

  Future<void> _showColorPicker({
    required String title,
    required Color initial,
    required ValueChanged<Color> onApply,
  }) async {
    Color temp = initial;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              MaterialPicker(
                pickerColor: temp,
                onColorChanged: (c) => temp = c,
                // don't pop here; wait for Apply
                enableLabel: false,
                // <-- hide RGB/HEX labels
                portraitOnly: true, // (optional) keep layout tidy on phones
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onApply(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetTailToCenter() {
    final center = Offset(_canvasW * 0.5, _canvasH * 0.5);
    setState(() {
      d = d.copyWith(tailOffset: center, tailNorm: const Offset(0.5, 0.5));
    });
  }

  void _resetAllToDefaults() {
    setState(() {
      d = d.copyWith(
        text: 'Hello!',
        bubbleColor: Colors.white,
        borderColor: Colors.black,
        borderWidth: 2.0,
        bubbleShape: DragBubbleShape.rectangle,
        fontSize: 18,
        textColor: Colors.black,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
        padding: 14.0,
      );
      _resetTailToCenter();
      _textCtrl.text = d.text;
    });
  }

  Offset _clampToRect(Offset p, Rect r) {
    return Offset(
      p.dx.clamp(r.left, r.right),
      p.dy.clamp(r.top, r.bottom),
    );
  }

  Future<void> _saveAndPop() async {
    // Make sure latest text is stored
    d = d.copyWith(text: _textCtrl.text);

    // Hide handle, wait a frame, then capture
    setState(() => _exporting = true);
    await Future.delayed(
        const Duration(milliseconds: 16)); // let UI rebuild without handle

    // Choose an export scale. 2.0 is usually enough; DPR is fine too.
    final double exportScale =
        MediaQuery.of(context).devicePixelRatio.clamp(2.0, 3.0);

    final result = await _captureCropped(_previewKey, pixelRatio: 1.0);

    if (!mounted) return;
    setState(() => _exporting = false);

    Navigator.pop<Map<String, dynamic>>(context, {
      // bubble attributes
      'text': d.text,
      'bubbleColor': d.bubbleColor,
      'borderColor': d.borderColor,
      'borderWidth': d.borderWidth,
      'bubbleShape': d.bubbleShape,
      'fontSize': d.fontSize,
      'textColor': d.textColor,
      'fontFamily': d.fontFamily,
      'fontWeight': d.fontWeight,
      'fontStyle': d.fontStyle,
      'padding': d.padding,
      'tailOffset': d.tailOffset,
      'tailNorm': {'dx': d.tailNorm?.dx, 'dy': d.tailNorm?.dy},

      // image payload (cropped to actual visible bubble)
      'pngBytes': result.bytes,
      'width': result.width.toDouble(),
      'height': result.height.toDouble(),
    });
  }

  Future<Uint8List> _capturePngOf(GlobalKey key,
      {double pixelRatio = 1.0}) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _refitCurrentText() {
    final formatter = BubbleFitFormatter(
      canvasSize: const Size(_canvasW, _canvasH),
      getData: () => d,
    );

    // Re-measure the current text against the current bubble geometry
    final fitted = formatter.formatEditUpdate(_textCtrl.value, _textCtrl.value);

    if (fitted.text != _textCtrl.text) {
      _textCtrl.value = fitted; // update the field
      d = d.copyWith(text: fitted.text); // keep the model in sync
    }
  }

  TextStyle _currentTextStyle() => TextStyle(
    fontFamily: d.fontFamily,
    fontSize: d.fontSize,
    fontWeight: d.fontWeight,
    fontStyle: d.fontStyle,
    color: d.textColor,
    height: 1.0, // nicer line-height
  );
}

// Single resolver used by TextField, painter, etc.
TextStyle _fontFromFamily({
  required String family,
  required double size,
  required FontWeight weight,
  required FontStyle style,
  required Color color,
}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    color: color,
    height: 1.2,
  );
  switch (family) {
    case 'OpenSans': return GoogleFonts.openSans(textStyle: base);
    case 'Poppins':  return GoogleFonts.poppins(textStyle: base);
    case 'NotoSans': return GoogleFonts.notoSans(textStyle: base);
    case 'Roboto':
    default:         return GoogleFonts.roboto(textStyle: base);
  }
}

class BubbleFitFormatter extends TextInputFormatter {
  final Size canvasSize;
  final DragSpeechBubbleData Function() getData; // read latest d

  BubbleFitFormatter({
    required this.canvasSize,
    required this.getData,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = getData();
    final textRect = _bubbleTextRect(d, canvasSize);

    TextPainter _layout(String s) {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: d.fontSize,
            fontWeight: d.fontWeight,
            fontStyle: d.fontStyle,
            fontFamily: d.fontFamily,
            height: 1.0,
            // match painter defaults
            color: d.textColor, // color doesn't affect size, but ok
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(minWidth: textRect.width, maxWidth: textRect.width);
    }

    // Fast accept if it already fits
    final tp = _layout(newValue.text);
    if (tp.height <= textRect.height) {
      return newValue;
    }

    // Otherwise binary-search the longest prefix that fits
    final full = newValue.text;
    int lo = 0, hi = full.length, ok = 0;

    while (lo <= hi) {
      final mid = (lo + hi) >> 1;

      // final candidate = full.characters.take(mid).toString(); // if using characters
      final candidate = full.substring(0, mid);

      final tp2 = _layout(candidate);
      if (tp2.height <= textRect.height) {
        ok = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    // final clipped = full.characters.take(ok).toString(); // if using characters
    final clipped = full.substring(0, ok);

    // Keep cursor at end of clipped text
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
      composing: TextRange.empty,
    );
  }

  Rect _bubbleTextRect(DragSpeechBubbleData d, Size size) {
    // Keep in sync with your painter:
    // ----- rectangle bubble bounds -----
    const double margin = 40;
    const double bubbleHeight = 120;
    const double bubbleWidthMargin = 50;
    const double kTailPlay = 10.0;

    double left = bubbleWidthMargin + kTailPlay;
    double right = size.width - bubbleWidthMargin - kTailPlay;
    double top = margin + kTailPlay * 0.4;
    double bottom = top + bubbleHeight;
    Rect rect = Rect.fromLTRB(left, top, right, bottom);

    // ----- shout bubble bounds (use its inner box) -----
    if (d.bubbleShape == DragBubbleShape.shout) {
      const double m = 12.0, scale = 0.8;
      final usableW = size.width - 2 * m;
      final usableH = size.height - 2 * m;
      final bubbleW = usableW * scale;
      final bubbleH = usableH * scale;
      final offsetX = (size.width - bubbleW) / 2;
      final offsetY = (size.height - bubbleH) / 2;
      rect = Rect.fromLTWH(offsetX, offsetY, bubbleW, bubbleH);
    }

    // Deflate by padding + half the stroke so we don't paint over the border
    final inset = d.padding + d.borderWidth * 0.5;
    return rect.deflate(inset);
  }
}

class _CropResult {
  final Uint8List bytes;
  final int width;
  final int height;

  _CropResult(this.bytes, this.width, this.height);
}

/// Captures the RepaintBoundary at 1.0x, trims transparent edges, and returns cropped bytes+size.
Future<_CropResult> _captureCropped(GlobalKey key,
    {double pixelRatio = 1.0, int alphaThreshold = 5}) async {
  // 1) Capture full image (transparent background)
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final ui.Image full = await boundary.toImage(pixelRatio: pixelRatio);

  // 2) Read raw RGBA to find non-transparent bounds
  final byteData = await full.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    // Fallback: return full PNG if raw data not available
    final png = await full.toByteData(format: ui.ImageByteFormat.png);
    return _CropResult(png!.buffer.asUint8List(), full.width, full.height);
  }

  final Uint8List rgba = byteData.buffer.asUint8List();
  final int w = full.width;
  final int h = full.height;
  final int stride = w * 4;

  int minX = w, minY = h, maxX = -1, maxY = -1;

  for (int y = 0; y < h; y++) {
    int row = y * stride;
    for (int x = 0; x < w; x++) {
      final int a = rgba[row + x * 4 + 3]; // RGBA -> A at +3
      if (a > alphaThreshold) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  // If everything is transparent, return a 1x1 transparent pixel
  if (maxX < minX || maxY < minY) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final img = await recorder.endRecording().toImage(1, 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return _CropResult(png!.buffer.asUint8List(), 1, 1);
  }

  final int cropW = (maxX - minX + 1);
  final int cropH = (maxY - minY + 1);

  // 3) Crop using drawImageRect into a new image
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final src = Rect.fromLTWH(
      minX.toDouble(), minY.toDouble(), cropW.toDouble(), cropH.toDouble());
  final dst = Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble());
  canvas.drawImageRect(full, src, dst, Paint());
  final ui.Image cropped = await recorder.endRecording().toImage(cropW, cropH);

  final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return _CropResult(png!.buffer.asUint8List(), cropW, cropH);
}
