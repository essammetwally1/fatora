import 'package:intl/intl.dart';

class InvoiceMonthKey implements Comparable<InvoiceMonthKey> {
  static final DateFormat _arabicFormatter = DateFormat('MMMM yyyy', 'ar');

  final int year;
  final int month;

  const InvoiceMonthKey({required this.year, required this.month})
    : assert(month >= 1 && month <= 12);

  factory InvoiceMonthKey.fromDate(DateTime date) {
    final localDate = date.toLocal();

    return InvoiceMonthKey(year: localDate.year, month: localDate.month);
  }

  static InvoiceMonthKey current([DateTime? now]) {
    return InvoiceMonthKey.fromDate(now ?? DateTime.now());
  }

  DateTime get start => DateTime(year, month);

  DateTime get nextMonthStart {
    return DateTime(year, month + 1);
  }

  String get labelAr {
    return _arabicFormatter.format(start);
  }

  bool contains(DateTime date) {
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
