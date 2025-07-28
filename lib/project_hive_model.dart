import 'package:hive/hive.dart';
part 'project_hive_model.g.dart'; // Required for code generation


@HiveType(typeId: 0)
class ProjectHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime lastModified;

  @HiveField(5)
  final List<List<LayoutPanelHiveModel>> pages;

  @HiveField(6)
  final List<int>? thumbnail;

  ProjectHiveModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.lastModified,
    required this.pages,
    this.thumbnail,
  });
}

@HiveType(typeId: 1)
class LayoutPanelHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double width;

  @HiveField(2)
  final double height;

  @HiveField(3)
  final double x;

  @HiveField(4)
  final double y;

  @HiveField(5)
  final String? customText;

  @HiveField(6)
  final int backgroundColorValue;

  @HiveField(7)
  final List<int>? previewImage;

  @HiveField(8)
  final List<PanelElementModelHiveModel> elements;

  LayoutPanelHiveModel({
    required this.id,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    this.customText,
    required this.backgroundColorValue,
    this.previewImage,
    required this.elements, // Make this required, not optional
  });
}

@HiveType(typeId: 2)
class PanelElementModelHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type;

  @HiveField(2)
  final String value;

  @HiveField(3)
  final double width;

  @HiveField(4)
  final double height;

  @HiveField(5)
  final double offsetDx;

  @HiveField(6)
  final double offsetDy;

  @HiveField(7)
  final double? sizeWidth;

  @HiveField(8)
  final double? sizeHeight;

  @HiveField(9)
  final int? colorValue;

  @HiveField(10)
  final double? fontSize;

  @HiveField(11)
  final String? fontFamily;

  PanelElementModelHiveModel({
    required this.id,
    required this.type,
    required this.value,
    required this.width,
    required this.height,
    required this.offsetDx,
    required this.offsetDy,
    this.sizeWidth,
    this.sizeHeight,
    this.colorValue,
    this.fontSize,
    this.fontFamily,
  });
}

