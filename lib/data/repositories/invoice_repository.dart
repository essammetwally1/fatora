import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../services/storage/hive_service.dart';

class InvoiceRepository {
  List<InvoiceModel> getInvoices() {
    final invoices = HiveService.getInvoiceBox().values.toList(growable: false);

    invoices.sort(_compareInvoicesNewestFirst);

    return invoices;
  }

  Future<InvoiceModel> createInvoice(String title) async {
    final box = HiveService.getInvoiceBox();

    final invoice = InvoiceModel(title: title, items: []);

    await box.add(invoice);

    return invoice;
  }

  Future<InvoiceModel?> updateInvoiceTitle({
    required dynamic invoiceKey,
    required String title,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = HiveService.getInvoiceBox().get(invoiceKey);

    if (invoice == null) return null;

    invoice.title = title;
    await invoice.save();

    return invoice;
  }

  Future<bool> deleteInvoice({required dynamic invoiceKey}) async {
    if (invoiceKey == null) return false;

    final box = HiveService.getInvoiceBox();

    if (!box.containsKey(invoiceKey)) return false;

    await box.delete(invoiceKey);

    return true;
  }

  Future<InvoiceModel?> addItem({
    required dynamic invoiceKey,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = HiveService.getInvoiceBox().get(invoiceKey);

    if (invoice == null) return null;

    invoice.items.add(item);
    await invoice.save();

    return invoice;
  }

  Future<InvoiceModel?> updateItem({
    required dynamic invoiceKey,
    required int index,
    required InvoiceItemModel item,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = HiveService.getInvoiceBox().get(invoiceKey);

    if (invoice == null) return null;
    if (!_isValidItemIndex(invoice, index)) return null;

    invoice.items[index] = item;
    await invoice.save();

    return invoice;
  }

  Future<InvoiceModel?> deleteItem({
    required dynamic invoiceKey,
    required int index,
  }) async {
    if (invoiceKey == null) return null;

    final invoice = HiveService.getInvoiceBox().get(invoiceKey);

    if (invoice == null) return null;
    if (!_isValidItemIndex(invoice, index)) return null;

    invoice.items.removeAt(index);
    await invoice.save();

    return invoice;
  }

  Future<void> compactInvoicesBox() {
    return HiveService.getInvoiceBox().compact();
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
