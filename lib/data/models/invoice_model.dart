import 'package:hive/hive.dart';

import 'invoice_item_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  List<InvoiceItemModel> items;

  InvoiceModel({required String title, required List<InvoiceItemModel> items})
    : title = title.trim(),
      items = List<InvoiceItemModel>.of(items, growable: true);

  int get itemCount => items.length;

  double get total {
    var value = 0.0;

    for (final item in items) {
      value += item.price;
    }

    return value;
  }

  double get paidTotal {
    var value = 0.0;

    for (final item in items) {
      value += item.paidValue;
    }

    return value;
  }

  double get unpaidTotal {
    var value = 0.0;

    for (final item in items) {
      value += item.remainingValue;
    }

    return value;
  }

  bool get hasUnpaidItems {
    for (final item in items) {
      if (!item.isPaid && item.remainingValue > 0) {
        return true;
      }
    }

    return false;
  }

  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? 'فاتورة بدون عنوان' : value;
  }
}
