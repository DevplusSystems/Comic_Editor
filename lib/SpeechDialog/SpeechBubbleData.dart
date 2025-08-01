import 'package:flutter/material.dart';

import 'SpeechBubbleComponents.dart';

class SpeechBubbleData {
  final String text;
  final Color bubbleColor;
  final Color borderColor;
  final double borderWidth;
  final BubbleShape bubbleShape;
  final double padding;
  final double fontSize;
  final Color textColor;
  final String fontFamily;
  final FontWeight fontWeight;
  final FontStyle fontStyle;

  const SpeechBubbleData({
    required this.text,
    required this.bubbleColor,
    required this.borderColor,
    required this.borderWidth,
    required this.bubbleShape,
    required this.padding,
    required this.fontSize,
    required this.textColor,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
  });

  factory SpeechBubbleData.defaultData() {
    return SpeechBubbleData(
      text: 'Hello!',
      bubbleColor: Colors.white,
      borderColor: Colors.black,
      borderWidth: 2.0,
      bubbleShape: BubbleShape.oval,
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
      'padding': padding,
      'fontSize': fontSize,
      'textColor': textColor.value,
      'fontFamily': fontFamily,
      'fontWeight': fontWeight.index,
      'fontStyle': fontStyle.index,
    };
  }

  factory SpeechBubbleData.fromMap(Map<String, dynamic> map) {
    return SpeechBubbleData(
      text: map['text'] ?? '',
      bubbleColor: Color(map['bubbleColor']),
      borderColor: Color(map['borderColor']),
      borderWidth: (map['borderWidth'] ?? 2.0).toDouble(),
      bubbleShape: BubbleShape.values[map['bubbleShape']],
      padding: (map['padding'] ?? 12.0).toDouble(),
      fontSize: (map['fontSize'] ?? 16.0).toDouble(),
      textColor: Color(map['textColor']),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontWeight: FontWeight.values[map['fontWeight']],
      fontStyle: FontStyle.values[map['fontStyle']],
    );
  }
}
