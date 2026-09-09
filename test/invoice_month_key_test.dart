import 'package:fatora/data/models/invoice_month_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('InvoiceMonthKey.legacy', () {
    test('is flagged as legacy and labelled without a month name', () {
      const legacy = InvoiceMonthKey.legacy();

      expect(legacy.isLegacy, isTrue);
      expect(legacy.labelAr, 'فواتير قديمة');
    });

    test('real months are never legacy', () {
      const march = InvoiceMonthKey(year: 2026, month: 3);

      expect(march.isLegacy, isFalse);
      expect(march, isNot(const InvoiceMonthKey.legacy()));
    });

    test('sorts after every real month, so it never displaces one', () {
      final months = <InvoiceMonthKey>[
        const InvoiceMonthKey(year: 2025, month: 1),
        const InvoiceMonthKey.legacy(),
        const InvoiceMonthKey(year: 2026, month: 8),
        const InvoiceMonthKey(year: 2026, month: 2),
      ]..sort();

      expect(months.first, const InvoiceMonthKey(year: 2026, month: 8));
      expect(months.last, const InvoiceMonthKey.legacy());
    });

    test('claims no real date, because it is defined by a missing one', () {
      const legacy = InvoiceMonthKey.legacy();

      expect(legacy.contains(DateTime(2026, 8, 29)), isFalse);
      expect(legacy.contains(DateTime(2000, 1, 1)), isFalse);
    });

    test('two legacy keys are the same bucket', () {
      expect(const InvoiceMonthKey.legacy(), const InvoiceMonthKey.legacy());

      expect(
        const InvoiceMonthKey.legacy().hashCode,
        const InvoiceMonthKey.legacy().hashCode,
      );
    });
  });

  group('InvoiceMonthKey', () {
    test('fromDate takes the local year and month', () {
      final key = InvoiceMonthKey.fromDate(DateTime(2026, 3, 17, 22, 40));

      expect(key.year, 2026);
      expect(key.month, 3);
    });

    test('contains only its own month', () {
      const march = InvoiceMonthKey(year: 2026, month: 3);

      expect(march.contains(DateTime(2026, 3, 1)), isTrue);
      expect(march.contains(DateTime(2026, 3, 31, 23, 59)), isTrue);
      expect(march.contains(DateTime(2026, 4, 1)), isFalse);
      expect(march.contains(DateTime(2025, 3, 15)), isFalse);
    });

    test('current resolves from an injected clock', () {
      final key = InvoiceMonthKey.current(DateTime(2026, 8, 29));

      expect(key, const InvoiceMonthKey(year: 2026, month: 8));
    });
  });
}
