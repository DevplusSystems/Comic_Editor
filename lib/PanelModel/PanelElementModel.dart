import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../SpeechDrag/DragSpeechBubbleData.dart';
class PanelElementModel {
  final String id;
  final String type; // e.g., "text", "draw", "speech_bubble"
  final String value; // for speech bubble: JSON-encoded SpeechBubbleData
  final double width;
  final double height;
  final Offset offset;
  final Size? size;
  final Color? color;
  final double? fontSize;
  final String? fontFamily;
  final bool locked;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;

  const PanelElementModel({
    required this.id,
    required this.type,
    required this.value,
    required this.width,
    required this.height,
    required this.offset,
    this.size,
    this.fontFamily,
    this.color,
    this.fontSize,
    this.locked = false,
    this.fontWeight,
    this.fontStyle,
  });

  PanelElementModel copyWith({
    String? id,
    String? type,
    String? value,
    double? width,
    double? height,
    Offset? offset,
    Size? size,
    Color? color,
    double? fontSize,
    String? fontFamily,
    bool? locked,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    return PanelElementModel(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      width: width ?? this.width,
      height: height ?? this.height,
      offset: offset ?? this.offset,
      size: size ?? this.size,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      locked: locked ?? this.locked,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'value': value,
      'offset_dx': offset.dx,
      'offset_dy': offset.dy,
      'width': width,
      'height': height,
      'size_width': size?.width,
      'size_height': size?.height,
      'fontSize': fontSize,
      'color': color?.value,
      'fontFamily': fontFamily,
      'locked': locked,
      'fontWeight': fontWeight?.index,
      'fontStyle': fontStyle?.index,
    };
  }

  factory PanelElementModel.fromMap(Map<String, dynamic> map) {
    return PanelElementModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      value: map['value'] ?? '',
      offset: Offset(
        (map['offset_dx'] ?? 0.0).toDouble(),
        (map['offset_dy'] ?? 0.0).toDouble(),
      ),
      width: (map['width'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
      size: (map['size_width'] != null && map['size_height'] != null)
          ? Size(
        (map['size_width']).toDouble(),
        (map['size_height']).toDouble(),
      )
          : null,
      fontSize: map['fontSize']?.toDouble(),
      color: map['color'] != null ? Color(map['color']) : null,
      fontFamily: map['fontFamily'],
      locked: map['locked'] ?? false,
      fontWeight: map['fontWeight'] != null
          ? FontWeight.values[map['fontWeight']]
          : null,
      fontStyle: map['fontStyle'] != null
          ? FontStyle.values[map['fontStyle']]
          : null,
    );
  }

  // If this is a speech bubble, decode its value
  DragSpeechBubbleData? get speechBubbleData {
    if (type != 'speech_bubble') return null;
    try {
      return DragSpeechBubbleData.fromMap(jsonDecode(value));
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'PanelElementModel(id: $id, type: $type)';
}


class ComicPanel {
  final String id;
  final List<PanelElementModel> elements;
  final Color backgroundColor;
  final Uint8List? previewImage;

  const ComicPanel({
    required this.id,
    required this.elements,
    required this.backgroundColor,
    this.previewImage,
  });

  ComicPanel copyWith({
    String? id,
    List<PanelElementModel>? elements,
    Color? backgroundColor,
    Uint8List? previewImage,
  }) {
    return ComicPanel(
      id: id ?? this.id,
      elements: elements ?? this.elements,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      previewImage: previewImage ?? this.previewImage,
    );
  }

  @override
  String toString() {
    return 'ComicPanel(id: $id, elements: $elements, backgroundColor: $backgroundColor)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComicPanel &&
        other.id == id &&
        other.elements == elements &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode {
    return Object.hash(id, elements, backgroundColor);
  }
}
