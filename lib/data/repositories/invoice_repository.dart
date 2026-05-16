import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../services/hive_service.dart';

class InvoiceRepository {
  List<InvoiceModel> getInvoices() {
    return HiveService.getBox().values.toList();
  }

  Future<void> createInvoice(String title) async {
    final invoice = InvoiceModel(title: title, items: []);

    await HiveService.getBox().add(invoice);
  }

  Future<void> updateInvoiceTitle({
    required dynamic invoiceKey,
    required String title,
  }) async {
    final box = HiveService.getBox();
    final invoice = box.get(invoiceKey);

    if (invoice == null) return;

    invoice.title = title;
    await invoice.save();
  }

  Future<void> deleteInvoice(int index) async {
    final box = HiveService.getBox();
    await box.deleteAt(index);
    await box.compact();
  }

  Future<void> addItem({
    required dynamic invoiceKey,
    required InvoiceItemModel item,
  }) async {
    final box = HiveService.getBox();
    final invoice = box.get(invoiceKey);

    if (invoice == null) return;

    invoice.items.add(item);
    await invoice.save();
  }

  Future<void> updateItem({
    required dynamic invoiceKey,
    required int index,
    required InvoiceItemModel item,
  }) async {
    final box = HiveService.getBox();
    final invoice = box.get(invoiceKey);

    if (invoice == null) return;
    if (index < 0 || index >= invoice.items.length) return;

    invoice.items[index] = item;
    await invoice.save();
  }

  Future<void> deleteItem({
    required dynamic invoiceKey,
    required int index,
  }) async {
    final box = HiveService.getBox();
    final invoice = box.get(invoiceKey);

    if (invoice == null) return;
    if (index < 0 || index >= invoice.items.length) return;

    invoice.items.removeAt(index);
    await invoice.save();
    await box.compact();
  }
}
