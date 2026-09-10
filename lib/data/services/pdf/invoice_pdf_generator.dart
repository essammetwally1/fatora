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

  /// The payment breakdown is a supporting detail printed under the totals,
  /// not a second invoice table, so it runs a size smaller than the item rows
  /// and keeps its own metrics here rather than scattering magic numbers.
  static const double _payHeaderHeight = 19;
  static const double _payRowHeight = 17;
  static const double _payHeaderFontSize = 8.2;
  static const double _payRowFontSize = 8;
  static const double _payMetaFontSize = 7.4;
  static const double _payCellPadding = 2;
  static const double _payNetRowHeight = 22;
  static const double _payNetFontSize = 9.4;

  /// Every table on the page is laid out as [line number | detail | amount],
  /// and these two widths are what make that true.
  ///
  /// Sharing them means one vertical rule runs down each side of the page: the
  /// line numbers stack in one band on the right, every amount in one band on
  /// the left, and the totals rows land exactly on the item table's grid.
  /// Before, each table divided the same width by its own flex ratios, so the
  /// three amount columns stopped a few points apart — close enough to read as
  /// a mistake rather than as a choice.
  /// How many breakdown rows still print as one unbreakable block.
  ///
  /// At [_payRowHeight] a dozen rows plus the header and the net total come to
  /// roughly a quarter of a page, which fits wherever it lands.
  static const int _maxUnbreakablePaymentRows = 12;

  static const double _indexColumnWidth = 38;
  static const double _moneyColumnWidth = 142;

  /// One radius and one border weight for the head of every table.
  static const double _tableRadius = 9;
  static const double _tableBorderWidth = .65;

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
      height: 130,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _line, width: .85),
      ),
      // The gold disc is placed to bleed off the bottom corner of the card.
      // The clip used to be the padding box, so the disc stopped 10pt short of
      // the corner on a straight edge, which read as a rectangle that had been
      // cut off. Clipping outside the padding instead lets it run to the
      // corner and take the card's radius, which is what a bleed should do.
      child: pw.ClipRRect(
        horizontalRadius: 18,
        verticalRadius: 18,
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
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _modernLogoSquare(logo),
                  pw.SizedBox(width: 14),
                  pw.Container(
                    width: .8,
                    height: 78,
                    color: const PdfColor(1, 1, 1, .22),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(child: _simpleCenteredBrandName()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The brand lockup: the name, then the rule and the ornament beneath it.
  ///
  /// The ornament used to be positioned against the bottom of the card while
  /// the name was centred in it, so the two were laid out against different
  /// edges and landed on top of each other — the rule crossed the descenders
  /// of "للبصريات" and the ornament crossed the rule. Everything sits in one
  /// column now, so the gaps below the name are the gaps that print.
  static pw.Widget _simpleCenteredBrandName() {
    return pw.Container(
      height: 110,
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
          // Clear of the descenders, then narrowing: the rule is wider than
          // the ornament under it, so the pair reads as one closing flourish
          // rather than as two rules that happen to be near each other.
          pw.SizedBox(height: 10),
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
          pw.SizedBox(height: 8),
          _brandOrnament(),
        ],
      ),
    );
  }

  /// Two hairlines around a gold diamond, centred under the brand rule.
  static pw.Widget _brandOrnament() {
    pw.Widget hairline() {
      return pw.Container(
        width: 42,
        height: .75,
        decoration: pw.BoxDecoration(
          color: const PdfColor(1, 1, 1, .35),
          borderRadius: pw.BorderRadius.circular(2),
        ),
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        hairline(),
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
        hairline(),
      ],
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
  ///
  /// Also omitted when the invoice is set to keep its breakdown private. Only
  /// this block goes: the totals row above still prints what was paid and what
  /// is left, so the receipt stays complete.
  static List<pw.Widget> _buildPaymentBreakdown(InvoiceModel invoice) {
    if (invoice.hidePaymentDetailsInExport) return const [];

    final rows = InvoicePaymentLine.fromInvoice(invoice);

    if (rows.isEmpty) return const [];

    final payments = rows.where((row) => !row.isReturn).toList(growable: false);
    final returns = rows.where((row) => row.isReturn).toList(growable: false);

    var lineIndex = 0;

    final bodyRows = <pw.Widget>[
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
    ];

    final netRow = _paymentNetRow(invoice);

    // `MultiPage` may break between any two widgets it is handed, and the
    // breakdown of a long invoice really does reach the bottom of a page. Left
    // as one widget per row it broke badly: a 22-item invoice printed its
    // "صافي المدفوع" alone on a third page, under nothing.
    //
    // A breakdown short enough to fit anywhere travels as a single widget, so
    // there is nowhere to break it. A longer one keeps its column titles with
    // the first rows and its total with the last, and breaks only in between.
    if (bodyRows.length <= _maxUnbreakablePaymentRows) {
      return [
        pw.SizedBox(height: 7),
        pw.Column(children: [_paymentSectionHeader(), ...bodyRows, netRow]),
      ];
    }

    final head = bodyRows.take(2).toList(growable: false);
    final middle = bodyRows.sublist(2, bodyRows.length - 1);
    final lastRow = bodyRows.last;

    return [
      pw.SizedBox(height: 7),
      pw.Column(children: [_paymentSectionHeader(), ...head]),
      ...middle,
      pw.Column(children: [lastRow, netRow]),
    ];
  }

  static pw.Widget _paymentSectionHeader() {
    return pw.Container(
      height: _payHeaderHeight,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(_tableRadius),
        ),
        border: pw.Border.all(color: _line, width: _tableBorderWidth),
      ),
      child: pw.Row(
        children: [
          // Blank, like the item table's leading cell, and the same width
          // so both tables keep one grid.
          pw.SizedBox(width: _indexColumnWidth, child: _paymentHeaderCell('')),
          _tableDivider(color: _line, height: _payHeaderHeight),
          pw.Expanded(flex: 4, child: _paymentHeaderCell('العملية')),
          _tableDivider(color: _line, height: _payHeaderHeight),
          pw.Expanded(flex: 3, child: _paymentHeaderCell('التاريخ')),
          _tableDivider(color: _line, height: _payHeaderHeight),
          pw.Expanded(flex: 2, child: _paymentHeaderCell('الوقت')),
          _tableDivider(color: _line, height: _payHeaderHeight),
          pw.SizedBox(
            width: _moneyColumnWidth,
            child: _paymentHeaderCell('المبلغ'),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentHeaderCell(String text) {
    return _tableText(
      text,
      color: _white,
      bold: true,
      center: true,
      fontSize: _payHeaderFontSize,
      verticalPadding: _payCellPadding,
    );
  }

  static pw.Widget _paymentGroupHeader({
    required String label,
    required PdfColor color,
    required double amount,
  }) {
    return pw.Container(
      height: _payRowHeight,
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
            child: _tableText(
              label,
              color: color,
              bold: true,
              center: true,
              fontSize: _payHeaderFontSize,
              verticalPadding: _payCellPadding,
            ),
          ),
          _tableDivider(height: _payRowHeight),
          pw.SizedBox(
            width: _moneyColumnWidth,
            child: _priceText(
              Formatters.formatMoney(amount),
              fontSize: _payHeaderFontSize,
              color: color,
              verticalPadding: _payCellPadding,
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
      constraints: const pw.BoxConstraints(minHeight: _payRowHeight),
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
          // Numbered like the item rows, and in the same column, so a customer
          // can point at "دفعة رقم ٣" and be understood.
          _tableText(
            '${index + 1}',
            width: _indexColumnWidth,
            color: color,
            bold: true,
            center: true,
            fontSize: _payMetaFontSize,
            verticalPadding: _payCellPadding,
          ),
          _tableDivider(height: _payRowHeight),
          pw.Expanded(
            flex: 4,
            child: _tableText(
              row.labelAr,
              color: color,
              bold: true,
              center: true,
              maxLines: 2,
              fontSize: _payRowFontSize,
              verticalPadding: _payCellPadding,
            ),
          ),
          _tableDivider(height: _payRowHeight),
          pw.Expanded(
            flex: 3,
            child: _priceText(
              occurredAt == null
                  ? '—'
                  : Formatters.formatPaymentDate(occurredAt),
              fontSize: _payMetaFontSize,
              color: _muted,
              verticalPadding: _payCellPadding,
            ),
          ),
          _tableDivider(height: _payRowHeight),
          pw.Expanded(
            flex: 2,
            child: _tableText(
              occurredAt == null
                  ? '—'
                  : Formatters.formatPaymentTime(occurredAt),
              color: _muted,
              center: true,
              fontSize: _payMetaFontSize,
              verticalPadding: _payCellPadding,
            ),
          ),
          _tableDivider(height: _payRowHeight),
          pw.SizedBox(
            width: _moneyColumnWidth,
            child: _priceText(
              row.isReturn
                  ? '- ${Formatters.formatMoney(row.amount)}'
                  : Formatters.formatMoney(row.amount),
              fontSize: _payRowFontSize,
              color: color,
              verticalPadding: _payCellPadding,
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
          bottom: pw.Radius.circular(8),
        ),
        border: pw.Border.all(color: _line, width: _tableBorderWidth),
      ),
      child: _invoiceMoneyRow(
        label: 'صافي المدفوع',
        value: Formatters.formatMoney(invoice.paidTotal),
        height: _payNetRowHeight,
        isLast: true,
        isMain: false,
        fontSize: _payNetFontSize,
      ),
    );
  }

  static pw.Widget _tableHeader() {
    return pw.Container(
      height: 30,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(_tableRadius),
        ),
        border: pw.Border.all(color: _line, width: _tableBorderWidth),
      ),
      child: pw.Row(
        children: [
          // Deliberately blank. The cell still holds the column's full width,
          // so the divider beside it lines up with the one under every row.
          _tableText(
            '',
            width: _indexColumnWidth,
            color: _white,
            bold: true,
            center: true,
            fontSize: 9.6,
          ),
          _tableDivider(color: _line, height: 30),
          pw.Expanded(
            child: _tableText(
              'اسم الصنف',
              color: _white,
              bold: true,
              center: true,
              fontSize: 10.8,
            ),
          ),
          _tableDivider(color: _line, height: 30),
          _tableText(
            'السعر',
            width: _moneyColumnWidth,
            color: _white,
            bold: true,
            center: true,
            fontSize: 10.8,
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
            width: _indexColumnWidth,
            color: _navy,
            bold: true,
            center: true,
            fontSize: 9,
          ),
          _tableDivider(height: 34),
          pw.Expanded(
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
          pw.SizedBox(
            width: _moneyColumnWidth,
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

  /// One summary row: a gold label band and the amount, on the page's grid.
  ///
  /// The label is centred over the detail column rather than over the whole
  /// band, so "الإجمالي" sits under "اسم الصنف" and the amount under "السعر" —
  /// the summary reads as the last rows of the table above it, not as a
  /// separate block that happens to be the same width.
  static pw.Widget _invoiceMoneyRow({
    required String label,
    required String value,
    required double height,
    required bool isLast,
    required bool isMain,
    double? fontSize,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            height: height,
            decoration: pw.BoxDecoration(
              color: _gold,
              borderRadius: isLast
                  ? const pw.BorderRadius.only(
                      bottomRight: pw.Radius.circular(8),
                    )
                  : null,
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(width: _indexColumnWidth),
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      label,
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: _navy,
                        fontSize: fontSize ?? (isMain ? 12 : 11.4),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Container(width: 1, height: height, color: _line),
        pw.SizedBox(
          width: _moneyColumnWidth,
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
            child: _moneyRun(
              value,
              color: _gold,
              fontSize: fontSize ?? (isMain ? 11.8 : 11.3),
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
    double verticalPadding = 4,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: verticalPadding,
      ),
      alignment: pw.Alignment.center,
      child: _moneyRun(text, color: color, fontSize: fontSize),
    );
  }

  /// An amount and its currency as two runs, each with its own direction.
  ///
  /// A money string is mixed-direction: Latin digits followed by the Arabic
  /// "ج.م". Every money cell used to force the whole string left-to-right so
  /// the digits would not be reordered, but that laid the currency out
  /// left-to-right too, and it printed as "م.ج" — the right letters in the
  /// wrong order. Splitting the string lets the digits stay left-to-right
  /// while the symbol is laid out right-to-left, which is the only way to get
  /// both halves right in one line.
  static pw.Widget _moneyRun(
    String text, {
    required PdfColor color,
    required double fontSize,
  }) {
    final style = pw.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.normal,
    );

    final money = Formatters.splitMoney(text);

    // Totals rows and the odd placeholder pass strings with no amount in them,
    // and a leading "-" on a return stays with the digits either way.
    if (money == null) {
      return pw.Text(
        text,
        maxLines: 1,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.ltr,
        style: style,
      );
    }

    return pw.Directionality(
      // Pins the order of the two runs, so the digits sit on the left and the
      // symbol on the right regardless of the page's own direction.
      textDirection: pw.TextDirection.ltr,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            money.amount,
            maxLines: 1,
            textDirection: pw.TextDirection.ltr,
            style: style,
          ),
          pw.SizedBox(width: 3),
          pw.Text(
            money.symbol,
            maxLines: 1,
            textDirection: pw.TextDirection.rtl,
            style: style,
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
    double fontSize = 8.9,
    double verticalPadding = 4,
  }) {
    final child = pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: verticalPadding,
      ),
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
