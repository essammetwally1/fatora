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
    if (notify) notifyListeners();

    final invoices = _repository.getInvoices();

    _invoices = List<InvoiceModel>.unmodifiable(invoices);

    _invoiceByKey
      ..clear()
      ..addEntries(
        _invoices
            .where((invoice) => invoice.key != null)
            .map((invoice) => MapEntry(invoice.key, invoice)),
      );

    _bumpVersion();

    _isLoading = false;
    if (notify) notifyListeners();
  }

  Future<void> migrateLegacyPayments() async {
    if (_isMutating) return;

    _isMutating = true;
    notifyListeners();

    try {
      await _repository.migrateLegacyPaymentsToInvoicePayments();
      loadInvoices(notify: false);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> createInvoice(String title) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || _isMutating) return false;

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
      return true;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> updateInvoiceTitle({
    required InvoiceModel invoice,
    required String title,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || _isMutating) return false;
    if (invoice.title == cleanTitle) return true;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateInvoiceTitle(
        invoiceKey: invoiceKey,
        title: cleanTitle,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> updateInvoicePaidAmount({
    required InvoiceModel invoice,
    required double paidAmount,
  }) async {
    if (_isMutating) return false;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    final cleanPaidAmount = _clampPaidAmount(
      paidAmount: paidAmount,
      total: invoice.total,
    );

    if (invoice.paidTotal == cleanPaidAmount) return true;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateInvoicePaidAmount(
        invoiceKey: invoiceKey,
        paidAmount: cleanPaidAmount,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> applyInvoicePaidDelta({
    required InvoiceModel invoice,
    required double deltaAmount,
  }) async {
    if (_isMutating) return false;
    if (deltaAmount.isNaN || deltaAmount.isInfinite || deltaAmount == 0) {
      return false;
    }

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    final nextPaidAmount = _clampPaidAmount(
      paidAmount: currentInvoice.paidTotal + deltaAmount,
      total: currentInvoice.total,
    );

    if (currentInvoice.paidTotal == nextPaidAmount) return true;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateInvoicePaidAmount(
        invoiceKey: invoiceKey,
        paidAmount: nextPaidAmount,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteInvoice(InvoiceModel invoice) async {
    if (_isMutating) return false;

    final invoiceKey = invoice.key;

    _isMutating = true;
    notifyListeners();

    try {
      final deleted = await _repository.deleteInvoice(
        invoice: invoice,
        invoiceKey: invoiceKey,
      );

      if (!deleted) return false;

      if (invoiceKey != null) {
        _removeInvoiceFromMemory(invoiceKey);
      } else {
        loadInvoices(notify: false);
      }

      return true;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    if (_isMutating || !invoice.canEditItems) return false;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.addItem(
        invoiceKey: invoiceKey,
        item: item,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> updateItem({
    required InvoiceModel invoice,
    required int index,
    required InvoiceItemModel item,
  }) async {
    if (_isMutating || !invoice.canEditItems) return false;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.updateItem(
        invoiceKey: invoiceKey,
        index: index,
        item: item,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    if (_isMutating || !invoice.canEditItems) return false;

    final invoiceKey = invoice.key;
    if (invoiceKey == null) return false;

    _isMutating = true;
    notifyListeners();

    try {
      final updatedInvoice = await _repository.deleteItem(
        invoiceKey: invoiceKey,
        index: index,
      );

      if (updatedInvoice == null) return false;

      return _replaceInvoiceInMemory(updatedInvoice);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> compactStorage() {
    return _repository.compactInvoicesBox();
  }

  bool _replaceInvoiceInMemory(InvoiceModel updatedInvoice) {
    final updatedKey = updatedInvoice.key;

    if (updatedKey == null) return false;

    final index = _invoices.indexWhere((invoice) => invoice.key == updatedKey);
    if (index == -1) return false;

    final nextInvoices = List<InvoiceModel>.of(_invoices, growable: true);
    nextInvoices[index] = updatedInvoice;

    _invoices = List<InvoiceModel>.unmodifiable(nextInvoices);
    _invoiceByKey[updatedKey] = updatedInvoice;

    _bumpVersion();
    return true;
  }

  void _removeInvoiceFromMemory(dynamic invoiceKey) {
    final beforeLength = _invoices.length;

    _invoices = List<InvoiceModel>.unmodifiable(
      _invoices.where((invoice) => invoice.key != invoiceKey),
    );

    _invoiceByKey.remove(invoiceKey);

    if (_invoices.length != beforeLength) {
      _bumpVersion();
    } else {
      loadInvoices(notify: false);
    }
  }

  static double _clampPaidAmount({
    required double paidAmount,
    required double total,
  }) {
    if (paidAmount.isNaN || paidAmount.isInfinite || paidAmount < 0) {
      return 0.0;
    }

    if (paidAmount > total) {
      return total;
    }

    return paidAmount;
  }

  void _bumpVersion() {
    _version++;
  }
}
