import 'dart:typed_data';

import 'package:fatora/data/models/invoice_model.dart';
import 'package:printing/printing.dart';

import 'invoice_pdf_generator.dart';
import 'pdf_file_saver.dart';

class PdfService {
  const PdfService._();

  static Future<Uint8List> buildInvoicePdf(InvoiceModel invoice) {
    return InvoicePdfGenerator.build(invoice);
  }

  static Future<PdfSaveResult> saveInvoice(InvoiceModel invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    final fileName = fileNameForInvoice(invoice);

    final savedPath = await PdfFileSaver.save(bytes: bytes, fileName: fileName);

    return PdfSaveResult(
      fileName: fileName,
      savedPath: savedPath,
      bytes: bytes,
    );
  }

  static Future<void> shareInvoice(InvoiceModel invoice) async {
    final bytes = await buildInvoicePdf(invoice);

    await shareInvoiceBytes(invoice: invoice, bytes: bytes);
  }

  static Future<void> printInvoice(InvoiceModel invoice) async {
    final bytes = await buildInvoicePdf(invoice);

    await printInvoiceBytes(invoice: invoice, bytes: bytes);
  }

  static Future<PdfSaveResult> saveInvoiceBytes({
    required InvoiceModel invoice,
    required Uint8List bytes,
  }) async {
    final fileName = fileNameForInvoice(invoice);

    final savedPath = await PdfFileSaver.save(bytes: bytes, fileName: fileName);

    return PdfSaveResult(
      fileName: fileName,
      savedPath: savedPath,
      bytes: bytes,
    );
  }

  static Future<void> shareInvoiceBytes({
    required InvoiceModel invoice,
    required Uint8List bytes,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileNameForInvoice(invoice),
    );
  }

  static Future<void> printInvoiceBytes({
    required InvoiceModel invoice,
    required Uint8List bytes,
  }) async {
    await Printing.layoutPdf(
      name: fileNameForInvoice(invoice),
      onLayout: (_) async => bytes,
    );
  }

  static String fileNameForInvoice(InvoiceModel invoice) {
    final sanitizedTitle = invoice.title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), '_');

    final title = sanitizedTitle.isEmpty ? 'invoice' : sanitizedTitle;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return '$title-$timestamp.pdf';
  }
}

class PdfSaveResult {
  final String fileName;
  final String savedPath;
  final Uint8List bytes;

  const PdfSaveResult({
    required this.fileName,
    required this.savedPath,
    required this.bytes,
  });
}
