import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/widgets/home/invoice_card.dart';
import 'package:fatora/widgets/invoice/invoice_star_button.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The card carries a title, a status chip, three action buttons, a total and a
/// star, inside a row that is only as wide as the phone. These tests build it at
/// the tightest sizes it has to survive and fail on any overflow.
void main() {
  InvoiceModel invoice({
    String title = 'عميل',
    double price = 500,
    double paid = 0,
    bool starred = false,
  }) {
    final model = InvoiceModel(
      title: title,
      items: [InvoiceItemModel(itemName: 'عدسة', price: price)],
      createdAt: DateTime(2026, 9, 10),
    );

    model.paidAmount = paid;
    model.isStarred = starred;

    return model;
  }

  Future<void> pumpCard(
    WidgetTester tester,
    InvoiceModel model, {
    Size size = const Size(320, 480),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<InvoiceProvider>(
        create: (_) => InvoiceProvider(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: textScale,
              maxScaleFactor: textScale,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: InvoiceCard(
                    invoice: model,
                    onTap: () {},
                    onLongPress: () {},
                    onEdit: () {},
                    onExportPdf: () {},
                    onExportImage: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('fits a narrow phone with a long name', (tester) async {
    await pumpCard(
      tester,
      invoice(
        title: 'عميل باسم طويل جدًا لا ينتهي أبدًا مهما طال الزمن',
        price: 123456,
        paid: 1000,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(InvoiceStarButton), findsOneWidget);

    // Each format has its own button on the card, so neither export is buried
    // behind the other.
    expect(find.byType(PdfActionButton), findsOneWidget);
    expect(find.byType(ImageActionButton), findsOneWidget);
  });

  testWidgets('fits a narrow phone at the largest allowed font', (
    tester,
  ) async {
    await pumpCard(
      tester,
      invoice(title: 'عميل باسم طويل جدًا', price: 123456, paid: 1000),
      textScale: 1.4,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the star reflects the stored mark', (tester) async {
    await pumpCard(tester, invoice(starred: true));

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);

    await pumpCard(tester, invoice());

    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });
}
