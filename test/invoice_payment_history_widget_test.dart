import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/widgets/invoice/invoice_payment_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

Future<void> pumpHistory(WidgetTester tester, InvoiceModel invoice) async {
  await tester.pumpWidget(
    MaterialApp(
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

  testWidgets('a long history scrolls instead of growing without limit', (
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

    final listSize = tester.getSize(find.byType(ListView));

    expect(listSize.height, lessThanOrEqualTo(190));
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
