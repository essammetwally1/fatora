import 'package:flutter/material.dart';

import '../data/models/invoice_model.dart';
import 'invoice_details_screen.dart';

/// Opens an invoice for viewing and editing.
///
/// Every entry point goes through here — the month list and the starred
/// section of the drawer — so an invoice reached from one place behaves
/// exactly like the same invoice reached from the other.
Future<void> openInvoiceDetails(BuildContext context, InvoiceModel invoice) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => InvoiceDetailsScreen(invoice: invoice),
    ),
  );
}
