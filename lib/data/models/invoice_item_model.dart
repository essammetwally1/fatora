import 'package:hive/hive.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String? deprecatedCustomerName;

  @HiveField(2)
  String itemName;

  @HiveField(3)
  double price;

  @HiveField(4)
  String? note;

  // Legacy payment fields. Keep them to support old Hive data.
  @HiveField(5)
  bool isPaid;

  @HiveField(6)
  double paidAmount;

  InvoiceItemModel({
    DateTime? date,
    this.deprecatedCustomerName,
    required String itemName,
    required double price,
    this.note,
    bool isPaid = false,
    double? paidAmount,
  }) : date = date ?? DateTime.now(),
       itemName = itemName.trim(),
       price = _safePositive(price),
       isPaid = isPaid,
       paidAmount = paidAmount ?? (isPaid ? _safePositive(price) : 0.0) {
    normalizeLegacyPaymentState();
  }

  String get displayItemName {
    final value = itemName.trim();
    return value.isEmpty ? 'بدون اسم صنف' : value;
  }

  String get displayNote {
    final value = note?.trim();
    return value == null || value.isEmpty ? 'لا توجد ملاحظات' : value;
  }

  double get legacyPaidValue => _clampPayment(paidAmount, price);

  bool get hasLegacyPayment => legacyPaidValue > 0;

  void normalizeBasicData() {
    itemName = itemName.trim();
    price = _safePositive(price);
  }

  void normalizeLegacyPaymentState() {
    normalizeBasicData();
    paidAmount = _clampPayment(paidAmount, price);
    isPaid = price > 0 && paidAmount >= price;
  }

  void clearLegacyPaymentState() {
    paidAmount = 0.0;
    isPaid = false;
  }

  static double _safePositive(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    return value;
  }

  static double _clampPayment(double value, double price) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    if (value > price) return price;
    return value;
  }
}
