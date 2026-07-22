// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fixed_menu_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FixedMenuItemModelAdapter extends TypeAdapter<FixedMenuItemModel> {
  @override
  final int typeId = 2;

  @override
  FixedMenuItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FixedMenuItemModel(
      name: fields[0] as String,
      price: _readDouble(fields[1]),
      createdAt: fields[2] as DateTime?,
      updatedAt: fields[3] as DateTime?,
    );
  }

  double _readDouble(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    return 0.0;
  }

  @override
  void write(BinaryWriter writer, FixedMenuItemModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedMenuItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
