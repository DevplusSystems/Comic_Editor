// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectHiveModelAdapter extends TypeAdapter<ProjectHiveModel> {
  @override
  final int typeId = 0;

  @override
  ProjectHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      createdAt: fields[3] as DateTime,
      lastModified: fields[4] as DateTime,
      pages: (fields[5] as List)
          .map((dynamic e) => (e as List).cast<LayoutPanelHiveModel>())
          .toList(),
      thumbnail: (fields[6] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectHiveModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.lastModified)
      ..writeByte(5)
      ..write(obj.pages)
      ..writeByte(6)
      ..write(obj.thumbnail);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LayoutPanelHiveModelAdapter extends TypeAdapter<LayoutPanelHiveModel> {
  @override
  final int typeId = 1;

  @override
  LayoutPanelHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LayoutPanelHiveModel(
      id: fields[0] as String,
      width: fields[1] as double,
      height: fields[2] as double,
      x: fields[3] as double,
      y: fields[4] as double,
      customText: fields[5] as String?,
      backgroundColorValue: fields[6] as int,
      previewImage: (fields[7] as List?)?.cast<int>(),
      elements: (fields[8] as List).cast<PanelElementModelHiveModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, LayoutPanelHiveModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.width)
      ..writeByte(2)
      ..write(obj.height)
      ..writeByte(3)
      ..write(obj.x)
      ..writeByte(4)
      ..write(obj.y)
      ..writeByte(5)
      ..write(obj.customText)
      ..writeByte(6)
      ..write(obj.backgroundColorValue)
      ..writeByte(7)
      ..write(obj.previewImage)
      ..writeByte(8)
      ..write(obj.elements);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutPanelHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PanelElementModelHiveModelAdapter
    extends TypeAdapter<PanelElementModelHiveModel> {
  @override
  final int typeId = 2;

  @override
  PanelElementModelHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PanelElementModelHiveModel(
      id: fields[0] as String,
      type: fields[1] as String,
      value: fields[2] as String,
      width: fields[3] as double,
      height: fields[4] as double,
      offsetDx: fields[5] as double,
      offsetDy: fields[6] as double,
      sizeWidth: fields[7] as double?,
      sizeHeight: fields[8] as double?,
      colorValue: fields[9] as int?,
      fontSize: fields[10] as double?,
      fontFamily: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PanelElementModelHiveModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.offsetDx)
      ..writeByte(6)
      ..write(obj.offsetDy)
      ..writeByte(7)
      ..write(obj.sizeWidth)
      ..writeByte(8)
      ..write(obj.sizeHeight)
      ..writeByte(9)
      ..write(obj.colorValue)
      ..writeByte(10)
      ..write(obj.fontSize)
      ..writeByte(11)
      ..write(obj.fontFamily);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelElementModelHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
