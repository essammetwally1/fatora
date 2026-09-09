// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_payment_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoicePaymentEntryModelAdapter
    extends TypeAdapter<InvoicePaymentEntryModel> {
  @override
  final int typeId = 3;

  @override
  InvoicePaymentEntryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoicePaymentEntryModel(
      id: fields[0] == null ? '' : fields[0] as String?,
      amount: fields[1] == null ? 0.0 : fields[1] as double,
      isReturn: fields[2] == null ? false : fields[2] as bool,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoicePaymentEntryModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.isReturn)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoicePaymentEntryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
