import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceRepository _repository = InvoiceRepository();

  List<InvoiceModel> _invoices = const [];
  final Map<dynamic, InvoiceModel> _invoiceByKey = <dynamic, InvoiceModel>{};

  int _version = 0;

  bool _isLoading = false;
  bool _isMutating = false;

  List<InvoiceModel> get invoices => _invoices;

  int get version => _version;

  bool get isLoading => _isLoading;

  bool get isMutating => _isMutating;

  InvoiceModel? invoiceByKey(dynamic key) {
    if (key == null) return null;
    return _invoiceByKey[key];
  }

  void loadInvoices({bool notify = true}) {
    if (_isLoading) return;

    _isLoading = true;

    final invoices = _repository.getInvoices();

    _setInvoices(invoices);
    _isLoading = false;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> createInvoice(String title) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || _isMutating) return;

    _isMutating = true;
    notifyListeners();

    try {
      final createdInvoice = await _repository.createInvoice(cleanTitle);

      _invoices = List<InvoiceModel>.unmodifiable(<InvoiceModel>[
        createdInvoice,
        ..._invoices,
      ]);

      final createdKey = createdInvoice.key;
      if (createdKey != null) {
        _invoiceByKey[createdKey] = createdInvoice;
      }

      _bumpVersion();
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> updateInvoiceTitle({
    required InvoiceModel invoice,
    required String title,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || _isMutating) return;
    if (invoice.title == cleanTitle) return;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateInvoiceTitle(
        invoiceKey: invoiceKey,
        title: cleanTitle,
      );

      if (updatedInvoice == null) return;

      _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> deleteInvoice(InvoiceModel invoice) async {
    if (_isMutating) return;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return;

    _isMutating = true;
    notifyListeners();

    try {
      final deleted = await _repository.deleteInvoice(invoiceKey: invoiceKey);

      if (!deleted) return;

      _removeInvoiceFromMemory(invoiceKey);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    if (_isMutating) return;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.addItem(
        invoiceKey: invoiceKey,
        item: item,
      );

      if (updatedInvoice == null) return;

      _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> updateItem({
    required InvoiceModel invoice,
    required int index,
    required InvoiceItemModel item,
  }) async {
    if (_isMutating) return;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateItem(
        invoiceKey: invoiceKey,
        index: index,
        item: item,
      );

      if (updatedInvoice == null) return;

      _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    if (_isMutating) return;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.deleteItem(
        invoiceKey: invoiceKey,
        index: index,
      );

      if (updatedInvoice == null) return;

      _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> compactStorage() {
    return _repository.compactInvoicesBox();
  }

  void _setInvoices(List<InvoiceModel> invoices) {
    _invoices = List<InvoiceModel>.unmodifiable(invoices);

    _invoiceByKey
      ..clear()
      ..addEntries(
        _invoices
            .where((invoice) => invoice.key != null)
            .map((invoice) => MapEntry(invoice.key, invoice)),
      );

    _bumpVersion();
  }

  void _replaceInvoiceInMemory(InvoiceModel updatedInvoice) {
    final updatedKey = updatedInvoice.key;

    if (updatedKey == null) return;

    final index = _invoices.indexWhere((invoice) => invoice.key == updatedKey);

    if (index == -1) return;

    final nextInvoices = List<InvoiceModel>.of(_invoices, growable: true);
    nextInvoices[index] = updatedInvoice;

    _invoices = List<InvoiceModel>.unmodifiable(nextInvoices);
    _invoiceByKey[updatedKey] = updatedInvoice;

    _bumpVersion();
  }

  void _removeInvoiceFromMemory(dynamic invoiceKey) {
    _invoices = List<InvoiceModel>.unmodifiable(
      _invoices.where((invoice) => invoice.key != invoiceKey),
    );

    _invoiceByKey.remove(invoiceKey);

    _bumpVersion();
  }

  void _bumpVersion() {
    _version++;
  }
}
