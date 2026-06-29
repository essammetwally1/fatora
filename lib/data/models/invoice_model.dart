import 'package:hive/hive.dart';

import 'invoice_item_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  static final DateTime legacyCreatedAt = DateTime(2000, 1, 1);

  @HiveField(0)
  String title;

  @HiveField(1)
  List<InvoiceItemModel> items;

  @HiveField(2, defaultValue: 0.0)
  double paidAmount;

  // New field.
  // Nullable intentionally:
  // Old Hive invoices will have null createdAt, so we can group them safely
  // under one old/legacy day without corrupting old data.
  @HiveField(3)
  DateTime? createdAt;

  InvoiceModel({
    required String title,
    required List<InvoiceItemModel> items,
    double paidAmount = 0.0,
    this.createdAt,
  }) : title = title.trim(),
       items = List<InvoiceItemModel>.of(items, growable: true),
       paidAmount = _safePositive(paidAmount) {
    normalizeBasicData();
  }

  int get itemCount => items.length;

  DateTime get listDate => createdAt ?? legacyCreatedAt;

  bool get isLegacyDate => createdAt == null;

  double get total {
    var value = 0.0;
    for (final item in items) {
      value += _safePositive(item.price);
    }
    return value;
  }

  double get legacyItemsPaidTotal {
    var value = 0.0;
    for (final item in items) {
      value += item.legacyPaidValue;
    }
    return _clamp(value, total);
  }

  bool get hasLegacyItemPayments => legacyItemsPaidTotal > 0;

  double get paidTotal {
    final invoicePaid = _clamp(paidAmount, total);

    // Supports old Hive data that stored payment inside items
    // before invoice.paidAmount existed.
    if (invoicePaid <= 0 && hasLegacyItemPayments) {
      return legacyItemsPaidTotal;
    }

    return invoicePaid;
  }

  double get unpaidTotal {
    final value = total - paidTotal;
    return value <= 0 ? 0.0 : value;
  }

  bool get hasUnpaidItems => unpaidTotal > 0;

  bool get isPaymentCompleted => itemCount > 0 && total > 0 && unpaidTotal <= 0;

  bool get canEditItems => !isPaymentCompleted;

  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? 'فاتورة بدون عنوان' : value;
  }

  void normalizeBasicData() {
    title = title.trim();
    paidAmount = _clamp(paidAmount, total);

    for (final item in items) {
      item.normalizeBasicData();
    }
  }

  void migrateLegacyPaymentToInvoicePaymentIfNeeded() {
    if (paidAmount > 0) {
      paidAmount = _clamp(paidAmount, total);
      return;
    }

    final legacyPaid = legacyItemsPaidTotal;
    if (legacyPaid > 0) {
      paidAmount = _clamp(legacyPaid, total);
    }
  }

  void clearLegacyItemPayments() {
    for (final item in items) {
      item.clearLegacyPaymentState();
    }
  }

  static double _safePositive(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    return value;
  }

  static double _clamp(double value, double max) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    if (value > max) return max;
    return value;
  }
}
