import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/models/invoice_payment_line.dart';
import 'package:fatora/data/repositories/invoice_repository.dart';
import 'package:fatora/data/services/pdf/invoice_pdf_generator.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/hive_test_env.dart';

InvoiceModel _invoice({
  String title = 'عميل',
  double price = 500,
  DateTime? createdAt,
  List<InvoicePaymentEntryModel> payments = const [],
}) {
  return InvoiceModel(
    title: title,
    items: [InvoiceItemModel(itemName: 'عدسة', price: price)],
    createdAt: createdAt ?? DateTime(2026, 9, 10),
    payments: payments,
  );
}

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

  group('the new invoice flags', () {
    test('start off, so nothing already stored changes behaviour', () {
      final invoice = _invoice();

      expect(invoice.hidePaymentDetailsInExport, isFalse);
      expect(invoice.printsPaymentDetails, isTrue);
      expect(invoice.isStarred, isFalse);
    });
  });

  group('hiding the printed breakdown', () {
    test('persists, and is reported the way the UI reads it', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      final repository = InvoiceRepository();

      final hidden = await repository.setPaymentDetailsHiddenInExport(
        invoiceKey: key,
        hidden: true,
      );

      expect(hidden?.hidePaymentDetailsInExport, isTrue);
      expect(hidden?.printsPaymentDetails, isFalse);

      // Read back through storage rather than trusting the returned object.
      expect(
        repository.getInvoices().single.hidePaymentDetailsInExport,
        isTrue,
      );

      final shown = await repository.setPaymentDetailsHiddenInExport(
        invoiceKey: key,
        hidden: false,
      );

      expect(shown?.printsPaymentDetails, isTrue);
    });

    test('takes the breakdown out of the exported PDF', () async {
      final payments = List.generate(
        20,
        (index) => InvoicePaymentEntryModel(
          amount: 10,
          createdAt: DateTime(2026, 9, 10, 8).add(Duration(hours: index)),
        ),
      );

      final invoice = _invoice(payments: payments);

      invoice.paidAmount = 200;

      final withDetails = await InvoicePdfGenerator.build(invoice);

      invoice.hidePaymentDetailsInExport = true;

      final withoutDetails = await InvoicePdfGenerator.build(invoice);

      expect(String.fromCharCodes(withoutDetails.take(5)), '%PDF-');

      // Twenty dated rows carry real weight; a document that dropped them
      // cannot be the same size as one that printed them.
      expect(withoutDetails.length, lessThan(withDetails.length));
    });

    test('leaves the invoice itself untouched', () async {
      final invoice = _invoice(
        payments: [
          InvoicePaymentEntryModel(
            amount: 120,
            createdAt: DateTime(2026, 9, 10, 9),
          ),
        ],
      );

      invoice.paidAmount = 120;
      invoice.hidePaymentDetailsInExport = true;

      // Only the printing changes: the entries are still stored, and the
      // totals the receipt prints above the breakdown still add up.
      expect(invoice.payments, hasLength(1));
      expect(invoice.paidTotal, 120);
      expect(InvoicePaymentLine.fromInvoice(invoice), hasLength(1));
    });
  });

  group('deleting one recorded movement', () {
    test('removes the entry and takes its money with it', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 200);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 150);

      final before = repository.getInvoices().single;

      expect(before.paidTotal, closeTo(350, 0.0001));

      final target = before.payments.firstWhere((entry) => entry.amount == 200);

      final updated = await repository.deletePaymentEntry(
        invoiceKey: key,
        entryId: target.id,
      );

      expect(updated, isNotNull);
      expect(updated!.payments, hasLength(1));
      expect(updated.paidTotal, closeTo(150, 0.0001));

      // The whole point: the deleted payment does not come back as an undated
      // "paid earlier" line on the receipt.
      final lines = InvoicePaymentLine.fromInvoice(updated);

      expect(lines, hasLength(1));
      expect(lines.single.isOpening, isFalse);
      expect(_linesTotal(lines), closeTo(updated.paidTotal, 0.0001));
      expect(updated.unrecordedPaidAmount, 0.0);
    });

    test('deleting a return puts the refunded money back', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 300);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: -100);

      final refund = repository.getInvoices().single.payments.firstWhere(
        (entry) => entry.isReturn,
      );

      final updated = await repository.deletePaymentEntry(
        invoiceKey: key,
        entryId: refund.id,
      );

      expect(updated!.paidTotal, closeTo(300, 0.0001));
      expect(updated.payments.single.isReturn, isFalse);
      expect(updated.unrecordedPaidAmount, 0.0);
    });

    test('never lets the paid total climb above the invoice total', () async {
      // A return recorded against an invoice that has since shrunk: undoing it
      // must stop at the total rather than claim more was paid than is owed.
      final key = await HiveService.getInvoiceBox().add(_invoice(price: 100));

      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 100);
      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: -60);

      final refund = repository.getInvoices().single.payments.firstWhere(
        (entry) => entry.isReturn,
      );

      final updated = await repository.deletePaymentEntry(
        invoiceKey: key,
        entryId: refund.id,
      );

      expect(updated!.paidTotal, closeTo(100, 0.0001));
      expect(updated.paidTotal, lessThanOrEqualTo(updated.total));
    });

    test('refuses an entry that is already gone', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      final repository = InvoiceRepository();

      await repository.applyPaidDelta(invoiceKey: key, deltaAmount: 200);

      expect(
        await repository.deletePaymentEntry(
          invoiceKey: key,
          entryId: 'not-an-entry',
        ),
        isNull,
      );

      expect(
        await repository.deletePaymentEntry(invoiceKey: key, entryId: '  '),
        isNull,
      );

      // Nothing was touched by the refusals.
      expect(repository.getInvoices().single.paidTotal, closeTo(200, 0.0001));
    });

    test(
      'the provider reports a vanished entry instead of failing silently',
      () async {
        final key = await HiveService.getInvoiceBox().add(_invoice());

        final provider = InvoiceProvider();

        provider.loadInvoices(notify: false);

        final invoice = provider.invoiceByKey(key)!;

        final deleted = await provider.deletePaymentEntry(
          invoice: invoice,
          entryId: 'not-an-entry',
        );

        expect(deleted, isFalse);
        expect(provider.lastErrorMessage, 'لم تعد هذه العملية موجودة');
      },
    );
  });

  group('starred invoices', () {
    test('are collected across months, newest first', () async {
      final box = HiveService.getInvoiceBox();

      final januaryKey = await box.add(
        _invoice(title: 'يناير', createdAt: DateTime(2026, 1, 5)),
      );
      await box.add(_invoice(title: 'فبراير', createdAt: DateTime(2026, 2, 5)));
      final marchKey = await box.add(
        _invoice(title: 'مارس', createdAt: DateTime(2026, 3, 5)),
      );

      final provider = InvoiceProvider();

      provider.loadInvoices(notify: false);

      expect(provider.starredInvoices, isEmpty);

      expect(
        await provider.setInvoiceStarred(
          invoice: provider.invoiceByKey(januaryKey)!,
          starred: true,
        ),
        isTrue,
      );

      expect(
        await provider.setInvoiceStarred(
          invoice: provider.invoiceByKey(marchKey)!,
          starred: true,
        ),
        isTrue,
      );

      // Two different months, one list, newest first — which is what makes
      // the drawer section worth having.
      expect(provider.starredInvoices.map((invoice) => invoice.title), [
        'مارس',
        'يناير',
      ]);
    });

    test('unstarring drops the invoice from the section', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      final provider = InvoiceProvider();

      provider.loadInvoices(notify: false);

      await provider.setInvoiceStarred(
        invoice: provider.invoiceByKey(key)!,
        starred: true,
      );

      expect(provider.starredInvoices, hasLength(1));

      await provider.setInvoiceStarred(
        invoice: provider.invoiceByKey(key)!,
        starred: false,
      );

      expect(provider.starredInvoices, isEmpty);
      expect(InvoiceRepository().getInvoices().single.isStarred, isFalse);
    });

    test('starring survives a reload from storage', () async {
      final key = await HiveService.getInvoiceBox().add(_invoice());

      await InvoiceRepository().setStarred(invoiceKey: key, starred: true);

      final provider = InvoiceProvider();

      provider.loadInvoices(notify: false);

      expect(provider.starredInvoices.single.key, key);
    });
  });
}
