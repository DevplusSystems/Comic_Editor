import 'package:flutter/material.dart';

import 'DragSpeechBubbleComponents.dart';
class DragSpeechBubbleData {
  final String text;
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final DragBubbleShape bubbleShape;

  final Offset tailOffset;
  final Offset? tailNorm;

  final double padding;
  final double fontSize;
  final Color textColor;
  final String fontFamily;
  final FontWeight fontWeight;
  final FontStyle fontStyle;

  const DragSpeechBubbleData({
    required this.text,
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
    required this.bubbleShape,
    required this.tailOffset,
    required this.padding,
    required this.fontSize,
    required this.textColor,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    this.tailNorm,
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'bubbleColor': bubbleColor.value,
    'borderColor': borderColor.value,
    'borderWidth': borderWidth,
    'bubbleShape': bubbleShape.index,
    'tailOffset': {'dx': tailOffset.dx, 'dy': tailOffset.dy},
    'tailNorm': tailNorm == null
        ? null
        : {'dx': tailNorm!.dx, 'dy': tailNorm!.dy},
    'padding': padding,
    'fontSize': fontSize,
    'textColor': textColor.value,
    'fontFamily': fontFamily,
    'fontWeight': fontWeight.index,
    'fontStyle': fontStyle.index,
  };

  factory DragSpeechBubbleData.fromMap(Map<String, dynamic> map) {
    final norm = map['tailNorm'];
    return DragSpeechBubbleData(
      text: map['text'] ?? '',
      bubbleColor: Color(map['bubbleColor']),
      borderColor: Color(map['borderColor']),
      borderWidth: (map['borderWidth'] ?? 2.0).toDouble(),
      bubbleShape: DragBubbleShape.values[map['bubbleShape'] ?? 0],
      tailOffset: Offset(
        (map['tailOffset']?['dx'] as num?)?.toDouble() ?? 100,
        (map['tailOffset']?['dy'] as num?)?.toDouble() ?? 120,
      ),
      tailNorm: (norm is Map)
          ? Offset(
        (norm['dx'] as num).toDouble(),
        (norm['dy'] as num).toDouble(),
      )
          : null,
      padding: (map['padding'] ?? 12.0).toDouble(),
      fontSize: (map['fontSize'] ?? 16.0).toDouble(),
      textColor: Color(map['textColor']),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontWeight: FontWeight.values[map['fontWeight'] ?? 3], // normal=3
      fontStyle: FontStyle.values[map['fontStyle'] ?? 0], // normal=0
    );
  }

  DragSpeechBubbleData copyWith({
    String? text,
    Color? bubbleColor,
    Color? borderColor,
    double? borderWidth,
    DragBubbleShape? bubbleShape,
    Offset? tailOffset,
    Offset? tailNorm,          // pass a value to replace, or omit to keep
    double? padding,
    double? fontSize,
    Color? textColor,
    String? fontFamily,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    return DragSpeechBubbleData(
      text:        text        ?? this.text,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      bubbleShape: bubbleShape ?? this.bubbleShape,
      tailOffset:  tailOffset  ?? this.tailOffset,
      tailNorm:    tailNorm    ?? this.tailNorm,
      padding:     padding     ?? this.padding,
      fontSize:    fontSize    ?? this.fontSize,
      textColor:   textColor   ?? this.textColor,
      fontFamily:  fontFamily  ?? this.fontFamily,
      fontWeight:  fontWeight  ?? this.fontWeight,
      fontStyle:   fontStyle   ?? this.fontStyle,
    );
  }
}
