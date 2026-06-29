import 'package:intl/intl.dart';

class Formatters {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy - hh:mm a', 'ar').format(date);
  }

  static String formatDateOnly(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'ar').format(date);
  }

  static String formatInvoiceDayLabel(DateTime date, {required bool isLegacy}) {
    if (isLegacy) return 'فواتير قديمة';

    final now = DateTime.now();

    if (isSameDay(date, now)) return 'اليوم';

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (isSameDay(date, yesterday)) return 'أمس';

    return formatDateOnly(date);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatMoney(num value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(value)} م.ج';
  }
}
