import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_month_key.dart';
import 'package:fatora/data/models/invoice_month_snapshot.dart';
import 'package:fatora/data/models/invoices_totals.dart';
import 'package:fatora/widgets/home/month_history_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

InvoiceModel _invoice({
  required String title,
  required DateTime createdAt,
  double price = 500,
  double paid = 0,
  bool starred = false,
}) {
  final invoice = InvoiceModel(
    title: title,
    items: [InvoiceItemModel(itemName: 'عدسة', price: price)],
    createdAt: createdAt,
  );

  invoice.paidAmount = paid;
  invoice.isStarred = starred;

  return invoice;
}

InvoiceMonthSnapshot _month(DateTime date, List<InvoiceModel> invoices) {
  return InvoiceMonthSnapshot(
    month: InvoiceMonthKey.fromDate(date),
    invoices: List<InvoiceModel>.unmodifiable(invoices),
    totals: InvoicesTotals.fromInvoices(invoices),
    isCurrentMonth: false,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  /// Opens the drawer on a real Scaffold, so a tap that pops only closes the
  /// drawer — the way it behaves in the app.
  Future<InvoiceModel?> pumpDrawer(
    WidgetTester tester, {
    required List<InvoiceModel> starred,
    required List<InvoiceMonthSnapshot> months,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    InvoiceModel? opened;

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          key: scaffoldKey,
          drawer: MonthHistoryDrawer(
            months: months,
            selectedMonth: months.isEmpty
                ? InvoiceMonthKey.current()
                : months.first.month,
            onMonthSelected: (_) {},
            starredInvoices: starred,
            onInvoiceSelected: (invoice) => opened = invoice,
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();

    await tester.pumpAndSettle();

    return opened;
  }

  testWidgets('shows no starred section when nothing is starred', (
    tester,
  ) async {
    await pumpDrawer(
      tester,
      starred: const [],
      months: [
        _month(DateTime(2026, 9, 1), [
          _invoice(title: 'عميل', createdAt: DateTime(2026, 9, 3)),
        ]),
      ],
    );

    expect(find.textContaining('الفواتير المميزة'), findsNothing);

    // The months are still the drawer's main content.
    expect(find.textContaining('عدد الفواتير'), findsOneWidget);
  });

  testWidgets('lists starred invoices above the months', (tester) async {
    final starred = [
      _invoice(
        title: 'أحمد',
        createdAt: DateTime(2026, 9, 3),
        price: 500,
        paid: 200,
        starred: true,
      ),
      _invoice(
        title: 'منى',
        createdAt: DateTime(2026, 3, 3),
        price: 300,
        paid: 300,
        starred: true,
      ),
    ];

    await pumpDrawer(
      tester,
      starred: starred,
      months: [
        _month(DateTime(2026, 9, 1), [starred.first]),
        _month(DateTime(2026, 3, 1), [starred.last]),
      ],
    );

    expect(find.text('الفواتير المميزة (2)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('منى'), findsOneWidget);

    // Each tile says where the invoice stands, so the user can pick the right
    // one without opening all of them.
    expect(find.text('متبقي 300.00 ج.م'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);

    // Above the months, which is the point of pinning them.
    final starredY = tester.getTopLeft(find.text('أحمد')).dy;
    final monthsY = tester.getTopLeft(find.text('شهور الفواتير')).dy;

    expect(starredY, lessThan(monthsY));
  });

  testWidgets('tapping a starred invoice closes the drawer and opens it', (
    tester,
  ) async {
    final invoice = _invoice(
      title: 'أحمد',
      createdAt: DateTime(2026, 9, 3),
      starred: true,
    );

    InvoiceModel? opened;

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          key: scaffoldKey,
          drawer: MonthHistoryDrawer(
            months: [
              _month(DateTime(2026, 9, 1), [invoice]),
            ],
            selectedMonth: InvoiceMonthKey.fromDate(DateTime(2026, 9, 1)),
            onMonthSelected: (_) {},
            starredInvoices: [invoice],
            onInvoiceSelected: (selected) => opened = selected,
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('أحمد'));
    await tester.pumpAndSettle();

    expect(opened, same(invoice));

    // The drawer got out of the way rather than staying open behind the
    // invoice that was just opened.
    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('the starred section collapses so the months stay reachable', (
    tester,
  ) async {
    final starred = List.generate(
      12,
      (index) => _invoice(
        title: 'عميل $index',
        createdAt: DateTime(2026, 9, 3),
        starred: true,
      ),
    );

    await pumpDrawer(
      tester,
      starred: starred,
      months: [_month(DateTime(2026, 9, 1), starred)],
      size: const Size(320, 480),
    );

    expect(find.text('عميل 0'), findsOneWidget);

    await tester.tap(find.text('الفواتير المميزة (12)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('عميل 0'), findsNothing);

    // Collapsed, the month cards are right there.
    expect(find.textContaining('عدد الفواتير'), findsOneWidget);
  });
}
