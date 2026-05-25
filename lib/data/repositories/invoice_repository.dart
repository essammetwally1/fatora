import 'package:hive/hive.dart';

import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../services/storage/hive_service.dart';

class InvoiceRepository {
  Box<InvoiceModel> get _box => HiveService.getInvoiceBox();

  List<InvoiceModel> getInvoices() {
    final invoices = _box.values.toList(growable: false);
    invoices.sort(_compareInvoicesNewestFirst);
    return invoices;
  }

  Future<InvoiceModel> createInvoice(String title) async {
    final invoice = InvoiceModel(
      title: title.trim(),
      items: <InvoiceItemModel>[],
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

    invoice.title = cleanTitle;
    await invoice.save();

    return invoice;
  }

  Future<bool> deleteInvoice({
    required InvoiceModel invoice,
    dynamic invoiceKey,
  }) async {
    final key = invoiceKey ?? invoice.key;

    // Main path: delete by Hive key.
    if (key != null && _box.containsKey(key)) {
      await _box.delete(key);
      return !_box.containsKey(key);
    }

    // Fallback path: if this object is still attached to Hive,
    // delete it directly through HiveObject.
    if (invoice.isInBox) {
      final attachedKey = invoice.key;

      await invoice.delete();

      if (attachedKey == null) {
        return !invoice.isInBox;
      }

      return !_box.containsKey(attachedKey);
    }

    return false;
  }

  Future<InvoiceModel?> addItem({
    required dynamic invoiceKey,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;

    final nextItems = List<InvoiceItemModel>.of(invoice.items, growable: true)
      ..add(item);

    invoice.items = nextItems;
    await invoice.save();

    return invoice;
  }

  Future<InvoiceModel?> updateItem({
    required dynamic invoiceKey,
    required int index,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;
    if (!_isValidItemIndex(invoice, index)) return null;

    final nextItems = List<InvoiceItemModel>.of(invoice.items, growable: true);

    nextItems[index] = item;

    invoice.items = nextItems;
    await invoice.save();

    return invoice;
  }

  Future<InvoiceModel?> deleteItem({
    required dynamic invoiceKey,
    required int index,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = _box.get(invoiceKey);
    if (invoice == null) return null;
    if (!_isValidItemIndex(invoice, index)) return null;

    final nextItems = List<InvoiceItemModel>.of(invoice.items, growable: true)
      ..removeAt(index);

    invoice.items = nextItems;
    await invoice.save();

    return invoice;
  }

  Future<void> compactInvoicesBox() {
    return _box.compact();
  }

  static int _compareInvoicesNewestFirst(InvoiceModel a, InvoiceModel b) {
    final aKey = a.key;
    final bKey = b.key;

    if (aKey is int && bKey is int) {
      return bKey.compareTo(aKey);
    }

    return 0;
  }

  static bool _isValidItemIndex(InvoiceModel invoice, int index) {
    return index >= 0 && index < invoice.items.length;
  }
}
