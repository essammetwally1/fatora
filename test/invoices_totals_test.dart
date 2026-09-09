import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceModel invoiceWith({
  required List<double> prices,
  double paidAmount = 0.0,
}) {
  return InvoiceModel(
    title: 'test',
    items: [
      for (final price in prices)
        InvoiceItemModel(itemName: 'item', price: price),
    ],
    paidAmount: paidAmount,
  );
}

void main() {
  group('InvoiceModel', () {
    test('total sums item prices', () {
      expect(invoiceWith(prices: [10, 20, 5]).total, 35.0);
      expect(invoiceWith(prices: []).total, 0.0);
    });

    test('clamps paidAmount to the total', () {
      final invoice = invoiceWith(prices: [10], paidAmount: 999);
      expect(invoice.paidTotal, 10.0);
      expect(invoice.unpaidTotal, 0.0);
    });

    test('never reports negative remaining', () {
      final invoice = invoiceWith(prices: [10], paidAmount: 10);
      expect(invoice.unpaidTotal, 0.0);
    });

    test('is complete only when it has items and no remainder', () {
      expect(
        invoiceWith(prices: [10], paidAmount: 10).isPaymentCompleted,
        isTrue,
      );
      expect(
        invoiceWith(prices: [10], paidAmount: 4).isPaymentCompleted,
        isFalse,
      );

      // An empty invoice is not "complete", so its items stay editable.
      expect(invoiceWith(prices: []).isPaymentCompleted, isFalse);
      expect(invoiceWith(prices: []).canEditItems, isTrue);
    });

    test('locks item editing once fully paid', () {
      expect(invoiceWith(prices: [10], paidAmount: 10).canEditItems, isFalse);
    });

    test('falls back to a placeholder title when blank', () {
      expect(
        InvoiceModel(title: '   ', items: []).displayTitle,
        'فاتورة بدون عنوان',
      );
    });

    test('ignores negative and non-finite prices', () {
      expect(invoiceWith(prices: [-5, 10]).total, 10.0);
      expect(invoiceWith(prices: [double.nan, 10]).total, 10.0);
    });
  });

  group('InvoicesTotals', () {
    test('empty totals are all zero', () {
      final totals = InvoicesTotals.empty();

      expect(totals.total, 0.0);
      expect(totals.paid, 0.0);
      expect(totals.remaining, 0.0);
      expect(totals.invoiceCount, 0);
      expect(totals.itemCount, 0);
      expect(totals.collectionProgress, 0.0);
    });

    test('aggregates across invoices', () {
      final totals = InvoicesTotals.fromInvoices([
        invoiceWith(prices: [10, 10], paidAmount: 5),
        invoiceWith(prices: [30], paidAmount: 30),
      ]);

      expect(totals.total, 50.0);
      expect(totals.paid, 35.0);
      expect(totals.remaining, 15.0);
      expect(totals.invoiceCount, 2);
      expect(totals.itemCount, 3);
    });

    test('collectionProgress stays within 0..1', () {
      expect(
        InvoicesTotals.fromInvoices([
          invoiceWith(prices: [10], paidAmount: 5),
        ]).collectionProgress,
        0.5,
      );

      // Zero total must not divide by zero.
      expect(
        InvoicesTotals.fromInvoices([
          invoiceWith(prices: []),
        ]).collectionProgress,
        0.0,
      );
    });

    test('hasRemaining reflects the outstanding balance', () {
      expect(
        InvoicesTotals.fromInvoices([
          invoiceWith(prices: [10], paidAmount: 10),
        ]).hasRemaining,
        isFalse,
      );

      expect(
        InvoicesTotals.fromInvoices([
          invoiceWith(prices: [10]),
        ]).hasRemaining,
        isTrue,
      );
    });
  });
}
