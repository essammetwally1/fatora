import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_month_key.dart';
import 'package:fatora/data/repositories/invoice_repository.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = HiveTestEnv();

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() => env.setUp());
  tearDown(() => env.tearDown());

  group('a pre-v1.1.10 invoice', () {
    test('loads, and totals from its items', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [
          (name: 'عدسة', price: 250.0, paid: 250.0),
          (name: 'إطار', price: 150.0, paid: 0.0),
        ],
      );

      await HiveService.getInvoiceBox().add(invoice);

      final loaded = InvoiceRepository().getInvoices();

      expect(loaded, hasLength(1));
      expect(loaded.single.total, 400.0);
      expect(loaded.single.isLegacyDate, isTrue);
    });

    test('reports payment recorded on its items, before any migration', () {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [
          (name: 'عدسة', price: 250.0, paid: 250.0),
          (name: 'إطار', price: 150.0, paid: 0.0),
        ],
      );

      expect(invoice.paidAmount, 0.0);
      expect(invoice.paidTotal, 250.0);
      expect(invoice.unpaidTotal, 150.0);
    });

    test(
      'migration promotes payment to the invoice without erasing it',
      () async {
        final invoice = buildLegacyInvoice(
          title: 'عميل قديم',
          items: [
            (name: 'عدسة', price: 250.0, paid: 250.0),
            (name: 'إطار', price: 150.0, paid: 0.0),
          ],
        );

        await HiveService.getInvoiceBox().add(invoice);

        await InvoiceRepository().migrateStoredInvoices();

        final migrated = InvoiceRepository().getInvoices().single;

        expect(migrated.paidAmount, 250.0);
        expect(migrated.paidTotal, 250.0);

        // The original per-item record is the only evidence of *which* items
        // were paid for. Promotion must not consume it.
        expect(migrated.items.first.paidAmount, 250.0);
        expect(migrated.items.first.isPaid, isTrue);

        // And every item ends up individually addressable.
        expect(
          migrated.items.every((item) => item.id.trim().isNotEmpty),
          isTrue,
        );
        expect(
          migrated.items.map((item) => item.id).toSet(),
          hasLength(migrated.items.length),
        );
      },
    );

    test('migration is idempotent', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [(name: 'عدسة', price: 250.0, paid: 250.0)],
      );

      await HiveService.getInvoiceBox().add(invoice);

      final repository = InvoiceRepository();

      await repository.migrateStoredInvoices();
      final firstPass = repository.getInvoices().single.paidAmount;

      await repository.migrateStoredInvoices();
      final secondPass = repository.getInvoices().single.paidAmount;

      expect(secondPass, firstPass);
      expect(HiveService.getInvoiceBox().length, 1);
    });
  });

  group('recording a payment on a legacy invoice', () {
    test('keeps the per-item payment history intact', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [
          (name: 'عدسة', price: 250.0, paid: 250.0),
          (name: 'إطار', price: 150.0, paid: 0.0),
        ],
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      // 250 was already paid against the items, so this settles the rest.
      final updated = await InvoiceRepository().applyPaidDelta(
        invoiceKey: key,
        deltaAmount: 150.0,
      );

      expect(updated, isNotNull);
      expect(updated!.paidTotal, 400.0);

      expect(updated.items.first.paidAmount, 250.0);
      expect(updated.items.first.isPaid, isTrue);
    });

    test('editing an item keeps that item\'s payment history intact', () async {
      // Part-paid, because a fully paid invoice correctly refuses item edits.
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [(name: 'عدسة', price: 250.0, paid: 100.0)],
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      // The sheet always hands the repository a freshly built item with a
      // zeroed payment state; the stored one has to be carried across.
      final replacement = InvoiceItemModel(
        itemName: 'عدسة مضادة للانعكاس',
        price: 300.0,
      );

      final updated = await InvoiceRepository().updateItem(
        invoiceKey: key,
        index: 0,
        item: replacement,
      );

      expect(updated, isNotNull);
      expect(updated!.items.single.itemName, 'عدسة مضادة للانعكاس');
      expect(updated.items.single.price, 300.0);
      expect(updated.items.single.paidAmount, 100.0);

      // Totals are unaffected by preserving the legacy fields: payment was
      // promoted to the invoice, and that is what `paidTotal` reads.
      expect(updated.paidTotal, 100.0);
      expect(updated.unpaidTotal, 200.0);
    });

    test('a fully paid legacy invoice still refuses item edits', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [(name: 'عدسة', price: 250.0, paid: 250.0)],
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      expect(invoice.isPaymentCompleted, isTrue);

      final updated = await InvoiceRepository().updateItem(
        invoiceKey: key,
        index: 0,
        item: InvoiceItemModel(itemName: 'أخرى', price: 300.0),
      );

      expect(updated, isNull);
    });
  });

  group('month grouping', () {
    test(
      'undated invoices form their own bucket, not the current month',
      () async {
        final box = HiveService.getInvoiceBox();

        await box.add(
          buildLegacyInvoice(
            title: 'عميل قديم',
            items: [(name: 'عدسة', price: 400.0, paid: 0.0)],
          ),
        );

        await box.add(
          InvoiceModel(
            title: 'عميل حالي',
            items: [InvoiceItemModel(itemName: 'إطار', price: 100.0)],
            createdAt: DateTime.now(),
          ),
        );

        final provider = InvoiceProvider();
        provider.loadInvoices(notify: false);

        // The 400 belongs to the legacy bucket and must not inflate this month.
        expect(provider.currentMonthTotals.total, 100.0);
        expect(provider.currentMonthTotals.invoiceCount, 1);

        final legacyTotals = provider.totalsForMonth(
          const InvoiceMonthKey.legacy(),
        );

        expect(legacyTotals.total, 400.0);
        expect(legacyTotals.invoiceCount, 1);
      },
    );

    test('the legacy bucket is browsable and never marked current', () async {
      await HiveService.getInvoiceBox().add(
        buildLegacyInvoice(
          title: 'عميل قديم',
          items: [(name: 'عدسة', price: 400.0, paid: 0.0)],
        ),
      );

      final provider = InvoiceProvider();
      provider.loadInvoices(notify: false);

      final snapshot = provider.monthSnapshot(const InvoiceMonthKey.legacy());

      expect(snapshot, isNotNull);
      expect(snapshot!.isCurrentMonth, isFalse);
      expect(snapshot.invoices.single.displayTitle, 'عميل قديم');

      // It sorts last, after the always-present current month.
      expect(provider.invoiceMonths.last.month.isLegacy, isTrue);
    });

    test('no legacy bucket appears when every invoice is dated', () async {
      await HiveService.getInvoiceBox().add(
        InvoiceModel(
          title: 'عميل حالي',
          items: [InvoiceItemModel(itemName: 'إطار', price: 100.0)],
          createdAt: DateTime.now(),
        ),
      );

      final provider = InvoiceProvider();
      provider.loadInvoices(notify: false);

      expect(
        provider.invoiceMonths.any((month) => month.month.isLegacy),
        isFalse,
      );
    });

    test('dated invoices stay in the month they were created in', () async {
      final box = HiveService.getInvoiceBox();

      final now = DateTime.now();
      final backThen = DateTime(now.year - 1, 3, 12);

      await box.add(
        InvoiceModel(
          title: 'عميل مارس',
          items: [InvoiceItemModel(itemName: 'عدسة', price: 500.0)],
          createdAt: backThen,
        ),
      );

      final provider = InvoiceProvider();
      provider.loadInvoices(notify: false);

      expect(provider.currentMonthTotals.total, 0.0);

      expect(
        provider.totalsForMonth(InvoiceMonthKey.fromDate(backThen)).total,
        500.0,
      );
    });
  });
}
