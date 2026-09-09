import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'invoice_payment_entry_model.g.dart';

/// One recorded movement of money on an invoice: a payment in, or a return
/// out.
///
/// Before this existed the invoice stored only a running `paidAmount`, so the
/// receipt could say *how much* had been paid but never *when* — which meant a
/// printed invoice could not be reconciled against a day's takings. Each entry
/// is immutable once written: corrections are made by recording the opposite
/// movement, never by rewriting history.
@HiveType(typeId: 3)
class InvoicePaymentEntryModel extends HiveObject {
  static final Uuid _uuid = Uuid();

  /// Stable identifier, so an entry can be addressed in a list without
  /// depending on its position.
  @HiveField(0, defaultValue: '')
  String id;

  /// Magnitude only. The direction lives in [isReturn], so a stored amount is
  /// never negative and cannot be misread as a credit by accident.
  @HiveField(1, defaultValue: 0.0)
  double amount;

  @HiveField(2, defaultValue: false)
  bool isReturn;

  @HiveField(3)
  DateTime createdAt;

  InvoicePaymentEntryModel({
    String? id,
    required double amount,
    this.isReturn = false,
    DateTime? createdAt,
  }) : id = _normalizeId(id) ?? _uuid.v4(),
       amount = _safePositive(amount),
       createdAt = createdAt ?? DateTime.now();

  /// Positive for a payment, negative for a return.
  double get signedAmount => isReturn ? -amount : amount;

  bool get isPayment => !isReturn;

  String get labelAr => isReturn ? 'مرتجع' : 'دفعة';

  void normalize() {
    id = id.trim();
    amount = _safePositive(amount);
  }

  /// Back-fills a persistent identifier on an entry that predates [id] being
  /// written, mirroring `InvoiceItemModel.ensureStableId`.
  ///
  /// Returns true when the entry changed and therefore needs saving.
  bool ensureStableId() {
    final normalizedId = _normalizeId(id);

    if (normalizedId != null) {
      if (normalizedId == id) return false;

      id = normalizedId;
      return true;
    }

    id = _uuid.v4();
    return true;
  }

  void regenerateId() {
    id = _uuid.v4();
  }

  static String? _normalizeId(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) return null;

    return normalized;
  }

  static double _safePositive(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    return value;
  }
}
