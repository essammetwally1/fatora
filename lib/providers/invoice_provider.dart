import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceRepository _repository = InvoiceRepository();

  List<InvoiceModel> _invoices = [];

  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);

  InvoiceModel? invoiceByKey(dynamic key) {
    if (key == null) return null;

    for (final invoice in _invoices) {
      if (invoice.key == key) {
        return invoice;
      }
    }

    return null;
  }

  void loadInvoices() {
    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> createInvoice(String title) async {
    await _repository.createInvoice(title.trim());
    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> updateInvoiceTitle({
    required InvoiceModel invoice,
    required String title,
  }) async {
    await _repository.updateInvoiceTitle(
      invoiceKey: invoice.key,
      title: title.trim(),
    );

    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> deleteInvoice(InvoiceModel invoice) async {
    await _repository.deleteInvoice(invoiceKey: invoice.key);

    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    await _repository.addItem(invoiceKey: invoice.key, item: item);

    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> updateItem({
    required InvoiceModel invoice,
    required int index,
    required InvoiceItemModel item,
  }) async {
    await _repository.updateItem(
      invoiceKey: invoice.key,
      index: index,
      item: item,
    );

    _replaceInvoices(_repository.getInvoices());
  }

  Future<void> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    await _repository.deleteItem(invoiceKey: invoice.key, index: index);

    _replaceInvoices(_repository.getInvoices());
  }

  void _replaceInvoices(List<InvoiceModel> invoices) {
    _invoices = invoices;
    notifyListeners();
  }
}
