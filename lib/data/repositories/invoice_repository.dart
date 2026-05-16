// invoice_repository.dart

import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../services/hive_service.dart';

class InvoiceRepository {
  final box = HiveService.getBox();

  List<InvoiceModel> getInvoices() {
    return box.values.toList();
  }

  Future<void> createInvoice(String title) async {
    final invoice = InvoiceModel(title: title, items: []);

    await box.add(invoice);
  }

  Future<void> deleteInvoice(int index) async {
    await box.deleteAt(index);
  }

  Future<void> addItem({
    required InvoiceModel invoice,
    required InvoiceItemModel item,
  }) async {
    invoice.items.add(item);

    await invoice.save();
  }

  Future<void> deleteItem({
    required InvoiceModel invoice,
    required int index,
  }) async {
    invoice.items.removeAt(index);

    await invoice.save();
  }
}
