import 'package:hive/hive.dart';

import 'invoice_item_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  List<InvoiceItemModel> items;
  @HiveField(2, defaultValue: 0.0)
  double paidAmount;

  InvoiceModel({
    required String title,
    required List<InvoiceItemModel> items,
    double paidAmount = 0.0,
  }) : title = title.trim(),
       items = List<InvoiceItemModel>.of(items, growable: true),
       paidAmount = paidAmount < 0 || paidAmount.isNaN || paidAmount.isInfinite
           ? 0.0
           : paidAmount;
  int get itemCount => items.length;

  double get total {
    var value = 0.0;
    for (final item in items) {
      value += item.price;
    }
    return value;
  }

  double get paidTotal {
    if (paidAmount.isNaN || paidAmount.isInfinite || paidAmount < 0) return 0.0;
    if (paidAmount > total) return total;
    return paidAmount;
  }

  double get unpaidTotal {
    final value = total - paidTotal;
    return value <= 0 ? 0.0 : value;
  }

  bool get hasUnpaidItems => unpaidTotal > 0;
  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? 'فاتورة بدون عنوان' : value;
  }

  bool get isPaymentCompleted => itemCount > 0 && total > 0 && unpaidTotal <= 0;
  bool get canEditItems => !isPaymentCompleted;
}
