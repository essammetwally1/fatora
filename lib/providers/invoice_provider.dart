import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceRepository _repository = InvoiceRepository();

  List<InvoiceModel> _invoices = [];

  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);

  InvoiceModel? invoiceByKey(dynamic key) {
    try {
      return _invoices.firstWhere((invoice) => invoice.key == key);
    } catch (_) {
      return null;
    }
  }

  void loadInvoices() {
    _invoices = _repository.getInvoices();
    notifyListeners();
  }

  Future<void> createInvoice(String title) async {
    await _repository.createInvoice(title.trim());
    loadInvoices();
  }

  Future<void> updateInvoiceTitle({
    required InvoiceModel invoice,
    required String title,
  }) async {
    await _repository.updateInvoiceTitle(
      invoiceKey: invoice.key,
      title: title.trim(),
    );
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
    await _repository.addItem(invoiceKey: invoice.key, item: item);
    loadInvoices();
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
    loadInvoices();
  }

  Future<void> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    await _repository.deleteItem(invoiceKey: invoice.key, index: index);
    loadInvoices();
  }
}
