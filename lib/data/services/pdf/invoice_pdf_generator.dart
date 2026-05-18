import 'dart:typed_data';

import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfGenerator {
  const InvoicePdfGenerator._();

  static final PdfColor _navy = PdfColor.fromHex('#061E3A');
  static final PdfColor _gold = PdfColor.fromHex('#B98A35');
  static final PdfColor _softGold = PdfColor.fromHex('#F5E9CF');
  static final PdfColor _cream = PdfColor.fromHex('#FFFDF7');
  static final PdfColor _white = PdfColors.white;
  static final PdfColor _text = PdfColor.fromHex('#142238');
  static final PdfColor _muted = PdfColor.fromHex('#667085');
  static final PdfColor _line = PdfColor.fromHex('#D8B56A');
  static final PdfColor _softRow = PdfColor.fromHex('#FBF6EA');

  static const PdfColor _bgGold = PdfColor(0.72, 0.54, 0.21, 0.10);
  static const PdfColor _bgNavy = PdfColor(0.02, 0.12, 0.23, 0.06);

  static Future<_InvoicePdfAssets>? _assetsFuture;

  static Future<Uint8List> build(InvoiceModel invoice) async {
    final assets = await (_assetsFuture ??= _loadAssets());

    final logo = assets.logoBytes == null
        ? null
        : pw.MemoryImage(assets.logoBytes!);

    final document = pw.Document(compress: true);

    final theme = pw.ThemeData.withFont(
      base: assets.regular,
      bold: assets.bold,
      fontFallback: [assets.regular, assets.bold],
    );

    document.addPage(
      pw.MultiPage(
        maxPages: 300,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 90),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          buildBackground: (_) => _buildBackground(),
        ),
        footer: (context) => _buildRepeatedFooter(context, logo),
        build: (_) => [
          _pageFrame(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildTopBrand(logo),
                pw.SizedBox(height: 8),
                _buildInvoiceInfoBox(invoice),
                pw.SizedBox(height: 9),
                ..._buildItemsSection(invoice.items, invoice.total),
              ],
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<_InvoicePdfAssets> _loadAssets() async {
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');

    Uint8List? logoBytes;

    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    return _InvoicePdfAssets(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      logoBytes: logoBytes,
    );
  }

  static pw.Widget _buildBackground() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Container(color: _cream),
          pw.Positioned(
            top: -74,
            right: -76,
            child: pw.Container(
              width: 178,
              height: 178,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: _bgGold,
              ),
            ),
          ),
          pw.Positioned(
            bottom: -84,
            left: -78,
            child: pw.Container(
              width: 196,
              height: 196,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: _bgNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pageFrame({required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 1, 1, 0.74),
        border: pw.Border.all(color: _line, width: .85),
      ),
      child: child,
    );
  }

  static pw.Widget _buildTopBrand(pw.ImageProvider? logo) {
    return pw.Container(
      height: 145,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _line, width: .85),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(top: 0, right: 0, child: _cornerBlock(isRight: true)),
          pw.Positioned(top: 0, left: 0, child: _cornerBlock(isRight: false)),
          pw.Center(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _logoBox(logo, size: 112),
                pw.SizedBox(width: 14),
                pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Mostafa Saad Optics Lab',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: .8,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        _smallLine(48),
                        pw.SizedBox(width: 7),
                        _diamond(6),
                        pw.SizedBox(width: 7),
                        _smallLine(48),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'معمل مصطفى سعد للبصريات',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _navy,
                        fontSize: 14.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'عدسات ونظارات طبية',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _gold,
                        fontSize: 8.4,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cornerBlock({required bool isRight}) {
    return pw.Container(
      width: 34,
      height: 34,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: isRight
            ? const pw.BorderRadius.only(
                topRight: pw.Radius.circular(13),
                bottomLeft: pw.Radius.circular(13),
              )
            : const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(13),
                bottomRight: pw.Radius.circular(13),
              ),
      ),
    );
  }

  static pw.Widget _logoBox(pw.ImageProvider? logo, {required double size}) {
    return pw.Container(
      width: size,
      height: size,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: _white,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: _gold, width: 1.65),
      ),
      child: logo == null
          ? pw.Center(
              child: pw.Text(
                'MS',
                style: pw.TextStyle(
                  color: _navy,
                  fontSize: size * .28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            )
          : pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  static pw.Widget _buildInvoiceInfoBox(InvoiceModel invoice) {
    final title = invoice.title.trim().isEmpty
        ? 'عميل غير معروف'
        : invoice.title.trim();

    final date = Formatters.formatDate(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _softGold,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _line, width: .65),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 88,
            height: 44,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'فاتورة',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'INVOICE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _gold,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              children: [
                _infoRow(label: 'اسم العميل', value: title),
                pw.SizedBox(height: 3),
                _infoRow(label: 'التاريخ', value: date),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow({required String label, required String value}) {
    return pw.Container(
      height: 18,
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 1, 1, .56),
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(
          color: const PdfColor(.84, .71, .42, .38),
          width: .35,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 72,
            alignment: pw.Alignment.center,
            child: pw.Text(
              label,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: 8.4,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Container(width: .55, height: 13, color: _gold),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text(
                value,
                maxLines: 1,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: _text,
                  fontSize: 8.4,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildItemsSection(
    List<InvoiceItemModel> items,
    double total,
  ) {
    return [
      _tableHeader(),
      if (items.isEmpty)
        _emptyItemsRow()
      else
        for (int i = 0; i < items.length; i++) _itemRow(items[i], i),
      _totalRow(total),
    ];
  }

  static pw.Widget _tableHeader() {
    return pw.Container(
      height: 28,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .65),
      ),
      child: pw.Row(
        children: [
          _tableText('م', width: 38, color: _white, bold: true, center: true),
          _tableDivider(color: _line, height: 28),
          pw.Expanded(
            flex: 5,
            child: _tableText(
              'اسم الصنف',
              color: _white,
              bold: true,
              center: true,
            ),
          ),
          _tableDivider(color: _line, height: 28),
          pw.Expanded(
            flex: 2,
            child: _tableText('السعر', color: _white, bold: true, center: true),
          ),
        ],
      ),
    );
  }

  static pw.Widget _emptyItemsRow() {
    return pw.Container(
      height: 34,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border(
          left: pw.BorderSide(color: _line, width: .5),
          right: pw.BorderSide(color: _line, width: .5),
          bottom: pw.BorderSide(color: _line, width: .5),
        ),
      ),
      child: pw.Text(
        'لا توجد عناصر داخل هذه الفاتورة.',
        style: pw.TextStyle(
          color: _muted,
          fontSize: 8.8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _itemRow(InvoiceItemModel item, int index) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 30),
      decoration: pw.BoxDecoration(
        color: index.isEven ? _white : _softRow,
        border: pw.Border(
          left: pw.BorderSide(color: _line, width: .5),
          right: pw.BorderSide(color: _line, width: .5),
          bottom: pw.BorderSide(color: _line, width: .38),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _tableText(
            '${index + 1}',
            width: 38,
            color: _navy,
            bold: true,
            center: true,
          ),
          _tableDivider(height: 32),
          pw.Expanded(
            flex: 5,
            child: _tableText(
              item.displayItemName,
              color: _text,
              maxLines: 2,
              center: true,
            ),
          ),
          _tableDivider(height: 32),
          pw.Expanded(
            flex: 2,
            child: _tableText(
              Formatters.formatMoney(item.price),
              color: _navy,
              bold: true,
              center: true,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(double total) {
    return pw.Container(
      height: 38,
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: const pw.BorderRadius.vertical(
          bottom: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .75),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              height: 38,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _gold,
                borderRadius: const pw.BorderRadius.only(
                  bottomRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Text(
                'الإجمالي',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Container(width: .8, height: 38, color: _line),
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              height: 38,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: const pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(8),
                ),
              ),
              child: pw.Text(
                Formatters.formatMoney(total),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 12.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableText(
    String text, {
    double? width,
    required PdfColor color,
    bool bold = false,
    bool center = false,
    int maxLines = 1,
  }) {
    final child = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerRight,
      child: pw.Text(
        text,
        maxLines: maxLines,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        style: pw.TextStyle(
          color: color,
          fontSize: 8.9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    if (width == null) return child;

    return pw.SizedBox(width: width, child: child);
  }

  static pw.Widget _tableDivider({PdfColor? color, double height = 32}) {
    return pw.Container(width: .5, height: height, color: color ?? _line);
  }

  static pw.Widget _buildRepeatedFooter(
    pw.Context context,
    pw.ImageProvider? logo,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 7),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _line, width: .75),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: pw.BoxDecoration(
              color: _softGold,
              borderRadius: pw.BorderRadius.circular(13),
              border: pw.Border.all(
                color: const PdfColor(.84, .71, .42, .45),
                width: .45,
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _footerBrand(logo),
                pw.SizedBox(width: 10),
                pw.Container(width: .65, height: 38, color: _gold),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _footerDataFrame(
                        text: '01210568226 - 01098279207',
                        iconText: '☎',
                      ),
                      pw.SizedBox(height: 4),
                      _footerDataFrame(
                        text:
                            'المحله الكبرى - ميدان الشون - أمام مدرسة طه حسين',
                        iconText: '⌖',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _muted,
              fontSize: 6.7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footerBrand(pw.ImageProvider? logo) {
    return pw.Row(
      children: [
        _logoBox(logo, size: 34),
        pw.SizedBox(width: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'مصطفى سعد',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: 9.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'MOSTAFA SAAD',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _gold,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footerDataFrame({
    required String text,
    required String iconText,
  }) {
    return pw.Container(
      height: 18,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(9),
        border: pw.Border.all(
          color: const PdfColor(.84, .71, .42, .48),
          width: .45,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 15,
            height: 15,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Text(
              iconText,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _gold,
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: 7.9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _smallLine(double width) {
    return pw.Container(width: width, height: .75, color: _gold);
  }

  static pw.Widget _diamond(double size) {
    return pw.Transform.rotate(
      angle: 0.785398,
      child: pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _gold, width: .75),
        ),
      ),
    );
  }
}

class _InvoicePdfAssets {
  final pw.Font regular;
  final pw.Font bold;
  final Uint8List? logoBytes;

  const _InvoicePdfAssets({
    required this.regular,
    required this.bold,
    required this.logoBytes,
  });
}
