import 'dart:typed_data';

import 'package:fatora/core/utils/app_toast.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';

class InvoicePdfScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePdfScreen({super.key, required this.invoice});

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  static const String _downloadIcon = 'assets/icons/download.svg';
  static const String _exportIcon = 'assets/icons/export.svg';

  late Future<Uint8List> _pdfFuture;

  bool _isSaving = false;
  bool _isSharing = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _pdfFuture = PdfService.buildInvoicePdf(widget.invoice);
  }

  Future<void> _savePdf() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final bytes = await _pdfFuture;

      final result = await PdfService.saveInvoiceBytes(
        invoice: widget.invoice,
        bytes: bytes,
      );

      if (!mounted) return;

      _showMessage('تم حفظ الملف: ${result.fileName}');
    } catch (_) {
      if (!mounted) return;

      _showMessage('حدث خطأ أثناء حفظ ملف PDF', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final bytes = await _pdfFuture;

      await PdfService.shareInvoiceBytes(invoice: widget.invoice, bytes: bytes);

      if (!mounted) return;

      _showMessage('تم تجهيز الفاتورة للمشاركة بنجاح');
    } catch (_) {
      if (!mounted) return;

      _showMessage('حدث خطأ أثناء مشاركة ملف PDF', isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _printPdf() async {
    if (_isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      final bytes = await _pdfFuture;

      await PdfService.printInvoiceBytes(invoice: widget.invoice, bytes: bytes);

      if (!mounted) return;

      _showMessage('تم فتح نافذة الطباعة');
    } catch (_) {
      if (!mounted) return;

      _showMessage('حدث خطأ أثناء الطباعة', isError: true);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _retryBuildPdf() {
    setState(() {
      _pdfFuture = PdfService.buildInvoicePdf(widget.invoice);
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    if (isError) {
      AppToast.showError(context, message: message);
    } else {
      AppToast.showSuccess(context, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final invoiceTitle = widget.invoice.title.trim().isEmpty
        ? 'معاينة الفاتورة'
        : widget.invoice.title.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 8,
          title: Text(
            invoiceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            _SvgActionButton(
              tooltip: 'حفظ PDF',
              asset: _downloadIcon,
              isLoading: _isSaving,
              onPressed: _savePdf,
            ),
            _SvgActionButton(
              tooltip: 'مشاركة PDF',
              asset: _exportIcon,
              isLoading: _isSharing,
              onPressed: _sharePdf,
            ),
            IconButton(
              tooltip: 'طباعة',
              onPressed: _isPrinting ? null : _printPdf,
              icon: _isPrinting
                  ? const _SmallLoader()
                  : Icon(Icons.print_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 4),
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
                onRetry: _retryBuildPdf,
              );
            }

            final bytes = snapshot.data;

            if (bytes == null || bytes.isEmpty) {
              return _PdfErrorView(
                message: 'ملف PDF فارغ',
                details: 'لم يتم إنشاء أي بيانات للفاتورة.',
                onRetry: _retryBuildPdf,
              );
            }

            return PdfPreview(
              build: (_) async => bytes,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) {
                return _PdfErrorView(
                  message: 'تعذر عرض ملف PDF',
                  details: error.toString(),
                  onRetry: _retryBuildPdf,
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

class _SvgActionButton extends StatelessWidget {
  final String tooltip;
  final String asset;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SvgActionButton({
    required this.tooltip,
    required this.asset,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const _SmallLoader()
          : SvgPicture.asset(
              asset,
              width: 23,
              height: 23,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary,
                BlendMode.srcIn,
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
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w900,
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
