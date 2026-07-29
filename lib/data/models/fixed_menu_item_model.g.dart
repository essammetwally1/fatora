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
      price: fields[1] == null ? 0.0 : fields[1] as double,
      createdAt: fields[2] as DateTime?,
      updatedAt: fields[3] as DateTime?,
    );
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
