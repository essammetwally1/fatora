import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/screens/invoice_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'support/hive_test_env.dart';

/// The payment card is not scrollable and sits directly above the items list,
/// so anything added to it can push the layout past the bottom of a small
/// screen. These tests open the real screen at real phone sizes and fail on any
/// overflow, including the ones Flutter only reports as a painted error stripe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = HiveTestEnv();

  late InvoiceProvider invoices;

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() async {
    await env.setUp();

    final invoice = InvoiceModel(
      title: 'عميل',
      items: List.generate(
        6,
        (index) => InvoiceItemModel(
          itemName: 'صنف رقم ${index + 1}',
          price: 100.0 + index,
        ),
      ),
      createdAt: DateTime(2026, 9, 10),
      payments: List.generate(
        12,
        (index) => InvoicePaymentEntryModel(
          amount: 20,
          isReturn: index.isOdd,
          createdAt: DateTime(2026, 9, 10, 8).add(Duration(hours: index)),
        ),
      ),
    );

    invoice.paidAmount = 120;

    await HiveService.getInvoiceBox().add(invoice);

    invoices = InvoiceProvider();

    await invoices.bootstrap();
  });

  tearDown(() => env.tearDown());

  Future<void> pumpDetails(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
          home: InvoiceDetailsScreen(
            invoice: invoices.invoices.single,
            onExport: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  // A small phone, a mainstream phone, and a tablet.
  const sizes = <String, Size>{
    'small phone': Size(320, 480),
    'phone': Size(390, 844),
    'tablet': Size(834, 1112),
  };

  for (final entry in sizes.entries) {
    testWidgets('lays out on a ${entry.key} with the log collapsed', (
      tester,
    ) async {
      await pumpDetails(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('سجل الدفعات والمرتجعات'), findsOneWidget);
    });

    testWidgets('lays out on a ${entry.key} with the log expanded', (
      tester,
    ) async {
      await pumpDetails(tester, entry.value);

      await tester.tap(find.textContaining('سجل الدفعات والمرتجعات'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The items list must keep a usable share of the screen.
      final listSize = tester.getSize(find.byType(ListView).last);

      expect(listSize.height, greaterThan(0));
    });
  }

  testWidgets('an oversized system font does not break the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            // The app clamps to 1.4; this is the worst case it allows.
            minScaleFactor: 1.4,
            maxScaleFactor: 1.4,
            child: child!,
          ),
          home: InvoiceDetailsScreen(
            invoice: invoices.invoices.single,
            onExport: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('سجل الدفعات والمرتجعات'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
