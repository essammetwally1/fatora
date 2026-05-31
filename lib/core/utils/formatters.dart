import 'package:intl/intl.dart';

class Formatters {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy - hh:mm a', 'ar').format(date);
  }

  static String formatMoney(num value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(value)} م.ج';
  }
}
