import 'dart:io';

import 'package:fatora/data/models/fixed_menu_item_model.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// Opens the app's real Hive boxes against a throwaway directory.
///
/// The repositories reach for boxes by name through [HiveService], so tests
/// exercise the same storage path production does rather than a stand-in.
class HiveTestEnv {
  Directory? _directory;

  Future<void> setUp() async {
    _directory = await Directory.systemTemp.createTemp('fatora_test_');

    Hive.init(_directory!.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(InvoiceItemModelAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(InvoiceModelAdapter());
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FixedMenuItemModelAdapter());
    }

    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(InvoicePaymentEntryModelAdapter());
    }

    await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);
    await Hive.openBox<FixedMenuItemModel>(HiveService.fixedMenuBox);
  }

  Future<void> tearDown() async {
    await Hive.deleteBoxFromDisk(HiveService.invoiceBox);
    await Hive.deleteBoxFromDisk(HiveService.fixedMenuBox);
    await Hive.close();

    final directory = _directory;

    if (directory != null && directory.existsSync()) {
      await directory.delete(recursive: true);
    }

    _directory = null;
  }
}

/// Builds an invoice shaped the way versions before v1.1.10 stored them:
/// no `createdAt`, no item IDs, and payment recorded per item rather than on
/// the invoice.
///
/// The fields are set after construction because the constructor deliberately
/// back-fills IDs and normalises payment — which is exactly the behaviour
/// under test, so it must not be applied to the fixture itself.
InvoiceModel buildLegacyInvoice({
  required String title,
  required List<({String name, double price, double paid})> items,
}) {
  final invoice = InvoiceModel(
    title: title,
    items: items
        .map((item) => InvoiceItemModel(itemName: item.name, price: item.price))
        .toList(),
  );

  invoice.createdAt = null;
  invoice.paidAmount = 0.0;

  for (var index = 0; index < items.length; index++) {
    final source = items[index];
    final target = invoice.items[index];

    target.id = '';
    target.paidAmount = source.paid;
    target.isPaid = source.paid >= source.price && source.price > 0;
  }

  return invoice;
}
