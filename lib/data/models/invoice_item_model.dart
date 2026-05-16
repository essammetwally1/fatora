// invoice_item_model.dart

import 'package:hive/hive.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String customerName;

  @HiveField(2)
  String itemName;

  @HiveField(3)
  double price;

  @HiveField(4)
  String note;

  @HiveField(5)
  bool isPaid;

  InvoiceItemModel({
    required this.date,
    required this.customerName,
    required this.itemName,
    required this.price,
    required this.note,
    required this.isPaid,
  });
}
