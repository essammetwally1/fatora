import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/services/storage/hive_service.dart';
import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/screens/invoice_details_screen.dart';
import 'package:fatora/widgets/invoice/invoice_star_button.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'support/hive_test_env.dart';

/// The payment card and the items list share one scroll view, so anything added
/// to the card lengthens the page rather than squeezing the list. These tests
/// open the real screen at real phone sizes and fail on any overflow, including
/// the ones Flutter only reports as a painted error stripe.
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

  Future<void> pumpDetails(
    WidgetTester tester,
    Size size, {
    InvoiceModel? invoice,
  }) async {
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
            invoice: invoice ?? invoices.invoices.single,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  /// Re-pumps the same screen with the stored invoice already starred.
  ///
  /// The flag is set on the stored record and reloaded, so the screen reads it
  /// the way it would after a real toggle, without a write that the fake clock
  /// cannot finish.
  Future<void> pumpStarredDetails(WidgetTester tester, Size size) async {
    invoices.invoices.single.isStarred = true;

    invoices.loadInvoices(notify: false);

    await pumpDetails(tester, size);
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

      // Both export formats and the star are offered from the header, and the
      // three buttons plus the title still fit the app bar.
      expect(find.byType(PdfActionButton), findsOneWidget);
      expect(find.byType(ImageActionButton), findsOneWidget);
      expect(find.byType(InvoiceStarButton), findsOneWidget);

      // The switch that keeps the breakdown off the export sits with the log,
      // reachable without expanding it.
      expect(find.text('طباعة التفاصيل في PDF والصورة'), findsOneWidget);
    });

    testWidgets('the header star shows whether the invoice is marked', (
      tester,
    ) async {
      await pumpDetails(tester, entry.value);

      // Unstarred to begin with: a hollow star, and nothing in the drawer's
      // starred section.
      expect(invoices.starredInvoices, isEmpty);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);

      // Tapping it is not exercised here: the write goes to Hive, and a real
      // file write started inside `testWidgets` never completes in its fake
      // clock — it hangs the run. `invoice_export_options_test.dart` covers
      // the write itself against real storage.
      await pumpStarredDetails(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    });

    testWidgets('lays out on a ${entry.key} with the log expanded', (
      tester,
    ) async {
      await pumpDetails(tester, entry.value);

      final toggle = find.textContaining('سجل الدفعات والمرتجعات');

      // On a small phone the toggle starts below the fold. Tapping blind there
      // silently hits whatever is drawn at that spot instead, so the test would
      // pass without ever expanding the log.
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The log really opened, rather than the tap landing elsewhere.
      expect(find.text('مرتجع'), findsWidgets);

      // The page scrolls as one: dragging the page's own scroll view reaches
      // the last invoice item, past the whole expanded log, so the card and
      // the items are not two scroll regions competing for the same finger.
      await tester.dragUntilVisible(
        find.text('صنف رقم 6'),
        find.byType(CustomScrollView),
        const Offset(0, -160),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('صنف رقم 6'), findsOneWidget);
    });
  }

  // A brand new invoice opens here with nothing in it, and the placeholder is
  // a sliver now rather than the body of the screen — a different layout path,
  // and one that can fail on its own.
  //
  // The model is never stored: an unsaved invoice has no key, the screen falls
  // back to the one it was handed, and no Hive write is started inside the
  // widget zone (see the note on the star test above).
  for (final entry in sizes.entries) {
    testWidgets('an invoice with no items lays out on a ${entry.key}', (
      tester,
    ) async {
      await pumpDetails(
        tester,
        entry.value,
        invoice: InvoiceModel(
          title: 'فاتورة فارغة',
          items: const [],
          createdAt: DateTime(2026, 9, 10),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('لا توجد عناصر بعد'), findsOneWidget);
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
          home: InvoiceDetailsScreen(invoice: invoices.invoices.single),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final toggle = find.textContaining('سجل الدفعات والمرتجعات');

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('مرتجع'), findsWidgets);
  });
}
