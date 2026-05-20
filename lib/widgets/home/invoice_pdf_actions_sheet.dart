import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:fatora/screens/invoice_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InvoicePdfActionsSheet extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePdfActionsSheet({super.key, required this.invoice});

  static Future<void> show({
    required BuildContext context,
    required InvoiceModel invoice,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => InvoicePdfActionsSheet(invoice: invoice),
    );
  }

  @override
  State<InvoicePdfActionsSheet> createState() => _InvoicePdfActionsSheetState();
}

class _InvoicePdfActionsSheetState extends State<InvoicePdfActionsSheet> {
  static const String _pdfIcon = 'assets/icons/pdf.svg';
  static const String _downloadIcon = 'assets/icons/download.svg';
  static const String _exportIcon = 'assets/icons/export.svg';

  bool _isPreviewing = false;
  bool _isSaving = false;
  bool _isSharing = false;

  Future<void> _openPreview() async {
    if (_isPreviewing) return;

    setState(() => _isPreviewing = true);

    try {
      Navigator.of(context).pop();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoicePdfScreen(invoice: widget.invoice),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
  }

  Future<void> _savePdf() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final result = await PdfService.saveInvoice(widget.invoice);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _PdfSnackBar.build(
            context: context,
            icon: Icons.check_circle_rounded,
            message: 'تم حفظ الملف: ${result.fileName}',
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _PdfSnackBar.build(
            context: context,
            icon: Icons.error_rounded,
            message: 'حدث خطأ أثناء حفظ ملف PDF',
            isError: true,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      await PdfService.shareInvoice(widget.invoice);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _PdfSnackBar.build(
            context: context,
            icon: Icons.ios_share_rounded,
            message: 'تم تجهيز الفاتورة للمشاركة بنجاح',
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _PdfSnackBar.build(
            context: context,
            icon: Icons.error_rounded,
            message: 'حدث خطأ أثناء مشاركة ملف PDF',
            isError: true,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceTitle = widget.invoice.title.trim().isEmpty
        ? 'فاتورة بدون عنوان'
        : widget.invoice.title.trim();

    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(invoiceTitle: invoiceTitle, pdfIconAsset: _pdfIcon),
              const SizedBox(height: 16),

              _PdfActionTile(
                icon: Icon(
                  Icons.visibility_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 22,
                ),
                title: 'معاينة PDF',
                subtitle: 'افتح صفحة المعاينة قبل الحفظ أو المشاركة',
                isLoading: _isPreviewing,
                onTap: _openPreview,
              ),

              const SizedBox(height: 10),

              _PdfActionTile(
                icon: _ActionSvgIcon(assetName: _downloadIcon),
                title: 'حفظ على الجهاز',
                subtitle: 'تنزيل الفاتورة كملف PDF',
                isLoading: _isSaving,
                onTap: _savePdf,
              ),

              const SizedBox(height: 10),

              _PdfActionTile(
                icon: _ActionSvgIcon(assetName: _exportIcon),
                title: 'مشاركة / Export',
                subtitle: 'إرسال الفاتورة عبر واتساب أو تليجرام أو غيره',
                isLoading: _isSharing,
                onTap: _sharePdf,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String invoiceTitle;
  final String pdfIconAsset;

  const _SheetHeader({required this.invoiceTitle, required this.pdfIconAsset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: .30),
              child: SvgPicture.asset(pdfIconAsset, width: 23, height: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                invoiceTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfActionTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _PdfActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          enabled: !isLoading,
          onTap: isLoading ? null : onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('icon'),
                      width: 22,
                      height: 22,
                      child: Center(child: icon),
                    ),
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          trailing: Icon(
            Icons.chevron_left_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ActionSvgIcon extends StatelessWidget {
  final String assetName;

  const _ActionSvgIcon({required this.assetName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SvgPicture.asset(
      assetName,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(
        theme.colorScheme.onPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}

class _PdfSnackBar {
  const _PdfSnackBar._();

  static SnackBar build({
    required BuildContext context,
    required IconData icon,
    required String message,
    bool isError = false,
  }) {
    final theme = Theme.of(context);

    final backgroundColor = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final foregroundColor = isError
        ? theme.colorScheme.onError
        : theme.colorScheme.onPrimary;

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      elevation: 0,
      margin: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
