import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:fatora/screens/invoice_pdf_screen.dart';
import 'package:flutter/material.dart';

Future<void> showInvoicePdfActionsSheet({
  required BuildContext context,
  required InvoiceModel invoice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: false,
    builder: (_) {
      return InvoicePdfActionsSheet(invoice: invoice);
    },
  );
}

class InvoicePdfActionsSheet extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePdfActionsSheet({super.key, required this.invoice});

  @override
  State<InvoicePdfActionsSheet> createState() => _InvoicePdfActionsSheetState();
}

class _InvoicePdfActionsSheetState extends State<InvoicePdfActionsSheet> {
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

      Navigator.of(context).pop();

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

      if (!mounted) return;
      Navigator.of(context).pop();
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
        ? 'فاتورة بدون عنوان'
        : widget.invoice.title.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.picture_as_pdf_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      invoiceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.visibility_rounded,
                title: 'معاينة PDF',
                subtitle: 'عرض الفاتورة قبل الحفظ أو المشاركة',
                onTap: _openPreview,
              ),
              _ActionTile(
                icon: Icons.download_rounded,
                title: 'تحميل PDF',
                subtitle: 'حفظ الفاتورة كملف PDF على الجهاز',
                isLoading: _isSaving,
                onTap: _savePdf,
              ),
              _ActionTile(
                icon: Icons.ios_share_rounded,
                title: 'مشاركة PDF',
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
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
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}
