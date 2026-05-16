// hive_service.dart

import 'package:hive_flutter/hive_flutter.dart';

import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';

class HiveService {
  static const String invoiceBox = 'invoiceBox';

  // PUT THIS TEMPORARILY INSIDE HiveService.init()

  static Future<void> init() async {
    await Hive.initFlutter();

    // await Hive.deleteBoxFromDisk('invoiceBox');

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(InvoiceItemModelAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(InvoiceModelAdapter());
    }

    await Hive.openBox<InvoiceModel>(invoiceBox);
  }

  static Box<InvoiceModel> getBox() {
    return Hive.box<InvoiceModel>(invoiceBox);
  }
}
