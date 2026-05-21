import 'package:hive/hive.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String? customerName;

  @HiveField(2)
  String itemName;

  @HiveField(3)
  double price;

  @HiveField(4)
  String? note;

  @HiveField(5)
  bool isPaid;

  @HiveField(6)
  double paidAmount;

  InvoiceItemModel({
    DateTime? date,
    this.customerName,
    required String itemName,
    required double price,
    this.note,
    required bool isPaid,
    double? paidAmount,
  }) : date = date ?? DateTime.now(),
       itemName = itemName.trim(),
       price = price < 0 ? 0.0 : price,
       isPaid = isPaid,
       paidAmount = paidAmount ?? (isPaid ? price : 0.0) {
    normalizePaymentState();
  }

  double get paidValue => isPaid ? price : _clampPayment(paidAmount, price);

  double get remainingValue {
    final value = price - paidValue;
    return value <= 0 ? 0.0 : value;
  }

  bool get hasPartialPayment => !isPaid && paidValue > 0;

  String get displayCustomerName {
    final value = customerName?.trim();
    return value == null || value.isEmpty ? 'عميل غير معروف' : value;
  }

  String get displayItemName {
    final value = itemName.trim();
    return value.isEmpty ? 'بدون اسم صنف' : value;
  }

  String get displayNote {
    final value = note?.trim();
    return value == null || value.isEmpty ? 'لا توجد ملاحظات' : value;
  }

  void normalizePaymentState() {
    itemName = itemName.trim();
    price = price < 0 ? 0.0 : price;
    paidAmount = _clampPayment(isPaid ? price : paidAmount, price);
    isPaid = price > 0 && paidAmount >= price;
  }

  static double _clampPayment(double value, double price) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > price) return price;
    return value;
  }
}
