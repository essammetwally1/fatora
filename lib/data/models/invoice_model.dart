import 'package:hive/hive.dart';

import 'invoice_item_model.dart';
import 'invoice_payment_entry_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  static final DateTime legacyCreatedAt = DateTime(2000, 1, 1);

  /// Amounts closer together than this are the same amount.
  ///
  /// Money is stored as `double`, so a chain of additions and subtractions
  /// leaves dust like `1e-13`. Comparing against zero without a tolerance made
  /// that dust look like an unexplained balance.
  static const double _moneyTolerance = 0.000001;

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

  /// Dated payments and returns, oldest first.
  ///
  /// Added after release, so every invoice stored by an older version arrives
  /// with `null` here and is defaulted to an empty list. An empty history does
  /// not mean nothing was paid — see [unrecordedPaidAmount], which reports the
  /// part of [paidTotal] that predates this field rather than pretending it
  /// was never paid or inventing a date for it.
  @HiveField(4, defaultValue: <InvoicePaymentEntryModel>[])
  List<InvoicePaymentEntryModel> payments;

  /// Keeps the dated breakdown off the printed receipt and the exported image.
  ///
  /// Only the presentation changes: the entries stay stored, the totals row
  /// still prints, and turning it back on reprints the same history. Stored as
  /// "hide" rather than "show" so an invoice written before this field existed
  /// arrives as `false` and keeps printing exactly what it printed yesterday.
  @HiveField(5, defaultValue: false)
  bool hidePaymentDetailsInExport;

  /// Marks an invoice the user wants to find again quickly.
  ///
  /// Defaults to `false`, so nothing already on the phone becomes starred by
  /// the upgrade.
  @HiveField(6, defaultValue: false)
  bool isStarred;

  InvoiceModel({
    required String title,
    required List<InvoiceItemModel> items,
    double paidAmount = 0.0,
    this.createdAt,
    List<InvoicePaymentEntryModel>? payments,
    this.hidePaymentDetailsInExport = false,
    this.isStarred = false,
  }) : title = title.trim(),
       items = List<InvoiceItemModel>.of(items, growable: true),
       paidAmount = _safePositive(paidAmount),
       payments = List<InvoicePaymentEntryModel>.of(
         payments ?? const <InvoicePaymentEntryModel>[],
         growable: true,
       ) {
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

  /// Signed sum of every recorded movement.
  double get recordedPaymentsNet {
    var value = 0.0;

    for (final payment in payments) {
      value += payment.signedAmount;
    }

    return value;
  }

  double get recordedPaymentsTotal {
    var value = 0.0;

    for (final payment in payments) {
      if (payment.isPayment) value += payment.amount;
    }

    return value;
  }

  double get recordedReturnsTotal {
    var value = 0.0;

    for (final payment in payments) {
      if (payment.isReturn) value += payment.amount;
    }

    return value;
  }

  /// The part of [paidTotal] that no recorded entry accounts for.
  ///
  /// Positive on an invoice paid before payment history existed, and on one
  /// whose payment was promoted from the old per-item fields. Negative only if
  /// [paidTotal] was clamped down below what the entries add up to. Reporting
  /// it lets the printed breakdown always sum to [paidTotal] without either
  /// dropping money or stamping a made-up date on it.
  double get unrecordedPaidAmount {
    final difference = paidTotal - recordedPaymentsNet;

    return difference.abs() <= _moneyTolerance ? 0.0 : difference;
  }

  bool get hasPaymentHistory => payments.isNotEmpty;

  /// Whether the PDF and the image print the dated breakdown.
  bool get printsPaymentDetails => !hidePaymentDetailsInExport;

  /// Recorded movements, oldest first.
  ///
  /// Entries are appended in order, so this is normally already sorted; the
  /// copy exists so callers cannot mutate the stored list, and the sort keeps
  /// it correct if an entry was ever back-dated.
  List<InvoicePaymentEntryModel> get paymentsOldestFirst {
    if (payments.length < 2) {
      return List<InvoicePaymentEntryModel>.unmodifiable(payments);
    }

    final sorted = List<InvoicePaymentEntryModel>.of(payments)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return List<InvoicePaymentEntryModel>.unmodifiable(sorted);
  }

  List<InvoicePaymentEntryModel> get paymentsNewestFirst {
    return List<InvoicePaymentEntryModel>.unmodifiable(
      paymentsOldestFirst.reversed,
    );
  }

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

    for (final payment in payments) {
      payment.normalize();
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

  // Deliberately no `clearLegacyItemPayments()`. Wiping the per-item
  // `isPaid`/`paidAmount` of an old invoice destroys the only record of which
  // items it was paid for, and buys nothing: `paidTotal` already ignores those
  // fields once `paidAmount` is positive. See `migrateLegacyPaymentToInvoice-
  // PaymentIfNeeded`, which promotes without erasing.

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
