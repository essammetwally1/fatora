import 'package:hive/hive.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String? customerName;

  @HiveField(2)
  String? itemName;

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
    this.itemName,
    required this.price,
    this.note,
    required this.isPaid,
    double? paidAmount,
  }) : date = date ?? DateTime.now(),
       paidAmount = paidAmount ?? (isPaid ? price : 0.0) {
    _normalizePaymentState();
  }

  double get paidValue => isPaid ? price : _clampPayment(paidAmount, price);

  double get remainingValue => price - paidValue;

  bool get hasPartialPayment => !isPaid && paidValue > 0;

  String get displayCustomerName {
    final value = customerName?.trim();
    return value == null || value.isEmpty ? 'عميل غير معروف' : value;
  }

  String get displayItemName {
    final value = itemName?.trim();
    return value == null || value.isEmpty ? 'بدون اسم صنف' : value;
  }

  String get displayNote {
    final value = note?.trim();
    return value == null || value.isEmpty ? 'لا توجد ملاحظات' : value;
  }

  void _normalizePaymentState() {
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
