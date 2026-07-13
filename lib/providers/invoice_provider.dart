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

  Object? _lastError;
  StackTrace? _lastStackTrace;
  String? _lastErrorMessage;

  Object? get lastError => _lastError;
  StackTrace? get lastStackTrace => _lastStackTrace;
  String? get lastErrorMessage => _lastErrorMessage;

  List<InvoiceModel> get invoices => _invoices;

  int get version => _version;

  bool get isLoading => _isLoading;

  bool get isMutating => _isMutating;

  InvoiceModel? invoiceByKey(dynamic key) {
    if (key == null) return null;
    return _invoiceByKey[key];
  }

  bool loadInvoices({bool notify = true}) {
    if (_isLoading) return false;

    _isLoading = true;
    clearError(notify: false);

    if (notify) {
      notifyListeners();
    }

    try {
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

      return true;
    } catch (error, stackTrace) {
      _recordError(error, stackTrace, message: 'تعذر تحميل الفواتير');

      return false;
    } finally {
      _isLoading = false;

      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> migrateLegacyPayments() async {
    await _runMutation(
      failureMessage: 'تعذر تحديث بيانات الدفع القديمة',
      operation: () async {
        await _repository.migrateLegacyPaymentsToInvoicePayments();

        return loadInvoices(notify: false);
      },
    );
  }

  Future<bool> createInvoice(String title) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      _setOperationError('اسم الفاتورة مطلوب');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر إنشاء الفاتورة',
      operation: () async {
        final createdInvoice = await _repository.createInvoice(cleanTitle);

        _invoices = List<InvoiceModel>.unmodifiable([
          createdInvoice,
          ..._invoices,
        ]);

        final createdKey = createdInvoice.key;

        if (createdKey != null) {
          _invoiceByKey[createdKey] = createdInvoice;
        }

        _bumpVersion();

        return true;
      },
    );
  }

  Future<bool> updateInvoiceTitle({
    required InvoiceModel invoice,
    required String title,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      _setOperationError('اسم الفاتورة مطلوب');
      return false;
    }

    if (invoice.title == cleanTitle) {
      return true;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر تعديل اسم الفاتورة',
      operation: () async {
        final updatedInvoice = await _repository.updateInvoiceTitle(
          invoiceKey: invoiceKey,
          title: cleanTitle,
        );

        if (updatedInvoice == null) {
          _setOperationError('لم تعد الفاتورة موجودة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<bool> updateInvoicePaidAmount({
    required InvoiceModel invoice,
    required double paidAmount,
  }) async {
    if (!paidAmount.isFinite) {
      _setOperationError('قيمة المبلغ غير صحيحة');
      return false;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    final cleanPaidAmount = _clampPaidAmount(
      paidAmount: paidAmount,
      total: currentInvoice.total,
    );

    if (currentInvoice.paidTotal == cleanPaidAmount) {
      return true;
    }

    return _runMutation(
      failureMessage: 'تعذر تحديث المبلغ المدفوع',
      operation: () async {
        final updatedInvoice = await _repository.updateInvoicePaidAmount(
          invoiceKey: invoiceKey,
          paidAmount: cleanPaidAmount,
        );

        if (updatedInvoice == null) {
          _setOperationError('لم تعد الفاتورة موجودة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<bool> applyInvoicePaidDelta({
    required InvoiceModel invoice,
    required double deltaAmount,
  }) async {
    if (!deltaAmount.isFinite || deltaAmount == 0) {
      _setOperationError('قيمة العملية غير صحيحة');
      return false;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    final nextPaidAmount = _clampPaidAmount(
      paidAmount: currentInvoice.paidTotal + deltaAmount,
      total: currentInvoice.total,
    );

    if (currentInvoice.paidTotal == nextPaidAmount) {
      return true;
    }

    return _runMutation(
      failureMessage: 'تعذر حفظ عملية الدفع',
      operation: () async {
        final updatedInvoice = await _repository.updateInvoicePaidAmount(
          invoiceKey: invoiceKey,
          paidAmount: nextPaidAmount,
        );

        if (updatedInvoice == null) {
          _setOperationError('لم تعد الفاتورة موجودة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<bool> deleteInvoice(InvoiceModel invoice) async {
    clearError(notify: false);

    return _runMutation(
      failureMessage: 'تعذر حذف الفاتورة',
      operation: () async {
        final invoiceKey = invoice.key;

        final currentInvoice = invoiceKey == null
            ? invoice
            : _invoiceByKey[invoiceKey] ?? invoice;

        final deleted = await _repository.deleteInvoice(
          invoice: currentInvoice,
          invoiceKey: invoiceKey,
        );

        if (!deleted) {
          _setOperationError('لم تعد الفاتورة موجودة');
          return false;
        }

        if (invoiceKey == null) {
          return loadInvoices(notify: false);
        }

        return _removeInvoiceFromMemory(invoiceKey);
      },
    );
  }

  Future<bool> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    clearError(notify: false);

    if (!item.price.isFinite || item.price <= 0) {
      _setOperationError('سعر العنصر غير صحيح');
      return false;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    if (!currentInvoice.canEditItems) {
      _setOperationError('لا يمكن تعديل عناصر فاتورة مدفوعة بالكامل');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر إضافة العنصر',
      operation: () async {
        final updatedInvoice = await _repository.addItem(
          invoiceKey: invoiceKey,
          item: item,
        );

        if (updatedInvoice == null) {
          _setOperationError('تعذر إضافة العنصر إلى هذه الفاتورة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<bool> updateItem({
    required InvoiceModel invoice,
    required int index,
    required InvoiceItemModel item,
  }) async {
    clearError(notify: false);

    if (!item.price.isFinite || item.price <= 0) {
      _setOperationError('سعر العنصر غير صحيح');
      return false;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    if (!currentInvoice.canEditItems) {
      _setOperationError('لا يمكن تعديل عناصر فاتورة مدفوعة بالكامل');
      return false;
    }

    if (index < 0 || index >= currentInvoice.items.length) {
      _setOperationError('العنصر لم يعد موجودًا');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر تعديل العنصر',
      operation: () async {
        final updatedInvoice = await _repository.updateItem(
          invoiceKey: invoiceKey,
          index: index,
          item: item,
        );

        if (updatedInvoice == null) {
          _setOperationError(
            'تعذر التعديل؛ تأكد أن الإجمالي ليس أقل من المدفوع',
          );
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<bool> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    clearError(notify: false);

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    final currentInvoice = _invoiceByKey[invoiceKey] ?? invoice;

    if (!currentInvoice.canEditItems) {
      _setOperationError('لا يمكن حذف عناصر فاتورة مدفوعة بالكامل');
      return false;
    }

    if (index < 0 || index >= currentInvoice.items.length) {
      _setOperationError('العنصر لم يعد موجودًا');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر حذف العنصر',
      operation: () async {
        final updatedInvoice = await _repository.deleteItem(
          invoiceKey: invoiceKey,
          index: index,
        );

        if (updatedInvoice == null) {
          _setOperationError('تعذر الحذف؛ لا يمكن جعل الإجمالي أقل من المدفوع');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  Future<void> compactStorage() {
    return _repository.compactInvoicesBox();
  }

  bool _replaceInvoiceInMemory(InvoiceModel updatedInvoice) {
    final updatedKey = updatedInvoice.key;

    if (updatedKey == null) {
      _setOperationError('تعذر تحديد الفاتورة بعد الحفظ');
      return false;
    }

    final index = _invoices.indexWhere((invoice) => invoice.key == updatedKey);

    if (index == -1) {
      final loaded = loadInvoices(notify: false);

      if (!loaded) {
        _setOperationError('تم الحفظ ولكن تعذر تحديث الواجهة');
      }

      return loaded;
    }

    final nextInvoices = List<InvoiceModel>.of(_invoices, growable: true);

    nextInvoices[index] = updatedInvoice;

    _invoices = List<InvoiceModel>.unmodifiable(nextInvoices);
    _invoiceByKey[updatedKey] = updatedInvoice;

    _bumpVersion();

    return true;
  }

  bool _removeInvoiceFromMemory(dynamic invoiceKey) {
    final beforeLength = _invoices.length;

    final nextInvoices = _invoices
        .where((invoice) => invoice.key != invoiceKey)
        .toList(growable: false);

    if (nextInvoices.length == beforeLength) {
      return loadInvoices(notify: false);
    }

    _invoices = List<InvoiceModel>.unmodifiable(nextInvoices);
    _invoiceByKey.remove(invoiceKey);

    _bumpVersion();

    return true;
  }

  static double _clampPaidAmount({
    required double paidAmount,
    required double total,
  }) {
    if (!total.isFinite || total <= 0) {
      return 0.0;
    }

    if (!paidAmount.isFinite || paidAmount < 0) {
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

  void clearError({bool notify = true}) {
    if (_lastError == null &&
        _lastStackTrace == null &&
        _lastErrorMessage == null) {
      return;
    }

    _lastError = null;
    _lastStackTrace = null;
    _lastErrorMessage = null;

    if (notify) {
      notifyListeners();
    }
  }

  void _recordError(
    Object error,
    StackTrace stackTrace, {
    required String message,
  }) {
    _lastError = error;
    _lastStackTrace = stackTrace;
    _lastErrorMessage = message;

    debugPrint(
      'InvoiceProvider error: $message\n'
      'Error: $error\n'
      'StackTrace: $stackTrace',
    );
  }

  void _setOperationError(String message) {
    _lastError = null;
    _lastStackTrace = null;
    _lastErrorMessage = message;
  }

  Future<bool> _runMutation({
    required String failureMessage,
    required Future<bool> Function() operation,
  }) async {
    if (_isMutating) {
      _setOperationError('توجد عملية حفظ أخرى قيد التنفيذ');
      return false;
    }

    _isMutating = true;
    clearError(notify: false);
    notifyListeners();

    try {
      final result = await operation();

      if (!result && _lastErrorMessage == null) {
        _lastErrorMessage = failureMessage;
      }

      return result;
    } catch (error, stackTrace) {
      _recordError(error, stackTrace, message: failureMessage);

      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }
}
