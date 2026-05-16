// invoice_model.dart

import 'package:hive/hive.dart';

import 'invoice_item_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  List<InvoiceItemModel> items;

  InvoiceModel({required this.title, required this.items});

  double get total {
    return items.fold(0.0, (sum, item) => sum + item.price);
  }

  double get paidTotal {
    return items.fold(0.0, (sum, item) => sum + item.paidValue);
  }

  double get unpaidTotal {
    return items.fold(0.0, (sum, item) => sum + item.remainingValue);
  }
}
