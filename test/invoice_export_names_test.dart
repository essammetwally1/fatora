import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/files/invoice_file_names.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceModel _invoice({required String title, DateTime? createdAt}) {
  return InvoiceModel(
    title: title,
    items: [InvoiceItemModel(itemName: 'عدسة', price: 100)],
    createdAt: createdAt,
  );
}

void main() {
  group('the exported file name', () {
    test('carries the invoice date, not the export date', () {
      final name = InvoiceFileNames.baseName(
        _invoice(title: 'عميل يناير', createdAt: DateTime(2026, 1, 14)),
      );

      expect(name, contains('2026-01-14'));
    });

    test('marks an undated legacy invoice instead of borrowing today', () {
      final name = InvoiceFileNames.baseName(_invoice(title: 'قديمة'));

      expect(name, contains('legacy'));
      expect(name, isNot(contains(DateTime.now().year.toString())));
    });

    test('strips characters no file system accepts', () {
      final name = InvoiceFileNames.baseName(
        _invoice(title: r'أحمد/محمد: "الأول" *?<>|'),
      );

      for (final forbidden in [r'\', '/', ':', '*', '?', '"', '<', '>', '|']) {
        expect(name, isNot(contains(forbidden)));
      }
    });

    test('falls back to a name when the title is blank', () {
      expect(
        InvoiceFileNames.baseName(_invoice(title: '   ')),
        startsWith('invoice'),
      );
    });

    test('still ends in .pdf for the PDF export', () {
      final name = PdfService.fileNameForInvoice(
        _invoice(title: 'عميل', createdAt: DateTime(2026, 3, 2)),
      );

      expect(name, endsWith('.pdf'));
      expect(name, contains('2026-03-02'));
    });
  });

  group('image page names', () {
    test('a one-page invoice keeps a plain name', () {
      final name = InvoiceFileNames.imagePage(
        baseName: 'عميل-2026-01-14-1',
        pageNumber: 1,
        pageCount: 1,
      );

      expect(name, 'عميل-2026-01-14-1.png');
    });

    test('a multi-page invoice numbers every page in order', () {
      const baseName = 'عميل-2026-01-14-1';

      final names = [
        for (var page = 1; page <= 3; page++)
          InvoiceFileNames.imagePage(
            baseName: baseName,
            pageNumber: page,
            pageCount: 3,
          ),
      ];

      expect(names, ['$baseName-1.png', '$baseName-2.png', '$baseName-3.png']);

      // Every page of one export shares a stem, so they stay grouped and
      // sorted next to each other in the user's file manager.
      expect(names.toSet().length, names.length);
      expect(names.every((name) => name.startsWith(baseName)), isTrue);
    });
  });
}
