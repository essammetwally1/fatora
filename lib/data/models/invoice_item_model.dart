import 'package:hive/hive.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String customerName;

  @HiveField(2)
  String? itemName;

  @HiveField(3)
  double price;

  @HiveField(4)
  String? note;

  @HiveField(5)
  bool isPaid;

  InvoiceItemModel({
    DateTime? date,
    required this.customerName,
    this.itemName,
    required this.price,
    this.note,
    required this.isPaid,
  }) : date = date ?? DateTime.now();

  String get displayItemName {
    final value = itemName?.trim();
    return value == null || value.isEmpty ? 'بدون اسم صنف' : value;
  }

  String get displayNote {
    final value = note?.trim();
    return value == null || value.isEmpty ? 'لا توجد ملاحظات' : value;
  }
}
