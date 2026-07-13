import 'invoice_model.dart';
import 'invoice_month_key.dart';
import 'invoices_totals.dart';

class InvoiceMonthSnapshot {
  final InvoiceMonthKey month;
  final List<InvoiceModel> invoices;
  final InvoicesTotals totals;
  final bool isCurrentMonth;

  const InvoiceMonthSnapshot({
    required this.month,
    required this.invoices,
    required this.totals,
    required this.isCurrentMonth,
  });

  int get invoiceCount => invoices.length;
}
