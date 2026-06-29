import 'package:hive_flutter/hive_flutter.dart';

import '../../models/fixed_menu_item_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';

class HiveService {
  static const String invoiceBox = 'invoiceBox';
  static const String settingsBox = 'settingsBox';
  static const String fixedMenuBox = 'fixedMenuBox';

  static const String themeModeKey = 'themeMode';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(InvoiceItemModelAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(InvoiceModelAdapter());
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FixedMenuItemModelAdapter());
    }

    if (!Hive.isBoxOpen(invoiceBox)) {
      await Hive.openBox<InvoiceModel>(invoiceBox);
    }

    if (!Hive.isBoxOpen(settingsBox)) {
      await Hive.openBox(settingsBox);
    }

    if (!Hive.isBoxOpen(fixedMenuBox)) {
      await Hive.openBox<FixedMenuItemModel>(fixedMenuBox);
    }
  }

  static Box<InvoiceModel> getInvoiceBox() {
    return Hive.box<InvoiceModel>(invoiceBox);
  }

  // Keep this if your InvoiceProvider already uses HiveService.getBox()
  static Box<InvoiceModel> getBox() {
    return getInvoiceBox();
  }

  static Box getSettingsBox() {
    return Hive.box(settingsBox);
  }

  static Box<FixedMenuItemModel> getFixedMenuBox() {
    return Hive.box<FixedMenuItemModel>(fixedMenuBox);
  }
}
