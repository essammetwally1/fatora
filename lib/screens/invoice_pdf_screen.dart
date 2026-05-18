import 'dart:typed_data';

import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class InvoicePdfScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePdfScreen({super.key, required this.invoice});

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  late final Future<Uint8List> _pdfFuture;

  bool _isSaving = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _pdfFuture = PdfService.buildInvoicePdf(widget.invoice);
  }

  Future<void> _savePdf() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final result = await PdfService.saveInvoice(widget.invoice);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الملف: ${result.fileName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الملف: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      await PdfService.shareInvoice(widget.invoice);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء مشاركة الملف: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoiceTitle = widget.invoice.title.trim().isEmpty
        ? 'فاتورة'
        : widget.invoice.title.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            invoiceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'حفظ PDF',
              onPressed: _isSaving ? null : _savePdf,
              icon: _isSaving
                  ? const _SmallLoader()
                  : const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: 'مشاركة PDF',
              onPressed: _isSharing ? null : _sharePdf,
              icon: _isSharing
                  ? const _SmallLoader()
                  : const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: FutureBuilder<Uint8List>(
          future: _pdfFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _PdfErrorView(
                message: 'تعذر إنشاء ملف PDF',
                details: snapshot.error.toString(),
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => InvoicePdfScreen(invoice: widget.invoice),
                    ),
                  );
                },
              );
            }

            final bytes = snapshot.data;

            if (bytes == null || bytes.isEmpty) {
              return _PdfErrorView(
                message: 'ملف PDF فارغ',
                details: 'لم يتم إنشاء بيانات للفاتورة.',
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => InvoicePdfScreen(invoice: widget.invoice),
                    ),
                  );
                },
              );
            }

            return PdfPreview(
              build: (_) async => bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              pdfFileName: PdfService.fileNameForInvoice(widget.invoice),
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) {
                return _PdfErrorView(
                  message: 'تعذر عرض ملف PDF',
                  details: error.toString(),
                  onRetry: () {
                    setState(() {});
                  },
                );
              },
              actionBarTheme: PdfActionBarTheme(
                backgroundColor: theme.colorScheme.surface,
                iconColor: theme.colorScheme.primary,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _PdfErrorView extends StatelessWidget {
  final String message;
  final String details;
  final VoidCallback onRetry;

  const _PdfErrorView({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.errorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
