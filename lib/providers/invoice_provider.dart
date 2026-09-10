import 'package:fatora/data/models/invoice_month_key.dart';
import 'package:fatora/data/models/invoice_month_snapshot.dart';
import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceRepository _repository = InvoiceRepository();
  static const double _moneyTolerance = 0.000001;
  List<InvoiceModel> _invoices = const [];
  final Map<dynamic, InvoiceModel> _invoiceByKey = <dynamic, InvoiceModel>{};

  int _version = 0;
  InvoiceMonthKey _currentMonth = InvoiceMonthKey.current();
  List<InvoiceMonthSnapshot> _invoiceMonths = const [];
  final Map<InvoiceMonthKey, InvoiceMonthSnapshot> _snapshotByMonth =
      <InvoiceMonthKey, InvoiceMonthSnapshot>{};
  List<InvoiceModel> _currentMonthInvoices = const [];
  InvoicesTotals _currentMonthTotals = InvoicesTotals.empty();
  List<InvoiceModel> _starredInvoices = const [];

  bool _isLoading = false;
  bool _isMutating = false;

  Object? _lastError;
  StackTrace? _lastStackTrace;
  String? _lastErrorMessage;

  Object? get lastError => _lastError;
  StackTrace? get lastStackTrace => _lastStackTrace;
  String? get lastErrorMessage => _lastErrorMessage;

  List<InvoiceModel> get invoices => _invoices;

  InvoiceMonthKey get currentMonth => _currentMonth;

  List<InvoiceModel> get currentMonthInvoices => _currentMonthInvoices;

  InvoicesTotals get currentMonthTotals => _currentMonthTotals;

  List<InvoiceMonthSnapshot> get invoiceMonths => _invoiceMonths;

  /// Starred invoices across every month, newest first.
  ///
  /// Built once per data change alongside the monthly snapshots rather than
  /// filtered in `build`, so opening the drawer never walks the whole invoice
  /// list.
  List<InvoiceModel> get starredInvoices => _starredInvoices;

  int get version => _version;

  bool get isLoading => _isLoading;

  bool get isMutating => _isMutating;

  InvoiceMonthSnapshot? monthSnapshot(InvoiceMonthKey month) {
    return _snapshotByMonth[month];
  }

  List<InvoiceModel> invoicesForMonth(InvoiceMonthKey month) {
    return _snapshotByMonth[month]?.invoices ?? const <InvoiceModel>[];
  }

  InvoicesTotals totalsForMonth(InvoiceMonthKey month) {
    return _snapshotByMonth[month]?.totals ?? InvoicesTotals.empty();
  }

  bool refreshCurrentMonthIfNeeded({bool notify = true}) {
    final nextCurrentMonth = InvoiceMonthKey.current();
    if (nextCurrentMonth == _currentMonth) return false;

    _currentMonth = nextCurrentMonth;
    _rebuildDerivedState();
    _bumpVersion();

    if (notify) {
      notifyListeners();
    }

    return true;
  }

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

      _currentMonth = InvoiceMonthKey.current();
      _rebuildDerivedState();
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

  /// One-time startup routine: normalise legacy Hive records, then load.
  ///
  /// Migration back-fills stable item IDs and promotes old per-item payments
  /// to the invoice-level `paidAmount`. Without it, items saved by older
  /// versions keep an empty ID and cannot be selected or deleted.
  ///
  /// Loading is deliberately outside the mutation: if migration fails on one
  /// bad record the user still gets their invoice list rather than a blank
  /// screen. The failure is recorded and logged.
  Future<void> bootstrap() async {
    await _runMutation(
      failureMessage: 'تعذر تحديث البيانات القديمة',
      operation: () async {
        await _repository.migrateStoredInvoices();

        return true;
      },
    );

    loadInvoices();
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
        final actualCurrentMonth = InvoiceMonthKey.current();

        if (actualCurrentMonth != _currentMonth) {
          _currentMonth = actualCurrentMonth;
        }

        final createdInvoice = await _repository.createInvoice(cleanTitle);

        _invoices = List<InvoiceModel>.unmodifiable([
          createdInvoice,
          ..._invoices,
        ]);

        final createdKey = createdInvoice.key;

        if (createdKey != null) {
          _invoiceByKey[createdKey] = createdInvoice;
        }

        _rebuildDerivedState();
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

  /// Sets the paid amount to an absolute value.
  ///
  /// Expressed as a delta so that the move is recorded in the invoice's
  /// payment history like any other; setting the field directly would leave
  /// money on the invoice that no dated entry accounts for.
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

    final delta = cleanPaidAmount - currentInvoice.paidTotal;

    if (delta.abs() <= _moneyTolerance) {
      return true;
    }

    return applyInvoicePaidDelta(invoice: currentInvoice, deltaAmount: delta);
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

    if ((nextPaidAmount - currentInvoice.paidTotal).abs() <= _moneyTolerance) {
      return true;
    }

    return _runMutation(
      failureMessage: 'تعذر حفظ عملية الدفع',
      operation: () async {
        // The repository re-clamps against freshly read storage and records
        // the movement that actually landed, so the printed history always
        // reconciles with the stored total.
        final updatedInvoice = await _repository.applyPaidDelta(
          invoiceKey: invoiceKey,
          deltaAmount: deltaAmount,
        );

        if (updatedInvoice == null) {
          _setOperationError('لم تعد الفاتورة موجودة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  /// Removes one recorded payment or return from the invoice's history.
  ///
  /// The money goes with it: the repository lowers the paid total by the same
  /// movement, so the breakdown keeps reconciling instead of re-printing the
  /// deleted entry as an undated balance.
  Future<bool> deletePaymentEntry({
    required InvoiceModel invoice,
    required String entryId,
  }) async {
    clearError(notify: false);

    final cleanEntryId = entryId.trim();

    if (cleanEntryId.isEmpty) {
      _setOperationError('تعذر تحديد العملية');
      return false;
    }

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return false;
    }

    return _runMutation(
      failureMessage: 'تعذر حذف العملية',
      operation: () async {
        final updatedInvoice = await _repository.deletePaymentEntry(
          invoiceKey: invoiceKey,
          entryId: cleanEntryId,
        );

        if (updatedInvoice == null) {
          _setOperationError('لم تعد هذه العملية موجودة');
          return false;
        }

        return _replaceInvoiceInMemory(updatedInvoice);
      },
    );
  }

  /// Shows or hides the dated breakdown on the exported PDF and image.
  Future<bool> setPaymentDetailsHiddenInExport({
    required InvoiceModel invoice,
    required bool hidden,
  }) {
    return _setInvoiceFlag(
      invoice: invoice,
      failureMessage: 'تعذر حفظ إعداد طباعة التفاصيل',
      write: (invoiceKey) => _repository.setPaymentDetailsHiddenInExport(
        invoiceKey: invoiceKey,
        hidden: hidden,
      ),
    );
  }

  Future<bool> setInvoiceStarred({
    required InvoiceModel invoice,
    required bool starred,
  }) {
    return _setInvoiceFlag(
      invoice: invoice,
      failureMessage: starred
          ? 'تعذر تمييز الفاتورة'
          : 'تعذر إلغاء تمييز الفاتورة',
      write: (invoiceKey) =>
          _repository.setStarred(invoiceKey: invoiceKey, starred: starred),
    );
  }

  Future<bool> _setInvoiceFlag({
    required InvoiceModel invoice,
    required String failureMessage,
    required Future<InvoiceModel?> Function(dynamic invoiceKey) write,
  }) {
    clearError(notify: false);

    final invoiceKey = invoice.key;

    if (invoiceKey == null) {
      _setOperationError('الفاتورة غير محفوظة');
      return Future<bool>.value(false);
    }

    return _runMutation(
      failureMessage: failureMessage,
      operation: () async {
        final updatedInvoice = await write(invoiceKey);

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
    final invoiceKey = invoice.key;

    final currentInvoice = invoiceKey == null
        ? invoice
        : _invoiceByKey[invoiceKey] ?? invoice;

    if (index < 0 || index >= currentInvoice.items.length) {
      _setOperationError('العنصر لم يعد موجودًا');
      return false;
    }

    final itemId = currentInvoice.items[index].id.trim();

    if (itemId.isEmpty) {
      _setOperationError('تعذر تحديد العنصر');
      return false;
    }

    return deleteItems(invoice: currentInvoice, itemIds: <String>{itemId});
  }

  Future<bool> deleteItems({
    required InvoiceModel invoice,
    required Set<String> itemIds,
  }) async {
    clearError(notify: false);

    final normalizedItemIds = itemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (normalizedItemIds.isEmpty) {
      _setOperationError('لم يتم تحديد أي عناصر');
      return false;
    }

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

    final currentItemIds = currentInvoice.items
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (!currentItemIds.containsAll(normalizedItemIds)) {
      _setOperationError('بعض العناصر المحددة لم تعد موجودة');
      return false;
    }

    var nextTotal = 0.0;

    for (final item in currentInvoice.items) {
      if (!normalizedItemIds.contains(item.id.trim())) {
        nextTotal += item.price;
      }
    }

    if (_isPaidAmountAboveTotal(
      paidAmount: currentInvoice.paidTotal,
      total: nextTotal,
    )) {
      _setOperationError(
        'لا يمكن حذف العناصر المحددة لأن إجمالي الفاتورة سيصبح أقل من المبلغ المدفوع',
      );
      return false;
    }

    final isSingleItem = normalizedItemIds.length == 1;

    return _runMutation(
      failureMessage: isSingleItem
          ? 'تعذر حذف العنصر'
          : 'تعذر حذف العناصر المحددة',
      operation: () async {
        final updatedInvoice = await _repository.deleteItems(
          invoiceKey: invoiceKey,
          itemIds: normalizedItemIds,
        );

        if (updatedInvoice == null) {
          _setOperationError(
            isSingleItem
                ? 'تعذر حذف العنصر؛ ربما تغيرت بيانات الفاتورة'
                : 'تعذر حذف العناصر؛ ربما تغيرت بيانات الفاتورة',
          );

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
    _rebuildDerivedState();
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

    _rebuildDerivedState();
    _bumpVersion();

    return true;
  }

  /// Recomputes everything the UI reads that is derived from [_invoices].
  void _rebuildDerivedState() {
    _rebuildMonthlySnapshots();
    _rebuildStarredInvoices();
  }

  void _rebuildStarredInvoices() {
    final starred = <InvoiceModel>[];

    // `_invoices` is already sorted newest first, so the filtered view
    // inherits that order without a second sort.
    for (final invoice in _invoices) {
      if (invoice.isStarred) starred.add(invoice);
    }

    _starredInvoices = starred.isEmpty
        ? const <InvoiceModel>[]
        : List<InvoiceModel>.unmodifiable(starred);
  }

  void _rebuildMonthlySnapshots() {
    final grouped = <InvoiceMonthKey, List<InvoiceModel>>{};

    for (final invoice in _invoices) {
      // Undated invoices go to their own bucket, never to the current month.
      // Counting them as this month's business overstated current revenue by
      // exactly the amount every historical month was understated, and the
      // distortion followed the calendar forward at each rollover.
      final month = invoice.isLegacyDate
          ? const InvoiceMonthKey.legacy()
          : InvoiceMonthKey.fromDate(invoice.listDate);

      grouped.putIfAbsent(month, () => <InvoiceModel>[]).add(invoice);
    }

    // The current month must always exist,
    // even when it contains zero invoices.
    grouped.putIfAbsent(_currentMonth, () => <InvoiceModel>[]);

    final sortedMonths = grouped.keys.toList(growable: false)..sort();

    final snapshots = <InvoiceMonthSnapshot>[];

    final snapshotMap = <InvoiceMonthKey, InvoiceMonthSnapshot>{};

    for (final month in sortedMonths) {
      final monthInvoices = List<InvoiceModel>.unmodifiable(
        grouped[month] ?? const <InvoiceModel>[],
      );

      final snapshot = InvoiceMonthSnapshot(
        month: month,
        invoices: monthInvoices,
        totals: InvoicesTotals.fromInvoices(monthInvoices),
        isCurrentMonth: month == _currentMonth,
      );

      snapshots.add(snapshot);
      snapshotMap[month] = snapshot;
    }

    _invoiceMonths = List<InvoiceMonthSnapshot>.unmodifiable(snapshots);

    _snapshotByMonth
      ..clear()
      ..addAll(snapshotMap);

    final currentSnapshot = _snapshotByMonth[_currentMonth];

    _currentMonthInvoices = currentSnapshot?.invoices ?? const <InvoiceModel>[];

    _currentMonthTotals = currentSnapshot?.totals ?? InvoicesTotals.empty();
  }

  static bool _isPaidAmountAboveTotal({
    required double paidAmount,
    required double total,
  }) {
    return paidAmount - total > _moneyTolerance;
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
