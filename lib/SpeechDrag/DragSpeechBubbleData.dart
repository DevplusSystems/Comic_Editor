import 'package:flutter/material.dart';

import 'DragSpeechBubbleComponents.dart';


class DragSpeechBubbleData {
  final String text;
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final DragBubbleShape bubbleShape;
  final Offset tailOffset;
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
  });

  factory DragSpeechBubbleData.defaultData() {
    return DragSpeechBubbleData(
      text: 'Hello!',
      bubbleColor: Colors.white,
      borderColor: Colors.black,
      borderWidth: 2.0,
      bubbleShape: DragBubbleShape.rectangle,
      tailOffset: Offset(100, 120),
      padding: 12.0,
      fontSize: 16.0,
      textColor: Colors.black,
      fontFamily: 'Roboto',
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'bubbleColor': bubbleColor.value,
      'borderColor': borderColor.value,
      'borderWidth': borderWidth,
      'bubbleShape': bubbleShape.index,
      'tailOffset': {'dx': tailOffset.dx, 'dy': tailOffset.dy},
      'padding': padding,
      'fontSize': fontSize,
      'textColor': textColor.value,
      'fontFamily': fontFamily,
      'fontWeight': fontWeight.index,
      'fontStyle': fontStyle.index,
    };
  }

  factory DragSpeechBubbleData.fromMap(Map<String, dynamic> map) {
    return DragSpeechBubbleData(
      text: map['text'] ?? '',
      bubbleColor: Color(map['bubbleColor']),
      borderColor: Color(map['borderColor']),
      borderWidth: (map['borderWidth'] ?? 2.0).toDouble(),
      bubbleShape: DragBubbleShape.values[map['bubbleShape']],
      tailOffset: Offset(
        map['tailOffset']['dx']?.toDouble() ?? 100,
        map['tailOffset']['dy']?.toDouble() ?? 120,
      ),
      padding: (map['padding'] ?? 12.0).toDouble(),
      fontSize: (map['fontSize'] ?? 16.0).toDouble(),
      textColor: Color(map['textColor']),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontWeight: FontWeight.values[map['fontWeight']],
      fontStyle: FontStyle.values[map['fontStyle']],
    );
  }
}