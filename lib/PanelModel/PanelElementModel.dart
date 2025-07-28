import 'package:flutter/material.dart';
import 'dart:typed_data';

class PanelElementModel {
  final String id;
  final String type;
  final String value;
  final double width;
  final double height;
  final Offset offset;
  final Size? size;
  final Color? color;
  final double? fontSize;
  final String? fontFamily;
  final bool locked; // ✅ added
  final FontWeight? fontWeight; // NEW
  final FontStyle? fontStyle;   // NEW


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
    this.locked = false, // ✅ default value
    this.fontWeight,  // NEW
    this.fontStyle,   // NEW

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
    bool? locked, // ✅ added to copyWith
    FontWeight? fontWeight,  // NEW
    FontStyle? fontStyle,    // NEW
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
      fontWeight: fontWeight ?? this.fontWeight,  // NEW
      fontStyle: fontStyle ?? this.fontStyle,     // NEW
    );
  }
  // Convert to Map for Hive storage
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
      'fontWeight': fontWeight?.index,  // NEW
      'fontStyle': fontStyle?.index,    // NEW
    };
  }

  // Create from Map for Hive loading
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
      size: map['size_width'] != null && map['size_height'] != null
          ? Size(
        (map['size_width']).toDouble(),
        (map['size_height']).toDouble(),
      )
          : null,
      fontSize: map['fontSize']?.toDouble(),
      color: map['color'] != null ? Color(map['color']) : null,
      fontFamily: map['fontFamily'],
      fontWeight: map['fontWeight'] != null
          ? FontWeight.values[map['fontWeight']]
          : null,  // NEW
      fontStyle: map['fontStyle'] != null
          ? FontStyle.values[map['fontStyle']]
          : null,   // NEW
    );
  }

  @override
  String toString() {
    return 'PanelElementModel(id: $id, type: $type, value: $value, width: $width, height: $height, offset: $offset, color: $color, size: $size, fontSize: $fontSize, fontFamily: $fontFamily, locked: $locked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PanelElementModel &&
        other.id == id &&
        other.type == type &&
        other.value == value &&
        other.width == width &&
        other.height == height &&
        other.offset == offset &&
        other.color == color &&
        other.size == size &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.locked == locked;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      value,
      width,
      height,
      offset,
      color,
      size,
      fontSize,
      fontFamily,
      locked,
    );
  }
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
