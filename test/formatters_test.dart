import 'package:fatora/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('formatMoney', () {
    test('uses the Egyptian pound symbol', () {
      // Regression guard: this read "م.ج" while the home totals card read
      // "ج.م", so one screen showed two different currency labels.
      expect(Formatters.currencySymbol, 'ج.م');
      expect(Formatters.formatMoney(25), endsWith('ج.م'));
      expect(Formatters.formatMoneyCompact(25), endsWith('ج.م'));
    });

    test('groups thousands and always shows two decimals', () {
      expect(Formatters.formatMoney(1234.5), '1,234.50 ج.م');
      expect(Formatters.formatMoney(0), '0.00 ج.م');
    });

    test('compact form rounds and omits decimals', () {
      expect(Formatters.formatMoneyCompact(1234.5), '1,235 ج.م');
      expect(Formatters.formatMoneyCompact(999), '999 ج.م');
    });

    test('both forms survive non-finite input', () {
      expect(Formatters.formatMoney(double.nan), '0.00 ج.م');
      expect(Formatters.formatMoney(double.infinity), '0.00 ج.م');
      expect(Formatters.formatMoneyCompact(double.nan), '0 ج.م');
    });

    test('agree on the same value apart from rounding', () {
      expect(Formatters.formatMoney(1000), '1,000.00 ج.م');
      expect(Formatters.formatMoneyCompact(1000), '1,000 ج.م');
    });
  });

  group('isSameDay', () {
    test('matches only on identical calendar dates', () {
      expect(
        Formatters.isSameDay(DateTime(2026, 3, 4, 1), DateTime(2026, 3, 4, 23)),
        isTrue,
      );
      expect(
        Formatters.isSameDay(DateTime(2026, 3, 4), DateTime(2026, 3, 5)),
        isFalse,
      );
      expect(
        Formatters.isSameDay(DateTime(2025, 3, 4), DateTime(2026, 3, 4)),
        isFalse,
      );
    });
  });

  group('formatInvoiceDayLabel', () {
    test('labels legacy invoices regardless of date', () {
      expect(
        Formatters.formatInvoiceDayLabel(DateTime(2000), isLegacy: true),
        'فواتير قديمة',
      );
    });

    test('labels today and yesterday relatively', () {
      final now = DateTime.now();

      expect(Formatters.formatInvoiceDayLabel(now, isLegacy: false), 'اليوم');

      expect(
        Formatters.formatInvoiceDayLabel(
          DateTime(now.year, now.month, now.day - 1),
          isLegacy: false,
        ),
        'أمس',
      );
    });

    test('falls back to an absolute date for older days', () {
      final label = Formatters.formatInvoiceDayLabel(
        DateTime(2024, 1, 15),
        isLegacy: false,
      );

      expect(label, isNot('اليوم'));
      expect(label, isNot('أمس'));
      expect(label, contains('2024'));
    });
  });
}
