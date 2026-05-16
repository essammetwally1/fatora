import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceRepository _repository = InvoiceRepository();

  List<InvoiceModel> _invoices = [];

  List<InvoiceModel> get invoices => _invoices;

  void loadInvoices() {
    _invoices = _repository.getInvoices();

    notifyListeners();
  }

  Future<void> createInvoice(String title) async {
    await _repository.createInvoice(title);

    loadInvoices();
  }

  Future<void> deleteInvoice(int index) async {
    await _repository.deleteInvoice(index);

    loadInvoices();
  }

  Future<void> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    await _repository.addItem(invoice: invoice, item: item);

    loadInvoices();
  }

  Future<void> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    await _repository.deleteItem(invoice: invoice, index: index);

    loadInvoices();
  }
}
