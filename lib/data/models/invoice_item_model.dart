import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 0)
class InvoiceItemModel extends HiveObject {
  static final Uuid _uuid = Uuid();

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

  // Stable item identifier.
  //
  // defaultValue is required because old Hive records do not contain field 7.
  // New items receive a UUID immediately, while old items will be migrated
  // safely in the repository.
  @HiveField(7, defaultValue: '')
  String id;

  InvoiceItemModel({
    String? id,
    DateTime? date,
    this.deprecatedCustomerName,
    required String itemName,
    required double price,
    this.note,
    bool isPaid = false,
    double? paidAmount,
  }) : id = _normalizeId(id) ?? _uuid.v4(),
       date = date ?? DateTime.now(),
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

  /// Ensures that old Hive items receive a persistent stable identifier.
  ///
  /// Returns true when the item was changed and the containing invoice
  /// therefore needs to be saved.
  bool ensureStableId() {
    final normalizedId = _normalizeId(id);

    if (normalizedId != null) {
      if (normalizedId == id) {
        return false;
      }

      id = normalizedId;
      return true;
    }

    id = _uuid.v4();
    return true;
  }

  void regenerateId() {
    id = _uuid.v4();
  }

  void normalizeBasicData() {
    id = id.trim();
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

  static String? _normalizeId(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
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
