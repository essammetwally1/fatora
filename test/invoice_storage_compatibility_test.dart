import 'dart:io';

import 'package:fatora/data/models/fixed_menu_item_model.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/repositories/invoice_repository.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The `InvoiceModel` adapter exactly as it was shipped before payment history
/// existed: four fields, no `payments`.
///
/// Every invoice already on a customer's phone is stored in this layout. This
/// test writes real bytes with it and then reads them back with the current
/// adapter, which is the only way to prove the upgrade cannot lose or corrupt
/// data that is already out there.
class _PreHistoryInvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 1;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return InvoiceModel(
      title: fields[0] as String,
      items: (fields[1] as List).cast<InvoiceItemModel>(),
      paidAmount: fields[2] == null ? 0.0 : fields[2] as double,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.paidAmount)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}

/// The `InvoiceModel` adapter as shipped with payment history but before the
/// export and star flags: five fields, no `hidePaymentDetailsInExport`, no
/// `isStarred`.
class _PreFlagsInvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 1;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return InvoiceModel(
      title: fields[0] as String,
      items: (fields[1] as List).cast<InvoiceItemModel>(),
      paidAmount: fields[2] == null ? 0.0 : fields[2] as double,
      createdAt: fields[3] as DateTime?,
      payments: fields[4] == null
          ? []
          : (fields[4] as List?)?.cast<InvoicePaymentEntryModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.paidAmount)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.payments);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fatora_compat_');

    Hive.init(directory.path);

    Hive.registerAdapter(InvoiceItemModelAdapter(), override: true);
    Hive.registerAdapter(FixedMenuItemModelAdapter(), override: true);
    Hive.registerAdapter(InvoicePaymentEntryModelAdapter(), override: true);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveService.invoiceBox);
    await Hive.close();

    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('invoices written by the previous release still open', () async {
    // Write with the shipped adapter, the way the customer's phone already
    // wrote them.
    Hive.registerAdapter(_PreHistoryInvoiceModelAdapter(), override: true);

    final box = await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

    final key = await box.add(
      InvoiceModel(
        title: 'عميل قديم',
        items: [
          InvoiceItemModel(itemName: 'عدسة', price: 250),
          InvoiceItemModel(itemName: 'إطار', price: 150),
        ],
        paidAmount: 250,
        createdAt: DateTime(2026, 3, 4, 10, 30),
      ),
    );

    await box.close();

    // Upgrade: the new build reads the very same bytes.
    Hive.registerAdapter(InvoiceModelAdapter(), override: true);

    await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

    final loaded = InvoiceRepository().getInvoices().single;

    expect(loaded.title, 'عميل قديم');
    expect(loaded.total, 400.0);
    expect(loaded.paidTotal, 250.0);
    expect(loaded.createdAt, DateTime(2026, 3, 4, 10, 30));

    // The missing field must arrive as an empty list, never as null.
    expect(loaded.payments, isEmpty);
    expect(loaded.hasPaymentHistory, isFalse);

    // And the money that has no entry behind it is reported, not lost.
    expect(loaded.unrecordedPaidAmount, 250.0);

    // A payment recorded after the upgrade lands alongside it.
    final updated = await InvoiceRepository().applyPaidDelta(
      invoiceKey: key,
      deltaAmount: 150,
    );

    expect(updated!.paidTotal, 400.0);
    expect(updated.payments, hasLength(1));
    expect(updated.unrecordedPaidAmount, 250.0);
  });

  test('startup migration leaves an untouched old invoice alone', () async {
    Hive.registerAdapter(_PreHistoryInvoiceModelAdapter(), override: true);

    final box = await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

    await box.add(
      InvoiceModel(
        title: 'عميل قديم',
        items: [InvoiceItemModel(itemName: 'عدسة', price: 250)],
        paidAmount: 100,
        createdAt: DateTime(2026, 3, 4),
      ),
    );

    await box.close();

    Hive.registerAdapter(InvoiceModelAdapter(), override: true);

    await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

    final repository = InvoiceRepository();

    await repository.migrateStoredInvoices();
    await repository.migrateStoredInvoices();

    final migrated = repository.getInvoices().single;

    expect(migrated.paidTotal, 100.0);
    expect(migrated.payments, isEmpty);
    expect(migrated.items.single.id.trim(), isNotEmpty);
  });

  test(
    'invoices written before the export flags existed open unchanged',
    () async {
      Hive.registerAdapter(_PreFlagsInvoiceModelAdapter(), override: true);

      final box = await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

      final key = await box.add(
        InvoiceModel(
          title: 'عميل',
          items: [InvoiceItemModel(itemName: 'عدسة', price: 400)],
          paidAmount: 250,
          createdAt: DateTime(2026, 3, 4, 10, 30),
          payments: [
            InvoicePaymentEntryModel(
              amount: 250,
              createdAt: DateTime(2026, 3, 4, 11),
            ),
          ],
        ),
      );

      await box.close();

      Hive.registerAdapter(InvoiceModelAdapter(), override: true);

      await Hive.openBox<InvoiceModel>(HiveService.invoiceBox);

      final repository = InvoiceRepository();

      final loaded = repository.getInvoices().single;

      // Everything that was there is still there.
      expect(loaded.title, 'عميل');
      expect(loaded.paidTotal, 250.0);
      expect(loaded.payments, hasLength(1));

      // And the two fields that were not written default to the behaviour this
      // invoice already had: its breakdown still prints, and it is not starred.
      expect(loaded.hidePaymentDetailsInExport, isFalse);
      expect(loaded.printsPaymentDetails, isTrue);
      expect(loaded.isStarred, isFalse);

      // Setting one and reading it back proves the new fields round-trip
      // through the same record.
      await repository.setStarred(invoiceKey: key, starred: true);
      await repository.setPaymentDetailsHiddenInExport(
        invoiceKey: key,
        hidden: true,
      );

      final updated = repository.getInvoices().single;

      expect(updated.isStarred, isTrue);
      expect(updated.hidePaymentDetailsInExport, isTrue);
      expect(updated.payments, hasLength(1));
      expect(updated.paidTotal, 250.0);
    },
  );
}
