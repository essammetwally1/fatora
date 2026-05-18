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
  static const String _downloadIcon = 'assets/icons/download.svg';
  static const String _exportIcon = 'assets/icons/export.svg';

  bool _isSaving = false;
  bool _isSharing = false;

  Future<void> _openPreview() async {
    Navigator.of(context).pop();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoicePdfScreen(invoice: widget.invoice),
      ),
    );
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(invoiceTitle: invoiceTitle),
              const SizedBox(height: 16),
              _MaterialActionTile(
                icon: Icons.visibility_rounded,
                title: 'معاينة PDF',
                subtitle: 'افتح صفحة المعاينة قبل الحفظ أو المشاركة',
                isLoading: false,
                onTap: _openPreview,
              ),
              const SizedBox(height: 10),
              _SvgActionTile(
                iconAsset: _downloadIcon,
                title: 'حفظ على الجهاز',
                subtitle: 'تنزيل الفاتورة كملف PDF',
                isLoading: _isSaving,
                onTap: _savePdf,
              ),
              const SizedBox(height: 10),
              _SvgActionTile(
                iconAsset: _exportIcon,
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

  const _SheetHeader({required this.invoiceTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.picture_as_pdf_rounded),
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
    );
  }
}

class _SvgActionTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _SvgActionTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ActionTileBase(
      title: title,
      subtitle: subtitle,
      isLoading: isLoading,
      onTap: onTap,
      icon: SvgPicture.asset(
        iconAsset,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(
          theme.colorScheme.onPrimary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _MaterialActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _MaterialActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ActionTileBase(
      title: title,
      subtitle: subtitle,
      isLoading: isLoading,
      onTap: onTap,
      icon: Icon(icon, color: theme.colorScheme.onPrimary),
    );
  }
}

class _ActionTileBase extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionTileBase({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        enabled: !isLoading,
        onTap: isLoading ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : icon,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_left_rounded,
          color: theme.colorScheme.primary,
        ),
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
