import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/services/pdf/invoice_pdf_generator.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

InvoiceModel invoiceWith({
  required String title,
  required List<InvoiceItemModel> items,
  DateTime? createdAt,
  double paidAmount = 0.0,
  List<InvoicePaymentEntryModel>? payments,
}) {
  return InvoiceModel(
    title: title,
    items: items,
    createdAt: createdAt,
    paidAmount: paidAmount,
    payments: payments,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('the printed date', () {
    test('is the invoice\'s own date, not today', () {
      final january = DateTime(2026, 1, 14, 15, 20);

      final label = Formatters.formatInvoiceDocumentDate(january);

      expect(label, Formatters.formatDate(january));
      expect(label, isNot(Formatters.formatDate(DateTime.now())));
    });

    test('states plainly that a legacy invoice has no recorded date', () {
      expect(Formatters.formatInvoiceDocumentDate(null), 'فاتورة قديمة');
    });

    test('never falls back to the year-2000 sorting sentinel', () {
      final label = Formatters.formatInvoiceDocumentDate(null);

      expect(label, isNot(Formatters.formatDate(InvoiceModel.legacyCreatedAt)));
      expect(label, isNot(contains('2000')));
    });
  });

  group('the saved filename', () {
    test(
      'carries the invoice date, so files sort by when business happened',
      () {
        final name = PdfService.fileNameForInvoice(
          invoiceWith(
            title: 'عميل يناير',
            items: [InvoiceItemModel(itemName: 'عدسة', price: 100)],
            createdAt: DateTime(2026, 1, 14),
          ),
        );

        expect(name, contains('2026-01-14'));
        expect(name, endsWith('.pdf'));
      },
    );

    test('marks a legacy invoice rather than borrowing today', () {
      final name = PdfService.fileNameForInvoice(
        invoiceWith(
          title: 'عميل قديم',
          items: [InvoiceItemModel(itemName: 'عدسة', price: 100)],
        ),
      );

      expect(name, contains('legacy'));
    });

    test('strips characters that are illegal in a filename', () {
      final name = PdfService.fileNameForInvoice(
        invoiceWith(
          title: 'a/b:c*d?e"f<g>h|i',
          items: const [],
          createdAt: DateTime(2026, 1, 14),
        ),
      );

      expect(name, isNot(matches(RegExp(r'[\\/:*?"<>|]'))));
    });

    test('falls back to a placeholder for a blank title', () {
      final name = PdfService.fileNameForInvoice(
        invoiceWith(
          title: '   ',
          items: const [],
          createdAt: DateTime(2026, 1, 14),
        ),
      );

      expect(name, startsWith('invoice-'));
    });

    test('two exports of the same invoice cannot collide', () async {
      final invoice = invoiceWith(
        title: 'عميل',
        items: const [],
        createdAt: DateTime(2026, 1, 14),
      );

      final first = PdfService.fileNameForInvoice(invoice);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = PdfService.fileNameForInvoice(invoice);

      expect(first, isNot(second));
    });
  });

  group('document generation', () {
    test('renders a legacy invoice', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'عميل قديم',
          items: [
            InvoiceItemModel(itemName: 'عدسة', price: 250),
            InvoiceItemModel(itemName: 'إطار', price: 150),
          ],
        ),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders an invoice with no items', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'فاتورة فارغة',
          items: const [],
          createdAt: DateTime(2026, 1, 14),
        ),
      );

      expect(bytes, isNotEmpty);
    });

    test('renders a single-item invoice', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'عميل',
          items: [InvoiceItemModel(itemName: 'عدسة', price: 250)],
          createdAt: DateTime(2026, 1, 14),
        ),
      );

      expect(bytes, isNotEmpty);
    });

    test('renders a long invoice across pages', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'عميل بفاتورة طويلة',
          items: List.generate(
            120,
            (index) => InvoiceItemModel(
              itemName: 'صنف رقم ${index + 1}',
              price: 12.5 + index,
            ),
          ),
          createdAt: DateTime(2026, 1, 14),
        ),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    // A breakdown past the block-printing threshold takes the other path
    // through `_buildPaymentBreakdown`: its head and its total are pinned to
    // neighbouring rows and only the middle is left free to break, which is
    // index arithmetic worth exercising on both sides of the boundary.
    for (final entryCount in [6, 12, 13, 60]) {
      test('renders a breakdown of $entryCount entries', () async {
        final bytes = await InvoicePdfGenerator.build(
          invoiceWith(
            title: 'عميل بدفعات كثيرة',
            items: [InvoiceItemModel(itemName: 'عدسة', price: 100000)],
            createdAt: DateTime(2026, 1, 14),
            paidAmount: 100 * entryCount.toDouble(),
            payments: List.generate(
              entryCount,
              (index) => InvoicePaymentEntryModel(
                amount: 100,
                // A mix of both kinds, so both group headers are printed.
                isReturn: index.isOdd,
                createdAt: DateTime(2026, 1, 14, 9).add(Duration(hours: index)),
              ),
            ),
          ),
        );

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      });
    }

    test('renders very long item names and large amounts', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'عميل ' * 20,
          items: [
            InvoiceItemModel(
              itemName: 'عدسة طبية مضادة للانعكاس ' * 12,
              price: 1234567.89,
            ),
            InvoiceItemModel(
              itemName: 'Latin name mixed with عربي',
              price: 0.5,
            ),
          ],
          createdAt: DateTime(2026, 1, 14),
          paidAmount: 1000,
        ),
      );

      expect(bytes, isNotEmpty);
    });

    test('renders a part-paid invoice', () async {
      final bytes = await InvoicePdfGenerator.build(
        invoiceWith(
          title: 'عميل',
          items: [InvoiceItemModel(itemName: 'عدسة', price: 250)],
          createdAt: DateTime(2026, 1, 14),
          paidAmount: 100,
        ),
      );

      expect(bytes, isNotEmpty);
    });
  });
}
