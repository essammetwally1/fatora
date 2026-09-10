import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  /// Egyptian pound. Written "ج.م" (جنيه مصري).
  ///
  /// This used to be "م.ج" here and "ج.م" in the home totals card, so the two
  /// halves of the same screen disagreed with each other.
  static const String currencySymbol = 'ج.م';

  /// `DateFormat`/`NumberFormat` parse their pattern on construction, so these
  /// are built once instead of on every call. `formatMoney` in particular runs
  /// for every item, every card, on every rebuild.
  static final DateFormat _dateTimeFormat = DateFormat(
    'dd MMMM yyyy - hh:mm a',
    'ar',
  );

  static final DateFormat _dateOnlyFormat = DateFormat('dd MMMM yyyy', 'ar');

  /// Compact numeric date for the dense payment-history rows, where the full
  /// month name does not fit.
  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy', 'ar');

  /// 12-hour clock with the Arabic ص/م marker, as printed on the receipt.
  static final DateFormat _clockFormat = DateFormat('hh:mm a', 'ar');

  static final NumberFormat _moneyFormat = NumberFormat('#,##0.00', 'en_US');

  static final NumberFormat _compactMoneyFormat = NumberFormat(
    '#,##0',
    'en_US',
  );

  static String formatDate(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  static String formatDateOnly(DateTime date) {
    return _dateOnlyFormat.format(date);
  }

  static String formatInvoiceDayLabel(DateTime date, {required bool isLegacy}) {
    if (isLegacy) return 'فواتير قديمة';

    final now = DateTime.now();

    if (isSameDay(date, now)) return 'اليوم';

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (isSameDay(date, yesterday)) return 'أمس';

    return formatDateOnly(date);
  }

  /// The date printed on an invoice document (the PDF).
  ///
  /// Takes the invoice's own `createdAt`, never the clock — a PDF represents
  /// stored historical state, so reprinting a January invoice in August must
  /// still say January.
  ///
  /// Invoices created before v1.1.10 never recorded a date and it cannot be
  /// recovered, so they say so rather than being stamped with today or with
  /// the year-2000 sentinel `listDate` uses for sorting. Inventing a date on a
  /// historical accounting document is worse than admitting there isn't one.
  static String formatInvoiceDocumentDate(DateTime? createdAt) {
    if (createdAt == null) return 'فاتورة قديمة';

    return formatDate(createdAt);
  }

  /// Date of a payment or return, e.g. `10/09/2026`.
  ///
  /// Render it left-to-right: the separators would otherwise be reordered by
  /// the surrounding right-to-left paragraph.
  static String formatPaymentDate(DateTime dateTime) {
    return _shortDateFormat.format(dateTime.toLocal());
  }

  /// Time of a payment or return on a 12-hour clock, e.g. `03:45 م`.
  static String formatPaymentTime(DateTime dateTime) {
    return _clockFormat.format(dateTime.toLocal());
  }

  /// Both halves in one string, for single-line contexts.
  static String formatPaymentDateTime(DateTime dateTime) {
    return '${formatPaymentDate(dateTime)} - ${formatPaymentTime(dateTime)}';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Full precision, e.g. `1,250.00 ج.م`. Use for any exact amount.
  static String formatMoney(num value) {
    return '${_moneyFormat.format(_safe(value))} $currencySymbol';
  }

  /// Rounded, e.g. `1,250 ج.م`. Use only where space is tight and the exact
  /// piastres do not matter, such as the collapsed totals header.
  static String formatMoneyCompact(num value) {
    return '${_compactMoneyFormat.format(_safe(value).round())} $currencySymbol';
  }

  /// Splits a formatted money string back into its digits and its symbol.
  ///
  /// The PDF has to lay the two halves out as separate runs — the digits
  /// left-to-right, the symbol right-to-left — because a single run forced one
  /// way prints one of them backwards. Doing the split here keeps it beside
  /// [formatMoney], so a change to how an amount is composed cannot leave the
  /// export quietly splitting it at the wrong place.
  ///
  /// Returns null when [text] does not end in the currency symbol.
  static ({String amount, String symbol})? splitMoney(String text) {
    if (!text.endsWith(currencySymbol)) return null;

    final amount = text
        .substring(0, text.length - currencySymbol.length)
        .trimRight();

    if (amount.isEmpty) return null;

    return (amount: amount, symbol: currencySymbol);
  }

  static num _safe(num value) => value.isFinite ? value : 0;
}
