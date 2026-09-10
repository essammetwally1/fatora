import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/widgets/home/invoice_export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceModel _invoice({bool hideDetails = false}) {
  return InvoiceModel(
    title: 'أحمد محمود',
    items: [InvoiceItemModel(itemName: 'عدسة + إطار', price: 450)],
    createdAt: DateTime(2026, 9, 10),
    hidePaymentDetailsInExport: hideDetails,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size size,
  InvoiceExportFormat format = InvoiceExportFormat.pdf,
  double textScale = 1.0,
  bool hideDetails = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: Scaffold(
        body: InvoiceExportSheet(
          invoice: _invoice(hideDetails: hideDetails),
          format: format,
        ),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the PDF sheet offers only the PDF actions', (tester) async {
    await _pumpSheet(tester, size: const Size(390, 844));

    for (final title in ['معاينة PDF', 'حفظ على الجهاز', 'مشاركة / Export']) {
      expect(find.text(title), findsOneWidget, reason: 'missing "$title"');
    }

    // The header names the format, so which of the two sheets this is does not
    // have to be inferred from the action wording.
    expect(find.text('ملف PDF'), findsOneWidget);

    // Nothing about images: that is the other button's sheet.
    for (final title in ['معاينة الصورة', 'حفظ كصورة', 'مشاركة كصورة']) {
      expect(find.text(title), findsNothing, reason: 'stray "$title"');
    }
  });

  testWidgets('the image sheet offers only the image actions', (tester) async {
    await _pumpSheet(
      tester,
      size: const Size(390, 844),
      format: InvoiceExportFormat.image,
    );

    for (final title in ['معاينة الصورة', 'حفظ كصورة', 'مشاركة كصورة']) {
      expect(find.text(title), findsOneWidget, reason: 'missing "$title"');
    }

    expect(find.text('صورة الفاتورة'), findsOneWidget);

    for (final title in ['معاينة PDF', 'حفظ على الجهاز', 'مشاركة / Export']) {
      expect(find.text(title), findsNothing, reason: 'stray "$title"');
    }
  });

  for (final format in InvoiceExportFormat.values) {
    testWidgets('the ${format.name} sheet fits a small phone', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), format: format);

      expect(tester.takeException(), isNull);

      // The last action is reachable, by scrolling if it has to be.
      final lastAction = find.text(format.shareTitle);

      await tester.scrollUntilVisible(lastAction, 120);

      expect(lastAction, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the ${format.name} sheet survives the largest system font allowed',
      (tester) async {
        await _pumpSheet(
          tester,
          size: const Size(360, 640),
          format: format,
          textScale: 1.4,
        );

        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(find.text(format.shareTitle), 120);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the ${format.name} sheet warns when the details are hidden', (
      tester,
    ) async {
      await _pumpSheet(tester, size: const Size(390, 844), format: format);

      // Nothing to warn about by default.
      expect(find.textContaining('تفاصيل الدفعات مخفية'), findsNothing);

      await _pumpSheet(
        tester,
        size: const Size(390, 844),
        format: format,
        hideDetails: true,
      );

      expect(
        find.text('تفاصيل الدفعات مخفية في الملف المصدَّر — الإجمالي فقط'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
