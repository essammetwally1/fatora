import 'invoice_model.dart';

class InvoicesTotals {
  final double total;
  final double paid;
  final double remaining;
  final int invoiceCount;
  final int itemCount;

  const InvoicesTotals({
    required this.total,
    required this.paid,
    required this.remaining,
    required this.invoiceCount,
    required this.itemCount,
  });

  factory InvoicesTotals.empty() {
    return const InvoicesTotals(
      total: 0.0,
      paid: 0.0,
      remaining: 0.0,
      invoiceCount: 0,
      itemCount: 0,
    );
  }

  factory InvoicesTotals.fromInvoices(List<InvoiceModel> invoices) {
    if (invoices.isEmpty) return InvoicesTotals.empty();

    double total = 0.0;
    double paid = 0.0;
    int itemCount = 0;

    for (final invoice in invoices) {
      final items = invoice.items;
      itemCount += items.length;

      for (final item in items) {
        item.normalizePaymentState();

        total += item.price;
        paid += item.paidValue;
      }
    }

    final remaining = total - paid;

    return InvoicesTotals(
      total: total,
      paid: paid,
      remaining: remaining <= 0 ? 0.0 : remaining,
      invoiceCount: invoices.length,
      itemCount: itemCount,
    );
  }

  bool get hasRemaining => remaining > 0;

  bool get hasPaid => paid > 0;

  double get collectionProgress {
    if (total <= 0) return 0.0;

    final progress = paid / total;

    if (progress < 0) return 0.0;
    if (progress > 1) return 1.0;

    return progress;
  }
}
