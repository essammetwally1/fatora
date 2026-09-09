import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/repositories/fixed_menu_repository.dart';
import 'package:fatora/data/repositories/invoice_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = HiveTestEnv();

  setUp(() => env.setUp());
  tearDown(() => env.tearDown());

  group('the menu is the catalogue, the invoice is the transaction', () {
    test('raising a menu price leaves an existing invoice untouched', () async {
      final menu = FixedMenuRepository();
      final invoices = InvoiceRepository();

      // January: the item costs 100.
      final menuItem = await menu.createItem(name: 'عدسة طبية', price: 100.0);

      final invoice = await invoices.createInvoice('عميل يناير');

      // Adding it to an invoice copies name and price by value. This mirrors
      // what InvoiceItemSheet does when the user picks from the menu.
      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(
          itemName: menuItem.displayName,
          price: menuItem.price,
        ),
      );

      expect(invoices.getInvoices().single.total, 100.0);

      // March: the price goes up.
      await menu.updateItem(
        itemKey: menuItem.key,
        name: 'عدسة طبية',
        price: 150.0,
      );

      expect(menu.getItems().single.price, 150.0);

      // The January invoice must still read 100.
      final januaryInvoice = invoices.getInvoices().single;

      expect(januaryInvoice.items.single.price, 100.0);
      expect(januaryInvoice.total, 100.0);
    });

    test('renaming a menu item leaves an existing invoice untouched', () async {
      final menu = FixedMenuRepository();
      final invoices = InvoiceRepository();

      final menuItem = await menu.createItem(name: 'إطار معدني', price: 200.0);

      final invoice = await invoices.createInvoice('عميل');

      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(
          itemName: menuItem.displayName,
          price: menuItem.price,
        ),
      );

      await menu.updateItem(
        itemKey: menuItem.key,
        name: 'إطار معدني فاخر',
        price: 200.0,
      );

      expect(invoices.getInvoices().single.items.single.itemName, 'إطار معدني');
    });

    test('deleting a menu item leaves an existing invoice intact', () async {
      final menu = FixedMenuRepository();
      final invoices = InvoiceRepository();

      final menuItem = await menu.createItem(name: 'عدسة طبية', price: 100.0);

      final invoice = await invoices.createInvoice('عميل');

      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(
          itemName: menuItem.displayName,
          price: menuItem.price,
        ),
      );

      await menu.deleteItem(item: menuItem, itemKey: menuItem.key);

      expect(menu.getItems(), isEmpty);

      final stored = invoices.getInvoices().single;

      expect(stored.items.single.itemName, 'عدسة طبية');
      expect(stored.total, 100.0);
    });

    test('a later invoice picks up the new price', () async {
      final menu = FixedMenuRepository();
      final invoices = InvoiceRepository();

      final menuItem = await menu.createItem(name: 'عدسة طبية', price: 100.0);

      final january = await invoices.createInvoice('عميل يناير');

      await invoices.addItem(
        invoiceKey: january.key,
        item: InvoiceItemModel(
          itemName: menuItem.displayName,
          price: menuItem.price,
        ),
      );

      final updatedMenuItem = await menu.updateItem(
        itemKey: menuItem.key,
        name: 'عدسة طبية',
        price: 150.0,
      );

      final march = await invoices.createInvoice('عميل مارس');

      await invoices.addItem(
        invoiceKey: march.key,
        item: InvoiceItemModel(
          itemName: updatedMenuItem!.displayName,
          price: updatedMenuItem.price,
        ),
      );

      final byTitle = {
        for (final invoice in invoices.getInvoices())
          invoice.title: invoice.total,
      };

      expect(byTitle['عميل يناير'], 100.0);
      expect(byTitle['عميل مارس'], 150.0);
    });

    test('a manual item behaves identically to a menu-backed one', () async {
      final invoices = InvoiceRepository();

      final invoice = await invoices.createInvoice('عميل');

      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(itemName: 'خدمة خاصة', price: 75.5),
      );

      final stored = invoices.getInvoices().single;

      expect(stored.items.single.itemName, 'خدمة خاصة');
      expect(stored.total, 75.5);
    });

    test('mixed manual and menu-backed items total together', () async {
      final menu = FixedMenuRepository();
      final invoices = InvoiceRepository();

      final menuItem = await menu.createItem(name: 'عدسة طبية', price: 100.0);

      final invoice = await invoices.createInvoice('عميل');

      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(
          itemName: menuItem.displayName,
          price: menuItem.price,
        ),
      );

      await invoices.addItem(
        invoiceKey: invoice.key,
        item: InvoiceItemModel(itemName: 'تلميع', price: 25.0),
      );

      final stored = invoices.getInvoices().single;

      expect(stored.items, hasLength(2));
      expect(stored.total, 125.0);
    });
  });
}
