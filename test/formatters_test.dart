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

  // The exported PDF lays the digits and the symbol out as two runs with
  // opposite directions, because one run forced either way prints the other
  // half backwards — "ج.م" came out as "م.ج" in every money cell. That split
  // is only correct as long as an amount really does end in the symbol.
  group('splitting a money string for the export', () {
    test('separates the digits from the currency symbol', () {
      final money = Formatters.splitMoney(Formatters.formatMoney(1250));

      expect(money, isNotNull);
      expect(money!.amount, '1,250.00');
      expect(money.symbol, Formatters.currencySymbol);
    });

    test('keeps a return\'s minus sign with the digits', () {
      final money = Formatters.splitMoney('- ${Formatters.formatMoney(50)}');

      expect(money!.amount, '- 50.00');
      expect(money.symbol, Formatters.currencySymbol);
    });

    test('splits the compact form too', () {
      final money = Formatters.splitMoney(Formatters.formatMoneyCompact(1250));

      expect(money!.amount, '1,250');
    });

    test('rejects a string that is not an amount', () {
      expect(Formatters.splitMoney('الإجمالي'), isNull);
      expect(Formatters.splitMoney(Formatters.currencySymbol), isNull);
      expect(Formatters.splitMoney(''), isNull);
    });

    test('recomposes into exactly what was formatted', () {
      for (final value in [0, 0.5, 999.99, 1234567.89, -20]) {
        final formatted = Formatters.formatMoney(value);
        final money = Formatters.splitMoney(formatted)!;

        expect('${money.amount} ${money.symbol}', formatted);
      }
    });
  });
}
