// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 1;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceModel(
      title: fields[0] as String,
      items: (fields[1] as List).cast<InvoiceItemModel>(),
      paidAmount: fields[2] == null ? 0.0 : fields[2] as double,
      createdAt: fields[3] as DateTime?,
      payments: fields[4] == null
          ? []
          : (fields[4] as List?)?.cast<InvoicePaymentEntryModel>(),
      hidePaymentDetailsInExport: fields[5] == null ? false : fields[5] as bool,
      isStarred: fields[6] == null ? false : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.paidAmount)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.payments)
      ..writeByte(5)
      ..write(obj.hidePaymentDetailsInExport)
      ..writeByte(6)
      ..write(obj.isStarred);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
