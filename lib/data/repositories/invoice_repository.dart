import 'package:hive/hive.dart';

import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../services/storage/hive_service.dart';

class InvoiceRepository {
  static const double _moneyTolerance = 0.000001;

  Box<InvoiceModel> get _box => HiveService.getInvoiceBox();

  List<InvoiceModel> getInvoices() {
    final invoices = _box.values.toList(growable: false);

    for (final invoice in invoices) {
      invoice.normalizeBasicData();
    }

    invoices.sort(_compareInvoicesNewestFirst);
    return invoices;
  }

  Future<InvoiceModel> createInvoice(String title) async {
    final invoice = InvoiceModel(
      title: title.trim(),
      items: <InvoiceItemModel>[],
      paidAmount: 0.0,
      createdAt: DateTime.now(),
    );

    await _box.add(invoice);
    return invoice;
  }

  Future<InvoiceModel?> updateInvoiceTitle({
    required dynamic invoiceKey,
    required String title,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return null;

    final previousTitle = invoice.title;

    try {
      invoice.title = cleanTitle;

      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.title = previousTitle;
      rethrow;
    }
  }

  Future<InvoiceModel?> updateInvoicePaidAmount({
    required dynamic invoiceKey,
    required double paidAmount,
  }) async {
    if (invoiceKey == null) return null;
    if (!paidAmount.isFinite) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;

    final previousPaidAmount = invoice.paidAmount;

    final legacySnapshots = invoice.items
        .map(
          (item) => _LegacyPaymentSnapshot(
            item: item,
            isPaid: item.isPaid,
            paidAmount: item.paidAmount,
          ),
        )
        .toList(growable: false);

    try {
      invoice.paidAmount = _clampPaidAmount(
        paidAmount: paidAmount,
        total: invoice.total,
      );

      invoice.clearLegacyItemPayments();

      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.paidAmount = previousPaidAmount;

      for (final snapshot in legacySnapshots) {
        snapshot.restore();
      }

      rethrow;
    }
  }

  Future<bool> deleteInvoice({
    required InvoiceModel invoice,
    dynamic invoiceKey,
  }) async {
    final key = invoiceKey ?? invoice.key;

    if (key != null && _box.containsKey(key)) {
      await _box.delete(key);
      return !_box.containsKey(key);
    }

    if (invoice.isInBox) {
      final attachedKey = invoice.key;
      await invoice.delete();

      if (attachedKey == null) return !invoice.isInBox;
      return !_box.containsKey(attachedKey);
    }

    return false;
  }

  Future<InvoiceModel?> addItem({
    required dynamic invoiceKey,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;
    if (!item.price.isFinite || item.price <= 0) return null;

    final invoice = _box.get(invoiceKey);

    if (invoice == null) return null;
    if (invoice.isPaymentCompleted) return null;

    item.normalizeBasicData();
    item.clearLegacyPaymentState();
    _prepareNewItemId(invoice: invoice, item: item);

    final effectivePaidAmount = invoice.paidTotal;

    final previousItems = invoice.items;
    final previousPaidAmount = invoice.paidAmount;

    final nextItems = List<InvoiceItemModel>.of(invoice.items, growable: true)
      ..add(item);

    try {
      invoice.items = nextItems;
      invoice.paidAmount = effectivePaidAmount;

      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.items = previousItems;
      invoice.paidAmount = previousPaidAmount;

      rethrow;
    }
  }

  Future<InvoiceModel?> updateItem({
    required dynamic invoiceKey,
    required int index,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);

    if (invoice == null) return null;
    if (invoice.isPaymentCompleted) return null;
    if (!_isValidItemIndex(invoice, index)) return null;
    if (!item.price.isFinite || item.price <= 0) return null;

    final existingItem = invoice.items[index];

    existingItem.ensureStableId();

    item.id = existingItem.id;
    item.normalizeBasicData();
    item.clearLegacyPaymentState();

    final effectivePaidAmount = invoice.paidTotal;

    final nextItems = List<InvoiceItemModel>.of(invoice.items, growable: true);

    nextItems[index] = item;

    final nextTotal = _calculateTotal(nextItems);

    if (_isPaidAmountAboveTotal(
      paidAmount: effectivePaidAmount,
      total: nextTotal,
    )) {
      return null;
    }

    final previousItems = invoice.items;
    final previousPaidAmount = invoice.paidAmount;

    try {
      invoice.items = nextItems;

      // Also safely promotes old item-level payment to invoice payment.
      invoice.paidAmount = effectivePaidAmount;

      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.items = previousItems;
      invoice.paidAmount = previousPaidAmount;

      rethrow;
    }
  }

  Future<InvoiceModel?> deleteItem({
    required dynamic invoiceKey,
    required int index,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);

    if (invoice == null) return null;
    if (!_isValidItemIndex(invoice, index)) return null;

    final itemId = invoice.items[index].id.trim();

    if (itemId.isEmpty) return null;

    return _deleteItemsFromInvoice(invoice: invoice, itemIds: <String>{itemId});
  }

  Future<InvoiceModel?> deleteItems({
    required dynamic invoiceKey,
    required Set<String> itemIds,
  }) async {
    if (invoiceKey == null) return null;

    final normalizedItemIds = itemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (normalizedItemIds.isEmpty) return null;

    final invoice = _box.get(invoiceKey);

    if (invoice == null) return null;

    return _deleteItemsFromInvoice(
      invoice: invoice,
      itemIds: normalizedItemIds,
    );
  }

  Future<InvoiceModel?> _deleteItemsFromInvoice({
    required InvoiceModel invoice,
    required Set<String> itemIds,
  }) async {
    if (invoice.isPaymentCompleted) return null;
    if (itemIds.isEmpty) return null;

    final effectivePaidAmount = invoice.paidTotal;

    final nextItems = <InvoiceItemModel>[];

    var nextTotal = 0.0;
    var removedCount = 0;

    for (final item in invoice.items) {
      final itemId = item.id.trim();

      if (itemIds.contains(itemId)) {
        removedCount++;
        continue;
      }

      nextItems.add(item);
      nextTotal += item.price;
    }

    // Prevent partial or unexpected deletion.
    //
    // This also protects against:
    // - stale selections;
    // - missing IDs;
    // - duplicated IDs.
    if (removedCount != itemIds.length) {
      return null;
    }

    if (_isPaidAmountAboveTotal(
      paidAmount: effectivePaidAmount,
      total: nextTotal,
    )) {
      return null;
    }

    final previousItems = invoice.items;
    final previousPaidAmount = invoice.paidAmount;

    try {
      invoice.items = nextItems;
      invoice.paidAmount = effectivePaidAmount;

      // Only one Hive write for all selected items.
      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.items = previousItems;
      invoice.paidAmount = previousPaidAmount;

      rethrow;
    }
  }

  Future<void> migrateStoredInvoices() async {
    for (final invoice in _box.values) {
      final previousPaidAmount = invoice.paidAmount;

      invoice.normalizeBasicData();
      invoice.migrateLegacyPaymentToInvoicePaymentIfNeeded();

      final itemIdsChanged = _ensureUniqueItemIds(invoice);

      final paymentChanged = invoice.paidAmount != previousPaidAmount;

      if (itemIdsChanged || paymentChanged) {
        await invoice.save();
      }
    }
  }

  /// Temporary compatibility method.
  ///
  /// This can be removed after all callers use [migrateStoredInvoices].
  Future<void> migrateLegacyPaymentsToInvoicePayments() {
    return migrateStoredInvoices();
  }

  Future<void> compactInvoicesBox() {
    return _box.compact();
  }

  static int _compareInvoicesNewestFirst(InvoiceModel a, InvoiceModel b) {
    final dateCompare = b.listDate.compareTo(a.listDate);
    if (dateCompare != 0) return dateCompare;

    final aKey = a.key;
    final bKey = b.key;

    if (aKey is int && bKey is int) {
      return bKey.compareTo(aKey);
    }

    return 0;
  }

  static void _prepareNewItemId({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) {
    item.ensureStableId();

    final existingIds = invoice.items
        .map((existingItem) => existingItem.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    while (existingIds.contains(item.id)) {
      item.regenerateId();
    }
  }

  static bool _ensureUniqueItemIds(InvoiceModel invoice) {
    var didChange = false;
    final usedIds = <String>{};

    for (final item in invoice.items) {
      if (item.ensureStableId()) {
        didChange = true;
      }

      while (!usedIds.add(item.id)) {
        item.regenerateId();
        didChange = true;
      }
    }

    return didChange;
  }

  static bool _isValidItemIndex(InvoiceModel invoice, int index) {
    return index >= 0 && index < invoice.items.length;
  }

  static double _calculateTotal(List<InvoiceItemModel> items) {
    var total = 0.0;

    for (final item in items) {
      total += item.price;
    }

    return total;
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

  static bool _isPaidAmountAboveTotal({
    required double paidAmount,
    required double total,
  }) {
    return paidAmount - total > _moneyTolerance;
  }
}

class _LegacyPaymentSnapshot {
  final InvoiceItemModel item;
  final bool isPaid;
  final double paidAmount;

  const _LegacyPaymentSnapshot({
    required this.item,
    required this.isPaid,
    required this.paidAmount,
  });

  void restore() {
    item.isPaid = isPaid;
    item.paidAmount = paidAmount;
  }
}
