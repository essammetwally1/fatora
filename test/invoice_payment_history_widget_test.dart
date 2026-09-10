import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/widgets/invoice/invoice_payment_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

InvoiceModel invoiceWith({
  required double paidAmount,
  List<InvoicePaymentEntryModel> payments = const [],
}) {
  final invoice = InvoiceModel(
    title: 'عميل',
    items: [InvoiceItemModel(itemName: 'عدسة', price: 500)],
    createdAt: DateTime(2026, 9, 10),
    payments: payments,
  );

  invoice.paidAmount = paidAmount;

  return invoice;
}

/// The widget reads the provider to know when a save is in flight and to run
/// its own deletes. Constructing one touches no storage — the repository only
/// reaches for a Hive box once a method is called — so the real provider can
/// stand in for the real thing here.
Future<void> pumpHistory(WidgetTester tester, InvoiceModel invoice) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<InvoiceProvider>(
      create: (_) => InvoiceProvider(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: InvoicePaymentHistory(invoice: invoice),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('stays out of the way on an unpaid invoice', (tester) async {
    await pumpHistory(tester, invoiceWith(paidAmount: 0));

    expect(find.byType(InvoicePaymentHistory), findsOneWidget);
    expect(find.textContaining('سجل الدفعات'), findsNothing);
  });

  testWidgets('counts the lines and starts collapsed', (tester) async {
    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 250,
        payments: [
          InvoicePaymentEntryModel(
            amount: 300,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
          InvoicePaymentEntryModel(
            amount: 50,
            isReturn: true,
            createdAt: DateTime(2026, 9, 11, 17, 40),
          ),
        ],
      ),
    );

    expect(find.text('سجل الدفعات والمرتجعات (2)'), findsOneWidget);
    expect(find.text('دفعة'), findsNothing);
  });

  testWidgets('expands to the dated entries, newest first', (tester) async {
    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 250,
        payments: [
          InvoicePaymentEntryModel(
            amount: 300,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
          InvoicePaymentEntryModel(
            amount: 50,
            isReturn: true,
            createdAt: DateTime(2026, 9, 11, 17, 40),
          ),
        ],
      ),
    );

    await tester.tap(find.text('سجل الدفعات والمرتجعات (2)'));
    await tester.pumpAndSettle();

    expect(find.text('دفعة'), findsOneWidget);
    expect(find.text('مرتجع'), findsOneWidget);

    // 12-hour clock with the Arabic marker, as asked for.
    expect(find.text('10/09/2026 - 09:15 ص'), findsOneWidget);
    expect(find.text('11/09/2026 - 05:40 م'), findsOneWidget);

    // A return reads as money going out.
    expect(find.text('- 50.00 ج.م'), findsOneWidget);
    expect(find.text('300.00 ج.م'), findsOneWidget);

    final returnRow = tester.getTopLeft(find.text('مرتجع'));
    final paymentRow = tester.getTopLeft(find.text('دفعة'));

    expect(returnRow.dy, lessThan(paymentRow.dy));
  });

  testWidgets('says plainly when a payment predates recorded times', (
    tester,
  ) async {
    await pumpHistory(tester, invoiceWith(paidAmount: 250));

    await tester.tap(find.text('سجل الدفعات والمرتجعات (1)'));
    await tester.pumpAndSettle();

    expect(find.text('دفعة مسجلة مسبقًا'), findsOneWidget);
    expect(find.text('بدون تاريخ مسجل'), findsOneWidget);
    expect(find.text('250.00 ج.م'), findsOneWidget);
  });

  testWidgets('a long history opens in full, inside the page scroll', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 500,
        payments: List.generate(
          40,
          (index) => InvoicePaymentEntryModel(
            amount: 12.5,
            createdAt: DateTime(2026, 9, 10, 8).add(Duration(hours: index)),
          ),
        ),
      ),
    );

    await tester.tap(find.text('سجل الدفعات والمرتجعات (40)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The log adds no scroll view of its own. It used to be capped and
    // scrollable, which trapped the finger inside the card once the whole
    // page started scrolling; it now lays out at full height and the page
    // scrolls it.
    expect(find.byType(Scrollable), findsOneWidget);

    // Every entry is really laid out, not clipped away by a height cap.
    final logHeight = tester.getSize(find.byType(InvoicePaymentHistory)).height;

    expect(logHeight, greaterThan(600));
  });

  testWidgets('offers the export switch as soon as there is a history', (
    tester,
  ) async {
    await pumpHistory(tester, invoiceWith(paidAmount: 250));

    // Reachable without expanding the log: hiding the breakdown is a decision
    // about the exported file, not about the log.
    expect(find.text('طباعة التفاصيل في PDF والصورة'), findsOneWidget);
    expect(find.text('الملف المصدَّر يعرض كل دفعة ومرتجع'), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));

    expect(switchWidget.value, isTrue);
  });

  testWidgets('the switch reads off on an invoice set to hide details', (
    tester,
  ) async {
    final invoice = invoiceWith(paidAmount: 250);

    invoice.hidePaymentDetailsInExport = true;

    await pumpHistory(tester, invoice);

    expect(find.text('الملف المصدَّر يعرض الإجمالي فقط'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a recorded entry can be deleted, an opening balance cannot', (
    tester,
  ) async {
    // 250 paid against one recorded payment of 100 leaves 150 that no entry
    // explains, so the log holds one deletable row and one that is derived.
    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 250,
        payments: [
          InvoicePaymentEntryModel(
            amount: 100,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
        ],
      ),
    );

    await tester.tap(find.text('سجل الدفعات والمرتجعات (2)'));
    await tester.pumpAndSettle();

    expect(find.text('دفعة'), findsOneWidget);
    expect(find.text('دفعة مسجلة مسبقًا'), findsOneWidget);

    // One delete button, and it belongs to the row backed by a stored entry.
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    final deleteY = tester
        .getCenter(find.byIcon(Icons.delete_outline_rounded))
        .dy;

    expect(deleteY, closeTo(tester.getCenter(find.text('دفعة')).dy, 12));
  });

  testWidgets('deleting asks first and says what it will cost', (tester) async {
    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 300,
        payments: [
          InvoicePaymentEntryModel(
            amount: 300,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
        ],
      ),
    );

    await tester.tap(find.text('سجل الدفعات والمرتجعات (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد حذف الدفعة'), findsOneWidget);

    // The consequence, not just the removal: what the paid total becomes.
    expect(
      find.textContaining('سيصبح إجمالي المدفوع 0.00 ج.م'),
      findsOneWidget,
    );

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد حذف الدفعة'), findsNothing);
  });

  testWidgets('survives a narrow viewport without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHistory(
      tester,
      invoiceWith(
        paidAmount: 250,
        payments: [
          InvoicePaymentEntryModel(
            amount: 250000,
            createdAt: DateTime(2026, 9, 10, 9, 15),
          ),
        ],
      ),
    );

    await tester.tap(find.textContaining('سجل الدفعات والمرتجعات'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
