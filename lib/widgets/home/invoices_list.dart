import 'package:fatora/widgets/home/invoice_card.dart';
import 'package:fatora/widgets/home/invoice_pdf_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      scrollCacheExtent: ScrollCacheExtent.pixels(700),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemCount: invoices.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return InvoicesSectionHeader(
            invoiceCount: hasSearchQuery ? invoices.length : totalInvoiceCount,
          );
        }

        final invoice = invoices[index - 1];

        return InvoiceCard(
          key: ValueKey(invoice.key ?? Object.hash(invoice.title, index)),
          invoice: invoice,
          onTap: () => _openInvoiceDetails(context, invoice),
          onLongPress: () => _deleteInvoiceByLongPress(context, invoice),
          onEdit: () => onEditInvoice(invoice),
          onExport: () => _showInvoicePdfActions(context, invoice),
        );
      },
    );
  }

  void _openInvoiceDetails(BuildContext context, InvoiceModel invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailsContext) => InvoiceDetailsScreen(
          invoice: invoice,
          onExport: (selectedInvoice) {
            _showInvoicePdfActions(detailsContext, selectedInvoice);
          },
        ),
      ),
    );
  }

  static void _showInvoicePdfActions(
    BuildContext context,
    InvoiceModel invoice,
  ) {
    InvoicePdfActionsSheet.show(context: context, invoice: invoice);
  }

  Future<void> _deleteInvoiceByLongPress(
    BuildContext context,
    InvoiceModel invoice,
  ) async {
    final confirmed = await _confirmDeleteInvoice(context);

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<InvoiceProvider>();
    final deleted = await provider.deleteInvoice(invoice);

    if (!context.mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الفاتورة، حاول مرة أخرى')),
      );
    }
  }

  Future<bool?> _confirmDeleteInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

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
