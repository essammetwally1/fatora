import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/invoice_model.dart';
import '../files/app_file_saver.dart';
import '../files/invoice_file_names.dart';
import 'invoice_pdf_generator.dart';

/// One rendered page of an invoice, as a PNG.
@immutable
class InvoiceImagePage {
  /// 1-based, as printed on the page footer.
  final int pageNumber;
  final int pageCount;
  final int width;
  final int height;
  final Uint8List bytes;

  const InvoiceImagePage({
    required this.pageNumber,
    required this.pageCount,
    required this.width,
    required this.height,
    required this.bytes,
  });

  double get aspectRatio => height == 0 ? 1 : width / height;

  String get labelAr =>
      pageCount <= 1 ? 'صورة الفاتورة' : 'صفحة $pageNumber من $pageCount';
}

/// A failure the user can act on, phrased for the toast that shows it.
class InvoiceImageExportException implements Exception {
  final String messageAr;

  const InvoiceImageExportException(this.messageAr);

  @override
  String toString() => 'InvoiceImageExportException: $messageAr';
}

/// Exports an invoice as image(s) that look exactly like its PDF.
///
/// The images are rasterised from the very PDF the preview and the printer
/// use, rather than by screenshotting a widget. That is what keeps the two
/// exports identical: there is only one layout, and it lives in
/// [InvoicePdfGenerator]. A widget screenshot would be a second layout to keep
/// in sync, and would silently drift the first time either one changed.
///
/// A long invoice is several PDF pages, so it is several images — one per
/// page, in order.
class InvoiceImageExporter {
  const InvoiceImageExporter._();

  /// Render density, in dots per inch.
  ///
  /// 300dpi is the print standard: an A4 page comes out at about 2480x3508px,
  /// so the invoice stays crisp when zoomed right in and prints from a chat
  /// app as cleanly as the PDF itself. It costs about 35MB of pixels while a
  /// page is encoded — transient, because pages are encoded one at a time and
  /// the buffer is released immediately.
  static const double dpi = 300;

  /// Density for the second attempt.
  ///
  /// The rasteriser runs on the platform side and can fail on an old phone
  /// simply because [dpi] asks for more memory than it has. Half the density
  /// is a quarter of the pixels, which is worth trying before telling the user
  /// their invoice cannot be turned into an image at all.
  static const double fallbackDpi = 150;

  /// Refuses to rasterise an absurd number of pages.
  ///
  /// A real invoice is one to a handful of pages; the PDF itself allows up to
  /// 300. Every encoded page is held until the whole set is ready, so
  /// rasterising hundreds of them would exhaust memory on the client's phone.
  /// The export stops and says so instead of being killed by the OS.
  static const int maxPages = 40;

  /// Renders [invoice] to one PNG per page.
  ///
  /// Throws [InvoiceImageExportException] when the platform cannot rasterise
  /// PDFs or the document came back empty.
  static Future<List<InvoiceImagePage>> render(InvoiceModel invoice) async {
    final pdfBytes = await InvoicePdfGenerator.build(invoice);

    return renderPdf(pdfBytes);
  }

  /// Renders already-built [pdfBytes], so a screen that has a PDF in hand does
  /// not build the same document twice.
  ///
  /// Tries [dpi] first and drops to [fallbackDpi] if the platform rasteriser
  /// fails, which on a phone short of memory it can. An
  /// [InvoiceImageExportException] is never retried: those describe the
  /// document, not the device, and a second pass would fail the same way.
  static Future<List<InvoiceImagePage>> renderPdf(Uint8List pdfBytes) async {
    if (!await _canRaster()) {
      throw const InvoiceImageExportException(
        'تحويل الفاتورة إلى صورة غير مدعوم على هذا الجهاز',
      );
    }

    try {
      return await _renderAt(pdfBytes, dpi);
    } on InvoiceImageExportException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'Invoice raster failed at ${dpi}dpi, retrying at ${fallbackDpi}dpi:\n'
        'Error: $error\n$stackTrace',
      );
    }

    try {
      return await _renderAt(pdfBytes, fallbackDpi);
    } on InvoiceImageExportException {
      rethrow;
    } catch (error, stackTrace) {
      // The rasteriser reports its failures as plain platform errors. They are
      // logged for diagnosis but never shown raw: the user gets the same
      // readable sentence as every other export failure.
      debugPrint('Invoice raster failed:\nError: $error\n$stackTrace');

      throw const InvoiceImageExportException('تعذر تحويل الفاتورة إلى صورة');
    }
  }

  static Future<List<InvoiceImagePage>> _renderAt(
    Uint8List pdfBytes,
    double renderDpi,
  ) async {
    final encoded = <Uint8List>[];
    final sizes = <(int, int)>[];

    var seenPages = 0;

    // Pages are encoded one at a time and the raw pixel buffer is released
    // immediately, so peak memory stays at roughly one page rather than the
    // whole document.
    await for (final raster in Printing.raster(pdfBytes, dpi: renderDpi)) {
      seenPages++;

      if (seenPages > maxPages) {
        // Cancels the stream, so the rest of the document is never
        // rasterised, and leaves the over-limit page unencoded.
        break;
      }

      encoded.add(await _encodePng(raster));
      sizes.add((raster.width, raster.height));
    }

    if (seenPages > maxPages) {
      throw const InvoiceImageExportException(
        'الفاتورة أطول من $maxPages صفحة، استخدم تصدير PDF بدلاً من الصور',
      );
    }

    if (encoded.isEmpty) {
      throw const InvoiceImageExportException('تعذر تحويل الفاتورة إلى صورة');
    }

    final pageCount = encoded.length;

    return List<InvoiceImagePage>.unmodifiable([
      for (var index = 0; index < pageCount; index++)
        InvoiceImagePage(
          pageNumber: index + 1,
          pageCount: pageCount,
          width: sizes[index].$1,
          height: sizes[index].$2,
          bytes: encoded[index],
        ),
    ]);
  }

  /// Saves every page under one shared name.
  ///
  /// Android asks the user where to put each file, so a multi-page invoice
  /// means several dialogs. Dismissing one stops the run rather than asking
  /// again for every remaining page, and the result says how far it got.
  static Future<InvoiceImageSaveResult> saveAll({
    required InvoiceModel invoice,
    required List<InvoiceImagePage> pages,
  }) async {
    if (pages.isEmpty) {
      throw const InvoiceImageExportException('لا توجد صور للحفظ');
    }

    final baseName = InvoiceFileNames.baseName(invoice);

    final savedPaths = <String>[];

    for (final page in pages) {
      try {
        savedPaths.add(
          await AppFileSaver.save(
            bytes: page.bytes,
            fileName: InvoiceFileNames.imagePage(
              baseName: baseName,
              pageNumber: page.pageNumber,
              pageCount: page.pageCount,
            ),
          ),
        );
      } on FileSaveCancelledException {
        return InvoiceImageSaveResult(
          savedPaths: List<String>.unmodifiable(savedPaths),
          requestedCount: pages.length,
          wasCancelled: true,
        );
      }
    }

    return InvoiceImageSaveResult(
      savedPaths: List<String>.unmodifiable(savedPaths),
      requestedCount: pages.length,
      wasCancelled: false,
    );
  }

  /// Hands every page to the platform share sheet in one action, so a
  /// multi-page invoice arrives as one message instead of several.
  static Future<void> shareAll({
    required InvoiceModel invoice,
    required List<InvoiceImagePage> pages,
  }) async {
    if (pages.isEmpty) {
      throw const InvoiceImageExportException('لا توجد صور للمشاركة');
    }

    final baseName = InvoiceFileNames.baseName(invoice);

    final fileNames = [
      for (final page in pages)
        InvoiceFileNames.imagePage(
          baseName: baseName,
          pageNumber: page.pageNumber,
          pageCount: page.pageCount,
        ),
    ];

    await SharePlus.instance.share(
      ShareParams(
        // `cross_file` ignores the name on mobile, so the names are supplied
        // again through the override list the plugin actually reads.
        files: [
          for (var index = 0; index < pages.length; index++)
            XFile.fromData(
              pages[index].bytes,
              mimeType: 'image/png',
              name: fileNames[index],
            ),
        ],
        fileNameOverrides: fileNames,
        subject: invoice.displayTitle,
      ),
    );
  }

  static Future<bool> _canRaster() async {
    try {
      final info = await Printing.info();

      return info.canRaster;
    } catch (_) {
      // A missing plugin implementation must read as "unsupported", not as a
      // crash on the user's screen.
      return false;
    }
  }

  /// Encodes one rasterised page, releasing the decoded image straight away.
  ///
  /// `PdfRaster.toPng` does the same encoding but leaks its `ui.Image`, which
  /// on a multi-page invoice piles up native memory until the GC gets round
  /// to it.
  static Future<Uint8List> _encodePng(PdfRaster raster) async {
    final image = await raster.toImage();

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) {
        // Deliberately not an InvoiceImageExportException: coming back empty
        // is what a memory-starved encode looks like, and `renderPdf` retries
        // those at a lower density rather than giving up.
        throw StateError('PNG encoding of invoice page returned no bytes');
      }

      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Outcome of saving an image export, including a run the user stopped.
@immutable
class InvoiceImageSaveResult {
  final List<String> savedPaths;
  final int requestedCount;
  final bool wasCancelled;

  const InvoiceImageSaveResult({
    required this.savedPaths,
    required this.requestedCount,
    required this.wasCancelled,
  });

  int get savedCount => savedPaths.length;

  bool get savedNothing => savedPaths.isEmpty;

  bool get savedEverything => savedPaths.length == requestedCount;

  /// What to tell the user, phrased for the exact outcome: cancelling before
  /// the first file is not a failure, and stopping half way through must not
  /// claim the whole invoice was saved.
  String get messageAr {
    if (savedNothing) return 'تم إلغاء حفظ الصور';

    if (!savedEverything) {
      return 'تم حفظ $savedCount من $requestedCount صور قبل الإلغاء';
    }

    return savedCount == 1
        ? 'تم حفظ صورة الفاتورة'
        : 'تم حفظ $savedCount صور للفاتورة';
  }
}
