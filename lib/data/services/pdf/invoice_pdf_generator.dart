import 'dart:typed_data';

import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/invoice_item_model.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/models/invoice_payment_line.dart';
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
  static final PdfColor _paymentGreen = PdfColor.fromHex('#1B6B3A');
  static final PdfColor _returnRed = PdfColor.fromHex('#A02525');

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
          margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 72),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          buildBackground: (_) => _buildBackground(),
        ),
        footer: (context) => _buildRepeatedFooter(context, logo, assets),
        build: (_) => [
          _pageFrame(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildTopBrand(logo),
                pw.SizedBox(height: 8),
                _buildInvoiceInfoBox(invoice),
                pw.SizedBox(height: 9),
                ..._buildItemsSection(invoice),
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
    String? phoneSvg;
    String? locationSvg;

    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    try {
      final rawPhoneSvg = await rootBundle.loadString('assets/icons/phone.svg');
      phoneSvg = _svgToWhite(rawPhoneSvg);
    } catch (_) {
      phoneSvg = null;
    }

    try {
      final rawLocationSvg = await rootBundle.loadString(
        'assets/icons/location.svg',
      );
      locationSvg = _svgToWhite(rawLocationSvg);
    } catch (_) {
      locationSvg = null;
    }

    return _InvoicePdfAssets(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      logoBytes: logoBytes,
      phoneSvg: phoneSvg,
      locationSvg: locationSvg,
    );
  }

  static String _svgToWhite(String svg) {
    return svg
        .replaceAll(RegExp(r'fill="(?!none)[^"]*"'), 'fill="#FFFFFF"')
        .replaceAll(RegExp(r"fill='(?!none)[^']*'"), "fill='#FFFFFF'")
        .replaceAll(RegExp(r'stroke="[^"]*"'), 'stroke="#FFFFFF"')
        .replaceAll(RegExp(r"stroke='[^']*'"), "stroke='#FFFFFF'")
        .replaceAll('currentColor', '#FFFFFF');
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
      height: 118,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _line, width: .85),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            bottom: -46,
            right: -30,
            child: pw.Container(
              width: 110,
              height: 110,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColor(.72, .54, .21, .12),
              ),
            ),
          ),
          pw.Positioned(
            left: 28,
            right: 128,
            bottom: 7,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 42,
                  height: .75,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(1, 1, 1, .35),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Transform.rotate(
                  angle: 0.785398,
                  child: pw.Container(
                    width: 5,
                    height: 5,
                    decoration: pw.BoxDecoration(
                      color: _gold,
                      border: pw.Border.all(color: _gold, width: .6),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  width: 42,
                  height: .75,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(1, 1, 1, .35),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _modernLogoSquare(logo),
              pw.SizedBox(width: 14),
              pw.Container(
                width: .8,
                height: 72,
                color: const PdfColor(1, 1, 1, .22),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(child: _simpleCenteredBrandName()),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _simpleCenteredBrandName() {
    return pw.Container(
      height: 86,
      width: double.infinity,
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'معمل',
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              color: _gold,
              fontSize: 15.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              'مصطفى سعد',
              maxLines: 1,
              softWrap: false,
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                color: _white,
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'للبصريات',
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              color: _gold,
              fontSize: 15.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Container(
              width: 132,
              height: 1.1,
              decoration: pw.BoxDecoration(
                color: _gold,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _modernLogoSquare(pw.ImageProvider? logo) {
    return pw.Container(
      width: 82,
      height: 82,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _gold, width: 1.25),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(
          color: _white,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(
            color: const PdfColor(.02, .12, .23, .10),
            width: .5,
          ),
        ),
        child: logo == null
            ? pw.Center(
                child: pw.Text(
                  'MS',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            : pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
      ),
    );
  }

  static pw.Widget _buildInvoiceInfoBox(InvoiceModel invoice) {
    final title = invoice.title.trim().isEmpty
        ? 'عميل غير معروف'
        : invoice.title.trim();

    // The invoice's own date, never the clock.
    final date = Formatters.formatInvoiceDocumentDate(invoice.createdAt);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _softGold,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _line, width: .65),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 92,
            height: 52,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              'فاتورة',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              children: [
                _infoRow(label: 'اسم العميل', value: title),
                pw.SizedBox(height: 4),
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
      height: 22,
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 1, 1, .56),
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(
          color: const PdfColor(.84, .71, .42, .38),
          width: .35,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 78,
            alignment: pw.Alignment.center,
            child: pw.Text(
              label,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: 10.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Container(width: .55, height: 16, color: _gold),
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
                  fontSize: 10.6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildItemsSection(InvoiceModel invoice) {
    return [
      _tableHeader(),
      if (invoice.items.isEmpty)
        _emptyItemsRow()
      else
        for (int i = 0; i < invoice.items.length; i++)
          _itemRow(invoice.items[i], i),
      _totalAndPaymentSummary(invoice),
      ..._buildPaymentBreakdown(invoice),
    ];
  }

  /// The dated breakdown printed under "المبلغ المدفوع".
  ///
  /// Split into payments and returns so a customer can see what they handed
  /// over and what came back, rather than only the net figure. Omitted
  /// entirely when nothing has been paid: an all-zero block on an unpaid
  /// invoice is noise.
  static List<pw.Widget> _buildPaymentBreakdown(InvoiceModel invoice) {
    final rows = InvoicePaymentLine.fromInvoice(invoice);

    if (rows.isEmpty) return const [];

    final payments = rows.where((row) => !row.isReturn).toList(growable: false);
    final returns = rows.where((row) => row.isReturn).toList(growable: false);

    var lineIndex = 0;

    return [
      pw.SizedBox(height: 9),
      _paymentSectionHeader(),
      if (payments.isNotEmpty) ...[
        _paymentGroupHeader(
          label: 'المدفوعات',
          color: _paymentGreen,
          amount: InvoicePaymentLine.sumOf(payments),
        ),
        for (final row in payments) _paymentRow(row, lineIndex++),
      ],
      if (returns.isNotEmpty) ...[
        _paymentGroupHeader(
          label: 'المرتجعات',
          color: _returnRed,
          amount: InvoicePaymentLine.sumOf(returns),
        ),
        for (final row in returns) _paymentRow(row, lineIndex++),
      ],
      _paymentNetRow(invoice),
    ];
  }

  static pw.Widget _paymentSectionHeader() {
    return pw.Container(
      height: 26,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .65),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: _tableText(
              'تفاصيل الدفعات والمرتجعات',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.2,
            ),
          ),
          _tableDivider(color: _line, height: 26),
          pw.Expanded(
            flex: 3,
            child: _tableText(
              'التاريخ',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.2,
            ),
          ),
          _tableDivider(color: _line, height: 26),
          pw.Expanded(
            flex: 2,
            child: _tableText(
              'الوقت',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.2,
            ),
          ),
          _tableDivider(color: _line, height: 26),
          pw.Expanded(
            flex: 3,
            child: _tableText(
              'المبلغ',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.2,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentGroupHeader({
    required String label,
    required PdfColor color,
    required double amount,
  }) {
    return pw.Container(
      height: 24,
      decoration: pw.BoxDecoration(
        color: _softGold,
        border: pw.Border(
          left: pw.BorderSide(color: _line, width: .5),
          right: pw.BorderSide(color: _line, width: .5),
          bottom: pw.BorderSide(color: _line, width: .5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 9,
            child: _tableText(
              label,
              color: color,
              bold: true,
              center: true,
              fontSize: 10.2,
            ),
          ),
          _tableDivider(height: 24),
          pw.Expanded(
            flex: 3,
            child: _priceText(
              Formatters.formatMoney(amount),
              fontSize: 10.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentRow(InvoicePaymentLine row, int index) {
    final occurredAt = row.occurredAt;
    final color = row.isReturn ? _returnRed : _text;

    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 26),
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
          pw.Expanded(
            flex: 4,
            child: _tableText(
              row.labelAr,
              color: color,
              bold: true,
              center: true,
              maxLines: 2,
              fontSize: 10,
            ),
          ),
          _tableDivider(height: 26),
          pw.Expanded(
            flex: 3,
            child: _priceText(
              occurredAt == null
                  ? '—'
                  : Formatters.formatPaymentDate(occurredAt),
              fontSize: 9.6,
              color: _muted,
            ),
          ),
          _tableDivider(height: 26),
          pw.Expanded(
            flex: 2,
            child: _tableText(
              occurredAt == null
                  ? '—'
                  : Formatters.formatPaymentTime(occurredAt),
              color: _muted,
              center: true,
              fontSize: 9.6,
            ),
          ),
          _tableDivider(height: 26),
          pw.Expanded(
            flex: 3,
            child: _priceText(
              row.isReturn
                  ? '- ${Formatters.formatMoney(row.amount)}'
                  : Formatters.formatMoney(row.amount),
              fontSize: 10.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentNetRow(InvoiceModel invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.vertical(
          bottom: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .75),
      ),
      child: _invoiceMoneyRow(
        label: 'صافي المدفوع',
        value: Formatters.formatMoney(invoice.paidTotal),
        height: 32,
        isLast: true,
        isMain: false,
      ),
    );
  }

  static pw.Widget _tableHeader() {
    return pw.Container(
      height: 30,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .65),
      ),
      child: pw.Row(
        children: [
          _tableText(
            '',
            width: 38,
            color: _white,
            bold: true,
            center: true,
            fontSize: 9.2,
          ),
          _tableDivider(color: _line, height: 30),
          pw.Expanded(
            flex: 5,
            child: _tableText(
              'اسم الصنف',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.8,
            ),
          ),
          _tableDivider(color: _line, height: 30),
          pw.Expanded(
            flex: 2,
            child: _tableText(
              'السعر',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.8,
            ),
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
          fontSize: 9.4,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _itemRow(InvoiceItemModel item, int index) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 34),
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
            fontSize: 9,
          ),
          _tableDivider(height: 34),
          pw.Expanded(
            flex: 5,
            child: _tableText(
              item.displayItemName,
              color: _text,
              maxLines: 2,
              center: true,
              bold: true,
              fontSize: 11.2,
            ),
          ),
          _tableDivider(height: 34),
          pw.Expanded(
            flex: 2,
            child: _priceText(
              Formatters.formatMoney(item.price),
              fontSize: 10.9,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalAndPaymentSummary(InvoiceModel invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: const pw.BorderRadius.vertical(
          bottom: pw.Radius.circular(9),
        ),
        border: pw.Border.all(color: _line, width: .75),
      ),
      child: pw.Column(
        children: [
          _invoiceMoneyRow(
            label: 'الإجمالي',
            value: Formatters.formatMoney(invoice.total),
            height: 38,
            isLast: false,
            isMain: true,
          ),
          pw.Container(height: 1, color: _line),
          _invoiceMoneyRow(
            label: 'المبلغ المدفوع',
            value: Formatters.formatMoney(invoice.paidTotal),
            height: 36,
            isLast: false,
            isMain: false,
          ),
          pw.Container(height: 1, color: _line),
          _invoiceMoneyRow(
            label: 'المبلغ المتبقي',
            value: Formatters.formatMoney(invoice.unpaidTotal),
            height: 36,
            isLast: true,
            isMain: false,
          ),
        ],
      ),
    );
  }

  static pw.Widget _invoiceMoneyRow({
    required String label,
    required String value,
    required double height,
    required bool isLast,
    required bool isMain,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            height: height,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _gold,
              borderRadius: isLast
                  ? const pw.BorderRadius.only(
                      bottomRight: pw.Radius.circular(8),
                    )
                  : null,
            ),
            child: pw.Text(
              label,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: isMain ? 12 : 11.4,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.Container(width: 1, height: height, color: _line),
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            height: height,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: isLast
                  ? const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(8),
                    )
                  : null,
            ),
            child: pw.Text(
              value,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(
                color: _gold,
                fontSize: isMain ? 11.8 : 11.3,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _priceText(
    String text, {
    required PdfColor color,
    required double fontSize,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        maxLines: 1,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.normal,
        ),
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
    double fontSize = 8.9,
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
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    if (width == null) return child;

    return pw.SizedBox(width: width, child: child);
  }

  static pw.Widget _tableDivider({PdfColor? color, double height = 34}) {
    return pw.Container(width: .5, height: height, color: color ?? _line);
  }

  static pw.Widget _buildRepeatedFooter(
    pw.Context context,
    pw.ImageProvider? logo,
    _InvoicePdfAssets assets,
  ) {
    return pw.Align(
      alignment: pw.Alignment.bottomCenter,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _white,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: _line, width: .7),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: _softGold,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(
                  color: const PdfColor(.84, .71, .42, .45),
                  width: .45,
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _footerBrand(logo),
                  pw.SizedBox(width: 9),
                  pw.Container(width: .65, height: 38, color: _gold),
                  pw.SizedBox(width: 9),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _footerDataFrame(
                          text: '01210568226 - 01098279207',
                          svg: assets.phoneSvg,
                          fallbackIcon: '☎',
                        ),
                        pw.SizedBox(height: 4),
                        _footerDataFrame(
                          text:
                              'المحله الكبرى - ميدان الشون - أمام مدرسة طه حسين',
                          svg: assets.locationSvg,
                          fallbackIcon: '⌖',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _muted,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _footerLogoBox(pw.ImageProvider? logo) {
    return pw.Container(
      width: 36,
      height: 36,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _gold, width: 1.1),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: logo == null
            ? pw.Center(
                child: pw.Text(
                  'MS',
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 9.6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            : pw.Image(logo, fit: pw.BoxFit.contain),
      ),
    );
  }

  static pw.Widget _footerBrand(pw.ImageProvider? logo) {
    return pw.Row(
      children: [
        _footerLogoBox(logo),
        pw.SizedBox(width: 7),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'مصطفى سعد',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _navy,
                fontSize: 11.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'MOSTAFA SAAD',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _gold,
                fontSize: 6.9,
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
    required String? svg,
    required String fallbackIcon,
  }) {
    return pw.Container(
      height: 21,
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
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 16,
            height: 16,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              shape: pw.BoxShape.circle,
            ),
            child: svg == null
                ? pw.Text(
                    fallbackIcon,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: _white,
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  )
                : pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.SvgImage(svg: svg, width: 9, height: 9),
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
                fontSize: 9.1,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoicePdfAssets {
  final pw.Font regular;
  final pw.Font bold;
  final Uint8List? logoBytes;
  final String? phoneSvg;
  final String? locationSvg;

  const _InvoicePdfAssets({
    required this.regular,
    required this.bold,
    required this.logoBytes,
    required this.phoneSvg,
    required this.locationSvg,
  });
}
