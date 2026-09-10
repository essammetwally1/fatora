import 'dart:typed_data';

import 'package:fatora/data/models/invoice_model.dart';
import 'package:printing/printing.dart';

import '../files/app_file_saver.dart';
import '../files/invoice_file_names.dart';
import 'invoice_pdf_generator.dart';

class PdfService {
  const PdfService._();

  static Future<Uint8List> buildInvoicePdf(InvoiceModel invoice) {
    return InvoicePdfGenerator.build(invoice);
  }

  static Future<PdfSaveResult> saveInvoice(InvoiceModel invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    final fileName = fileNameForInvoice(invoice);

    final savedPath = await AppFileSaver.save(bytes: bytes, fileName: fileName);

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

    final savedPath = await AppFileSaver.save(bytes: bytes, fileName: fileName);

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
    return InvoiceFileNames.pdf(invoice);
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
