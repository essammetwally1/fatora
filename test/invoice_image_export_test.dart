import 'dart:typed_data';

import 'package:fatora/app/app_theme.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_entry_model.dart';
import 'package:fatora/data/services/pdf/invoice_image_exporter.dart';
import 'package:fatora/widgets/common/export_status_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

InvoiceModel _invoice() {
  return InvoiceModel(
    title: 'أحمد محمود',
    items: [
      InvoiceItemModel(itemName: 'عدسة + إطار', price: 450),
      InvoiceItemModel(itemName: 'محلول', price: 50),
    ],
    createdAt: DateTime(2026, 9, 10),
    payments: [
      InvoicePaymentEntryModel(
        amount: 200,
        createdAt: DateTime(2026, 9, 10, 11, 25),
      ),
    ],
  )..paidAmount = 200;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar');

    // Warms the generator's static font cache from a real async zone. Inside
    // `testWidgets` the fake clock never lets that file read finish.
    await InvoiceImageExporter.render(
      _invoice(),
    ).catchError((_) => const <InvoiceImagePage>[]);
  });

  group('rendering', () {
    test('refuses with a message the user can read when the platform cannot '
        'rasterise', () async {
      // No plugin implementation is registered in a unit test, which is the
      // same situation as a platform without a PDF rasteriser.
      await expectLater(
        InvoiceImageExporter.render(_invoice()),
        throwsA(
          isA<InvoiceImageExportException>().having(
            (error) => error.messageAr,
            'messageAr',
            contains('غير مدعوم'),
          ),
        ),
      );
    });

    test('sharing nothing is refused rather than opening an empty sheet', () {
      expect(
        () =>
            InvoiceImageExporter.shareAll(invoice: _invoice(), pages: const []),
        throwsA(isA<InvoiceImageExportException>()),
      );
    });
  });

  group('a rendered page', () {
    final page = InvoiceImagePage(
      pageNumber: 2,
      pageCount: 3,
      width: 1240,
      height: 1754,
      bytes: Uint8List(0),
    );

    test('reports the A4 aspect ratio it was rasterised at', () {
      expect(page.aspectRatio, closeTo(1240 / 1754, 0.0001));
    });

    test('names itself by page only when there is more than one', () {
      expect(page.labelAr, 'صفحة 2 من 3');

      final single = InvoiceImagePage(
        pageNumber: 1,
        pageCount: 1,
        width: 10,
        height: 10,
        bytes: Uint8List(0),
      );

      expect(single.labelAr, 'صورة الفاتورة');
    });

    test('never divides by a zero height', () {
      final empty = InvoiceImagePage(
        pageNumber: 1,
        pageCount: 1,
        width: 0,
        height: 0,
        bytes: Uint8List(0),
      );

      expect(empty.aspectRatio, 1);
    });
  });

  group('saving a multi-page export', () {
    test('reports the count when every page was written', () {
      const result = InvoiceImageSaveResult(
        savedPaths: ['a.png', 'b.png', 'c.png'],
        requestedCount: 3,
        wasCancelled: false,
      );

      expect(result.savedEverything, isTrue);
      expect(result.messageAr, contains('3'));
    });

    test('a single page is announced without a count', () {
      const result = InvoiceImageSaveResult(
        savedPaths: ['a.png'],
        requestedCount: 1,
        wasCancelled: false,
      );

      expect(result.messageAr, 'تم حفظ صورة الفاتورة');
    });

    test('cancelling before the first file is not reported as a save', () {
      const result = InvoiceImageSaveResult(
        savedPaths: [],
        requestedCount: 3,
        wasCancelled: true,
      );

      expect(result.savedNothing, isTrue);
      expect(result.messageAr, contains('إلغاء'));
      expect(result.messageAr, isNot(contains('تم حفظ')));
    });

    test(
      'stopping half way says how many were saved, never the whole invoice',
      () {
        const result = InvoiceImageSaveResult(
          savedPaths: ['a.png'],
          requestedCount: 3,
          wasCancelled: true,
        );

        expect(result.savedEverything, isFalse);
        expect(result.messageAr, contains('1'));
        expect(result.messageAr, contains('3'));
        expect(result.messageAr, contains('إلغاء'));
      },
    );

    test('saving nothing at all is refused before any dialog opens', () {
      expect(
        () =>
            InvoiceImageExporter.saveAll(invoice: _invoice(), pages: const []),
        throwsA(isA<InvoiceImageExportException>()),
      );
    });
  });

  testWidgets('a failed export offers the message and a way to retry', (
    tester,
  ) async {
    // The screen itself cannot be pumped here: building the PDF reads font
    // files, and `testWidgets`' fake clock never lets real file I/O finish.
    // The failure surface it shows is what matters, so that is what is tested.
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ExportErrorView(
            icon: Icons.image_not_supported_outlined,
            message: 'تعذر تحويل الفاتورة إلى صورة',
            details: 'تحويل الفاتورة إلى صورة غير مدعوم على هذا الجهاز',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.textContaining('غير مدعوم'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('the error card survives a tiny screen and a huge font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.4,
          maxScaleFactor: 1.4,
          child: child!,
        ),
        home: const Scaffold(
          body: ExportErrorView(
            icon: Icons.image_not_supported_outlined,
            message: 'تعذر تحويل الفاتورة إلى صورة',
            details:
                'الفاتورة أطول من 40 صفحة، استخدم تصدير PDF بدلاً من الصور',
            onRetry: _noop,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
