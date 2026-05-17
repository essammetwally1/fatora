import '../../data/models/invoice_model.dart';

class InvoicesTotals {
  final int invoiceCount;
  final int itemCount;
  final double total;

  const InvoicesTotals({
    required this.invoiceCount,
    required this.itemCount,
    required this.total,
  });

  factory InvoicesTotals.fromInvoices(List<InvoiceModel> invoices) {
    var itemCount = 0;
    var total = 0.0;

    for (final invoice in invoices) {
      for (final item in invoice.items) {
        itemCount++;
        total += item.price;
      }
    }

    return InvoicesTotals(
      invoiceCount: invoices.length,
      itemCount: itemCount,
      total: total,
    );
  }
}
