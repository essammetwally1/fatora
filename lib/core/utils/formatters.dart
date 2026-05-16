// formatters.dart

import 'package:intl/intl.dart';

class Formatters {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy - hh:mm a', 'ar').format(date);
  }

  static String formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'ar',
      symbol: 'ج.م',
      decimalDigits: 2,
    ).format(value);
  }
}
