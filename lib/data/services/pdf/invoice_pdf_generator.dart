import 'dart:typed_data';

import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfGenerator {
  const InvoicePdfGenerator._();

  static Future<_InvoicePdfFonts>? _fontsFuture;

  static Future<Uint8List> build(InvoiceModel invoice) async {
    final fonts = await (_fontsFuture ??= _loadFonts());

    final document = pw.Document(compress: true);

    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      fontFallback: [fonts.regular, fonts.bold],
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(28),
          buildBackground: (_) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.grey50),
            );
          },
        ),
        header: (_) => _buildHeader(invoice),
        footer: (context) => _buildFooter(context),
        build: (_) {
          return [
            pw.SizedBox(height: 18),
            _buildItemsTable(invoice.items),
            pw.SizedBox(height: 16),
            _buildTotal(invoice.total),
          ];
        },
      ),
    );

    return document.save();
  }

  static Future<_InvoicePdfFonts> _loadFonts() async {
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');

    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');

    return _InvoicePdfFonts(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  static pw.Widget _buildHeader(InvoiceModel invoice) {
    final title = invoice.title.trim().isEmpty ? 'بدون عنوان' : invoice.title;

    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#128277'),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'فاتورة',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  title,
                  maxLines: 2,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              '${invoice.items.length} عنصر',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#128277'),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<InvoiceItemModel> items) {
    if (items.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: pw.Text(
          'لا توجد عناصر في هذه الفاتورة.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
        ),
      );
    }

    return pw.Container(
      decoration: _cardDecoration(),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.35),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(2),
          3: pw.FixedColumnWidth(34),
        },
        children: [
          _buildTableRow(const [
            'السعر',
            'اسم الصنف',
            'اسم العميل',
            '#',
          ], isHeader: true),
          for (var index = 0; index < items.length; index++)
            _buildTableRow([
              Formatters.formatMoney(items[index].price),
              items[index].displayItemName,
              items[index].displayCustomerName,
              '${index + 1}',
            ]),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableRow(
    List<String> cells, {
    bool isHeader = false,
  }) {
    final textStyle = pw.TextStyle(
      color: isHeader ? PdfColors.white : PdfColors.grey900,
      fontSize: isHeader ? 12 : 11,
      fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColor.fromHex('#128277') : PdfColors.white,
      ),
      children: [
        for (var index = 0; index < cells.length; index++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: pw.Text(
              cells[index],
              textAlign: index == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: textStyle,
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildTotal(double total) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#128277'),
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              Formatters.formatMoney(total),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'الإجمالي',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'صفحة ${context.pageNumber} من ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  static pw.BoxDecoration _cardDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(color: PdfColors.grey300),
    );
  }
}

class _InvoicePdfFonts {
  final pw.Font regular;
  final pw.Font bold;

  const _InvoicePdfFonts({required this.regular, required this.bold});
}
