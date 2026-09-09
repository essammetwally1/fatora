import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/models/invoice_payment_line.dart';
import 'package:fatora/data/repositories/invoice_repository.dart';
import 'package:fatora/data/services/pdf/invoice_pdf_generator.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/hive_test_env.dart';

/// Sum of every printed line, which must always equal the stored paid total.
double _linesTotal(List<InvoicePaymentLine> lines) {
  var value = 0.0;

  for (final line in lines) {
    value += line.signedAmount;
  }

  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = HiveTestEnv();

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() => env.setUp());
  tearDown(() => env.tearDown());

  group('recording a payment', () {
    test('stores the amount, the direction and the moment', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      final before = DateTime.now();

      final updated = await InvoiceRepository().applyPaidDelta(
        invoiceKey: key,
        deltaAmount: 120,
      );

      expect(updated, isNotNull);
      expect(updated!.paidTotal, 120.0);
      expect(updated.payments, hasLength(1));

      final entry = updated.payments.single;

      expect(entry.amount, 120.0);
      expect(entry.isReturn, isFalse);
      expect(entry.id.trim(), isNotEmpty);
      expect(
        entry.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('records a return as a return, not as a negative payment', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);
      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 200);

      final updated = await repository.applyPaidDelta(
        invoiceKey: key,
        deltaAmount: -50,
      );

      expect(updated!.paidTotal, 150.0);
      expect(updated.payments, hasLength(2));

      final returnEntry = updated.payments.last;

      // Stored as a positive magnitude plus a direction, so it can never be
      // misread as a credit by a caller that forgets to check the sign.
      expect(returnEntry.amount, 50.0);
      expect(returnEntry.isReturn, isTrue);
      expect(returnEntry.signedAmount, -50.0);

      expect(updated.recordedPaymentsTotal, 200.0);
      expect(updated.recordedReturnsTotal, 50.0);
      expect(updated.recordedPaymentsNet, 150.0);
    });

    test('records what was actually applied, not what was asked for', () async {
      // Overpaying is clamped to the remaining balance. If the entry stored
      // the requested 500, the printed breakdown would claim more money
      // changed hands than the invoice total.
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      final updated = await InvoiceRepository().applyPaidDelta(
        invoiceKey: key,
        deltaAmount: 500,
      );

      expect(updated!.paidTotal, 300.0);
      expect(updated.payments.single.amount, 300.0);
      expect(updated.unrecordedPaidAmount, 0.0);
    });

    test('does not record a movement that changes nothing', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);
      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 300);

      final updated = await repository.applyPaidDelta(
        invoiceKey: key,
        deltaAmount: 40,
      );

      expect(updated!.paidTotal, 300.0);
      expect(updated.payments, hasLength(1));
    });

    test('survives a restart', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);
      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 120);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: -20);

      await Hive.box<InvoiceModel>(HiveService.invoiceBox).close();
      await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

      final reloaded = InvoiceRepository().getInvoices().single;

      expect(reloaded.paidTotal, 100.0);
      expect(reloaded.payments, hasLength(2));
      expect(reloaded.payments.first.isReturn, isFalse);
      expect(reloaded.payments.last.isReturn, isTrue);
    });
  });

  group('an invoice paid before payment history existed', () {
    test('reports its balance as unrecorded rather than as zero', () async {
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

      expect(migrated.payments, isEmpty);
      expect(migrated.paidTotal, 250.0);
      expect(migrated.unrecordedPaidAmount, 250.0);
    });

    test('prints one dateless line rather than inventing a date', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [(name: 'عدسة', price: 250.0, paid: 250.0)],
      );

      await HiveService.getInvoiceBox().add(invoice);
      await InvoiceRepository().migrateStoredInvoices();

      final lines = InvoicePaymentLine.fromInvoice(
        InvoiceRepository().getInvoices().single,
      );

      expect(lines, hasLength(1));
      expect(lines.single.isOpening, isTrue);
      expect(lines.single.occurredAt, isNull);
      expect(lines.single.amount, 250.0);
      expect(lines.single.labelAr, 'دفعة مسجلة مسبقًا');
    });

    test('keeps the carried balance when a new payment is added', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [
          (name: 'عدسة', price: 250.0, paid: 250.0),
          (name: 'إطار', price: 150.0, paid: 0.0),
        ],
      );

      final key = await HiveService.getInvoiceBox().add(invoice);

      final updated = await InvoiceRepository().applyPaidDelta(
        invoiceKey: key,
        deltaAmount: 150,
      );

      expect(updated!.paidTotal, 400.0);

      final lines = InvoicePaymentLine.fromInvoice(updated);

      // The old 250 and the new 150, and only the new one carries a time.
      expect(lines, hasLength(2));
      expect(lines.first.isOpening, isTrue);
      expect(lines.first.amount, 250.0);
      expect(lines.last.isOpening, isFalse);
      expect(lines.last.occurredAt, isNotNull);
      expect(lines.last.amount, 150.0);

      expect(_linesTotal(lines), closeTo(updated.paidTotal, 0.0001));
    });
  });

  group('the printed breakdown', () {
    test('is empty on an invoice nobody has paid', () {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      expect(InvoicePaymentLine.fromInvoice(invoice), isEmpty);
    });

    test('always adds up to the stored paid total', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
      );

      final key = await HiveService.getInvoiceBox().add(invoice);
      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 100);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 120);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: -70);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 50);

      final updated = repository.getInvoices().single;
      final lines = InvoicePaymentLine.fromInvoice(updated);

      expect(lines, hasLength(4));
      expect(_linesTotal(lines), closeTo(updated.paidTotal, 0.0001));
      expect(updated.paidTotal, closeTo(200.0, 0.0001));
    });

    test('runs oldest first', () {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 300)],
        createdAt: DateTime(2026, 9, 10),
        payments: [
          InvoicePaymentEntryModel(
            amount: 50,
            createdAt: DateTime(2026, 9, 9, 18),
          ),
          InvoicePaymentEntryModel(
            amount: 30,
            createdAt: DateTime(2026, 9, 8, 11),
          ),
        ],
      );

      invoice.paidAmount = 80;

      final lines = InvoicePaymentLine.fromInvoice(invoice);

      expect(lines.first.occurredAt, DateTime(2026, 9, 8, 11));
      expect(lines.last.occurredAt, DateTime(2026, 9, 9, 18));
      expect(invoice.unrecordedPaidAmount, 0.0);
    });

    test('drops floating-point dust instead of showing it as a balance', () {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 1)],
        createdAt: DateTime(2026, 9, 10),
        payments: [
          InvoicePaymentEntryModel(amount: 0.1),
          InvoicePaymentEntryModel(amount: 0.2),
        ],
      );

      invoice.paidAmount = 0.3;

      // 0.1 + 0.2 != 0.3 in binary floating point; without a tolerance this
      // showed a phantom line worth 5.5e-17.
      expect(invoice.unrecordedPaidAmount, 0.0);
      expect(InvoicePaymentLine.fromInvoice(invoice), hasLength(2));
    });
  });

  group('the 12-hour timestamp', () {
    test('uses a 12-hour clock with an Arabic marker', () {
      expect(
        Formatters.formatPaymentTime(DateTime(2026, 9, 10, 15, 45)),
        '03:45 م',
      );
      expect(
        Formatters.formatPaymentTime(DateTime(2026, 9, 10, 9, 5)),
        '09:05 ص',
      );
      expect(
        Formatters.formatPaymentTime(DateTime(2026, 9, 10, 0, 30)),
        '12:30 ص',
      );
      expect(
        Formatters.formatPaymentTime(DateTime(2026, 9, 10, 12, 30)),
        '12:30 م',
      );
    });

    test('pairs the date with the time', () {
      final label = Formatters.formatPaymentDateTime(
        DateTime(2026, 9, 10, 15, 45),
      );

      expect(label, '10/09/2026 - 03:45 م');
    });
  });

  group('the exported document', () {
    test('renders an invoice carrying payments and returns', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [
          InvoiceItemModel(itemName: 'عدسة', price: 300),
          InvoiceItemModel(itemName: 'إطار', price: 200),
        ],
        createdAt: DateTime(2026, 9, 10),
        payments: [
          InvoicePaymentEntryModel(
            amount: 200,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
          InvoicePaymentEntryModel(
            amount: 50,
            isReturn: true,
            createdAt: DateTime(2026, 9, 11, 17, 40),
          ),
          InvoicePaymentEntryModel(
            amount: 100,
            createdAt: DateTime(2026, 9, 12, 12, 5),
          ),
        ],
      );

      invoice.paidAmount = 250;

      final bytes = await InvoicePdfGenerator.build(invoice);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders a legacy invoice whose payment has no date', () async {
      final invoice = buildLegacyInvoice(
        title: 'عميل قديم',
        items: [(name: 'عدسة', price: 250.0, paid: 250.0)],
      );

      final bytes = await InvoicePdfGenerator.build(invoice);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders a history long enough to break across pages', () async {
      final invoice = InvoiceModel(
        title: 'عميل',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 5000)],
        createdAt: DateTime(2026, 9, 10),
        payments: List.generate(
          80,
          (index) => InvoicePaymentEntryModel(
            amount: 25,
            isReturn: index.isOdd,
            createdAt: DateTime(2026, 9, 10, 8).add(Duration(hours: index)),
          ),
        ),
      );

      invoice.paidAmount = invoice.recordedPaymentsNet;

      final bytes = await InvoicePdfGenerator.build(invoice);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
