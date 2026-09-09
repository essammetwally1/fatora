import 'package:hive/hive.dart';

import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_payment_entry_model.dart';
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

  /// Moves the paid amount by [deltaAmount] and records what actually moved.
  ///
  /// Positive is a payment, negative a return. The delta is applied to
  /// `paidTotal` rather than to the raw `paidAmount` field, so a legacy
  /// invoice whose payment still lives on its items is topped up from its real
  /// balance instead of from zero.
  ///
  /// The entry stores the *clamped* movement, never the amount the caller
  /// asked for: paying 500 against a 300 remaining balance records 300, so the
  /// history always adds up to the stored total.
  Future<InvoiceModel?> applyPaidDelta({
    required dynamic invoiceKey,
    required double deltaAmount,
    DateTime? occurredAt,
  }) async {
    if (invoiceKey == null) return null;
    if (!deltaAmount.isFinite || deltaAmount == 0) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;

    final currentPaid = invoice.paidTotal;

    final nextPaidAmount = _clampPaidAmount(
      paidAmount: currentPaid + deltaAmount,
      total: invoice.total,
    );

    final appliedDelta = nextPaidAmount - currentPaid;

    // Nothing moved (paying zero against a full invoice, or dust). Recording a
    // zero-value entry would clutter the printed receipt for no information.
    if (appliedDelta.abs() <= _moneyTolerance) {
      return invoice;
    }

    final entry = InvoicePaymentEntryModel(
      amount: appliedDelta.abs(),
      isReturn: appliedDelta < 0,
      createdAt: occurredAt ?? DateTime.now(),
    );

    _prepareNewPaymentId(invoice: invoice, entry: entry);

    final previousPaidAmount = invoice.paidAmount;
    final previousPayments = invoice.payments;

    final nextPayments = List<InvoicePaymentEntryModel>.of(
      invoice.payments,
      growable: true,
    )..add(entry);

    try {
      // Also promotes any legacy item-level payment onto the invoice, because
      // `currentPaid` was read from `paidTotal`.
      invoice.paidAmount = nextPaidAmount;
      invoice.payments = nextPayments;

      await invoice.save();

      return invoice;
    } catch (_) {
      invoice.paidAmount = previousPaidAmount;
      invoice.payments = previousPayments;

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

    // Editing an item must not erase its legacy payment record. The sheet
    // always builds the replacement with a zeroed payment state, so carry the
    // stored one across. This is total-neutral: `paidAmount` is set to the
    // pre-edit `paidTotal` below, after which `paidTotal` reads the invoice
    // level and ignores these fields.
    item.isPaid = existingItem.isPaid;
    item.paidAmount = existingItem.paidAmount;
    item.normalizeLegacyPaymentState();

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
    // `Box.values` is a lazy view over Hive's keystore, and this loop awaits a
    // write inside it. Overwriting an existing key neither adds nor removes
    // keys, so iterating it directly happens to be safe — but this routine
    // touches every invoice the user owns, at startup, so it iterates a
    // snapshot of the keys instead of relying on that.
    final keys = _box.keys.toList(growable: false);

    for (final key in keys) {
      final invoice = _box.get(key);

      if (invoice == null) continue;

      final previousPaidAmount = invoice.paidAmount;

      invoice.normalizeBasicData();
      invoice.migrateLegacyPaymentToInvoicePaymentIfNeeded();

      final itemIdsChanged = _ensureUniqueItemIds(invoice);
      final paymentIdsChanged = _ensureUniquePaymentIds(invoice);

      final paymentChanged = invoice.paidAmount != previousPaidAmount;

      if (itemIdsChanged || paymentIdsChanged || paymentChanged) {
        await invoice.save();
      }
    }
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

  static void _prepareNewPaymentId({
    required InvoiceModel invoice,
    required InvoicePaymentEntryModel entry,
  }) {
    entry.ensureStableId();

    final existingIds = invoice.payments
        .map((existingEntry) => existingEntry.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    while (existingIds.contains(entry.id)) {
      entry.regenerateId();
    }
  }

  static bool _ensureUniquePaymentIds(InvoiceModel invoice) {
    var didChange = false;
    final usedIds = <String>{};

    for (final entry in invoice.payments) {
      if (entry.ensureStableId()) {
        didChange = true;
      }

      while (!usedIds.add(entry.id)) {
        entry.regenerateId();
        didChange = true;
      }
    }

    return didChange;
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
