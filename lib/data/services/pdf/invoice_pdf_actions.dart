import 'dart:typed_data';

import 'package:fatora/data/models/invoice_model.dart';
import 'package:printing/printing.dart';

import 'invoice_pdf_generator.dart';
import 'pdf_file_saver.dart';

class InvoicePdfActions {
  const InvoicePdfActions._();

  static Future<PdfDownloadResult> download(InvoiceModel invoice) async {
    final bytes = await _buildBytes(invoice);
    final fileName = fileNameFor(invoice);

    final savedPath = await savePdfFile(bytes: bytes, fileName: fileName);

    return PdfDownloadResult(fileName: fileName, savedPath: savedPath);
  }

  static Future<void> export(InvoiceModel invoice) async {
    final bytes = await _buildBytes(invoice);

    await Printing.sharePdf(bytes: bytes, filename: fileNameFor(invoice));
  }

  static String fileNameFor(InvoiceModel invoice) {
    final sanitizedTitle = invoice.title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), '_');

    final title = sanitizedTitle.isEmpty ? 'invoice' : sanitizedTitle;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return '$title-$timestamp.pdf';
  }

  static Future<Uint8List> _buildBytes(InvoiceModel invoice) {
    return InvoicePdfGenerator.build(invoice);
  }
}

class PdfDownloadResult {
  final String fileName;
  final String savedPath;

  const PdfDownloadResult({required this.fileName, required this.savedPath});
}
