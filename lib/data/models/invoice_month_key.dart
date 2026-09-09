import 'package:intl/intl.dart';

class InvoiceMonthKey implements Comparable<InvoiceMonthKey> {
  static final DateFormat _arabicFormatter = DateFormat('MMMM yyyy', 'ar');

  /// Sentinel year for the bucket holding invoices that have no `createdAt`.
  ///
  /// Invoices created before v1.1.10 never recorded a date, and it cannot be
  /// recovered. They used to be folded into whatever month happened to be
  /// current, which added their money to that month's totals and moved them
  /// forward again at every rollover. They now live in a bucket of their own:
  /// still listed, still editable, still printable — just never counted as
  /// business done in a month they may have nothing to do with.
  static const int legacyYear = 0;

  final int year;
  final int month;

  const InvoiceMonthKey({required this.year, required this.month})
    : assert(month >= 1 && month <= 12);

  /// The bucket for undated (pre-v1.1.10) invoices.
  const InvoiceMonthKey.legacy() : year = legacyYear, month = 1;

  factory InvoiceMonthKey.fromDate(DateTime date) {
    final localDate = date.toLocal();

    return InvoiceMonthKey(year: localDate.year, month: localDate.month);
  }

  static InvoiceMonthKey current([DateTime? now]) {
    return InvoiceMonthKey.fromDate(now ?? DateTime.now());
  }

  bool get isLegacy => year == legacyYear;

  DateTime get start => DateTime(year, month);

  DateTime get nextMonthStart {
    return DateTime(year, month + 1);
  }

  String get labelAr {
    if (isLegacy) return 'فواتير قديمة';

    return _arabicFormatter.format(start);
  }

  bool contains(DateTime date) {
    // No real date belongs to the legacy bucket; membership there is decided
    // by the absence of `createdAt`, never by the value of a date.
    if (isLegacy) return false;

    final localDate = date.toLocal();

    return localDate.year == year && localDate.month == month;
  }

  int compareNewestFirst(InvoiceMonthKey other) {
    final yearComparison = other.year.compareTo(year);

    if (yearComparison != 0) {
      return yearComparison;
    }

    return other.month.compareTo(month);
  }

  @override
  int compareTo(InvoiceMonthKey other) {
    return compareNewestFirst(other);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InvoiceMonthKey && year == other.year && month == other.month;
  }

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() {
    return '$year-${month.toString().padLeft(2, '0')}';
  }
}
