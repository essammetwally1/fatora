import 'package:fatora/data/services/pdf/android_file_permission.dart';
import 'package:fatora/data/services/pdf/invoice_pdf_actions.dart';
import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/home/invoice_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../screens/invoice_details_screen.dart';
import '../nosearch_result_state.dart';
import 'invoices_section_header.dart';

class InvoicesList extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final int totalInvoiceCount;
  final bool hasSearchQuery;
  final ValueChanged<InvoiceModel> onEditInvoice;

  const InvoicesList({
    super.key,
    required this.invoices,
    required this.totalInvoiceCount,
    required this.hasSearchQuery,
    required this.onEditInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (invoices.isEmpty) {
      return NoSearchResultsState(
        color: colorScheme.primary,
        title: 'لا توجد فواتير مطابقة',
        message: hasSearchQuery
            ? 'جرّب البحث باسم فاتورة مختلف'
            : 'ابدأ بإضافة أول فاتورة',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: invoices.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return InvoicesSectionHeader(
            invoiceCount: hasSearchQuery ? invoices.length : totalInvoiceCount,
          );
        }

        final invoice = invoices[index - 1];

        return Dismissible(
          key: ValueKey(invoice.key ?? '${invoice.title}-$index'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDeleteInvoice(context),
          background: const DeleteBackground(),
          onDismissed: (_) {
            context.read<InvoiceProvider>().deleteInvoice(invoice);
          },
          child: InvoiceCard(
            invoice: invoice,
            onTap: () => _openInvoiceDetails(context, invoice),
            onEdit: () => onEditInvoice(invoice),
            onExport: () => _showPdfActionsSheet(context, invoice),
          ),
        );
      },
    );
  }

  void _openInvoiceDetails(BuildContext context, InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoice: invoice)),
    );
  }

  Future<void> _showPdfActionsSheet(
    BuildContext context,
    InvoiceModel invoice,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'خيارات ملف PDF',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    invoice.title.trim().isEmpty
                        ? 'فاتورة بدون عنوان'
                        : invoice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  _PdfActionTile(
                    icon: Icons.file_download_outlined,
                    title: 'تحميل PDF',
                    subtitle: 'حفظ نسخة من الفاتورة على الجهاز',
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      final hasPermission =
                          await AndroidFilePermission.ensureCanSaveFile();

                      if (!context.mounted) return;

                      if (!hasPermission) {
                        _showMessage(
                          context,
                          'يجب السماح بصلاحية الملفات لحفظ ملف PDF.',
                        );
                        return;
                      }

                      await _runPdfAction<PdfDownloadResult>(
                        context,
                        loadingMessage: 'جاري تجهيز ملف PDF...',
                        successMessage: (result) {
                          return 'تم حفظ ${result.fileName} في المكان الذي اخترته';
                        },
                        action: () => InvoicePdfActions.download(invoice),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  _PdfActionTile(
                    icon: Icons.ios_share_outlined,
                    title: 'تصدير PDF',
                    subtitle: 'مشاركة الفاتورة أو إرسالها خارج التطبيق',
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      await _runPdfAction<void>(
                        context,
                        loadingMessage: 'جاري تجهيز ملف PDF للتصدير...',
                        successMessage: (_) => 'تم فتح خيارات تصدير PDF',
                        action: () => InvoicePdfActions.export(invoice),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runPdfAction<T>(
    BuildContext context, {
    required String loadingMessage,
    required String Function(T result) successMessage,
    required Future<T> Function() action,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(loadingMessage)));

    try {
      final result = await action();

      if (!context.mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage(result))));
    } catch (_) {
      if (!context.mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تعذر إنشاء ملف PDF، حاول مرة أخرى.')),
        );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmDeleteInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الفاتورة'),
            content: const Text(
              'هل أنت متأكد من حذف هذه الفاتورة؟ سيتم حذف كل العناصر المرتبطة بها.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PdfActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PdfActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.onPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
