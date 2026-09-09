import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/fixed_menu_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/widgets/invoice/invoice_item_sheet.dart';
import 'package:fatora/widgets/menu/fixed_menu_quick_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'support/hive_test_env.dart';

/// The composed name and price fields, read straight out of the open sheet.
///
/// The sheet lays out name, price and note in that order.
({String name, String price}) sheetFields(WidgetTester tester) {
  final fields = tester
      .widgetList<TextFormField>(find.byType(TextFormField))
      .toList(growable: false);

  expect(fields, hasLength(3));

  return (
    name: fields[0].controller?.text ?? '',
    price: fields[1].controller?.text ?? '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = HiveTestEnv();

  late InvoiceProvider invoices;
  late InvoiceModel invoice;

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  // Storage work lives here on purpose. Hive writes to a real file, and inside
  // a `testWidgets` body the fake-async zone never lets that I/O complete, so
  // the test would hang rather than fail.
  setUp(() async {
    await env.setUp();

    await HiveService.getFixedMenuBox().addAll([
      FixedMenuItemModel(name: 'عدسة', price: 10),
      FixedMenuItemModel(name: 'إطار', price: 20),
      // Deliberately not a round number: the composed total must stay exact.
      FixedMenuItemModel(name: 'غطاء', price: 15.55),
    ]);

    invoices = InvoiceProvider();

    await invoices.bootstrap();
    await invoices.createInvoice('عميل');

    invoice = invoices.invoices.single;
  });

  tearDown(() => env.tearDown());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InvoiceProvider>.value(value: invoices),
          ChangeNotifierProvider<FixedMenuProvider>(
            create: (_) => FixedMenuProvider()..loadMenu(notify: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showInvoiceItemSheet(context, invoice: invoice),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Taps a row inside the picker.
  ///
  /// Scoped to the picker because a picked name also shows up in the name
  /// field and in the selection summary, so a bare `find.text` matches three
  /// widgets once anything is selected.
  Future<void> pick(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(FixedMenuQuickPicker),
        matching: find.text(name),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('picking two menu items composes one line at the sum', (
    tester,
  ) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'إطار');

    final fields = sheetFields(tester);

    expect(fields.name, 'عدسة + إطار');
    expect(fields.price, '30');
  });

  testWidgets('a third pick extends the name and the total', (tester) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'إطار');
    await pick(tester, 'غطاء');

    final fields = sheetFields(tester);

    expect(fields.name, 'عدسة + إطار + غطاء');
    expect(fields.price, '45.55');
  });

  testWidgets('the composed name follows the order they were picked', (
    tester,
  ) async {
    await openSheet(tester);

    await pick(tester, 'غطاء');
    await pick(tester, 'عدسة');

    expect(sheetFields(tester).name, 'غطاء + عدسة');
  });

  testWidgets('tapping a picked item again removes it from the line', (
    tester,
  ) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'إطار');
    await pick(tester, 'عدسة');

    final fields = sheetFields(tester);

    expect(fields.name, 'إطار');
    expect(fields.price, '20');
  });

  testWidgets('clearing the last pick empties the form again', (tester) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'عدسة');

    final fields = sheetFields(tester);

    expect(fields.name, '');
    expect(fields.price, '');
  });

  testWidgets('the clear button drops the whole selection', (tester) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'إطار');

    expect(find.text('تم اختيار 2 من القائمة'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'مسح'));
    await tester.pumpAndSettle();

    final fields = sheetFields(tester);

    expect(fields.name, '');
    expect(fields.price, '');
    expect(find.widgetWithText(TextButton, 'مسح'), findsNothing);
  });

  testWidgets('the summary shows the composed name and the running total', (
    tester,
  ) async {
    await openSheet(tester);

    await pick(tester, 'عدسة');
    await pick(tester, 'إطار');

    expect(find.text('مجموع 2 أصناف من القائمة'), findsOneWidget);
    expect(find.text('30.00 ج.م'), findsWidgets);
  });
}
