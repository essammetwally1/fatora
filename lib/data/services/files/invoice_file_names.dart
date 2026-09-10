import '../../models/invoice_model.dart';

/// Builds the file names used by every invoice export.
///
/// Exports are named after the invoice's own date, so saved files sort by when
/// the business happened rather than by when someone happened to export them.
/// Undated legacy invoices are marked as such instead of borrowing today's
/// date.
class InvoiceFileNames {
  const InvoiceFileNames._();

  /// Extension-less stem shared by every file of one export.
  ///
  /// A multi-page image export must build this once and reuse it, so all of
  /// its pages carry the same stem and stay grouped in the file manager.
  static String baseName(InvoiceModel invoice) {
    final sanitizedTitle = invoice.title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), '_');

    final title = sanitizedTitle.isEmpty ? 'invoice' : sanitizedTitle;

    final createdAt = invoice.createdAt;

    final datePart = createdAt == null
        ? 'legacy'
        : '${createdAt.year.toString().padLeft(4, '0')}-'
              '${createdAt.month.toString().padLeft(2, '0')}-'
              '${createdAt.day.toString().padLeft(2, '0')}';

    // Kept only so two exports of the same invoice cannot collide.
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;

    return '$title-$datePart-$uniqueSuffix';
  }

  static String pdf(InvoiceModel invoice) => '${baseName(invoice)}.pdf';

  /// One page of an image export.
  ///
  /// Single-page invoices keep the plain stem; only a genuinely multi-page
  /// invoice gains a page number, so the common case is not cluttered by a
  /// "-1" that means nothing.
  static String imagePage({
    required String baseName,
    required int pageNumber,
    required int pageCount,
  }) {
    if (pageCount <= 1) return '$baseName.png';

    return '$baseName-$pageNumber.png';
  }
}
