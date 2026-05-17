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
        message:
            'جرّب كتابة اسم الفاتورة بطريقة مختلفة أو امسح البحث لعرض كل الفواتير.',
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
            onExport: () => _showPdfExportComingSoon(context),
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

  void _showPdfExportComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تصدير PDF للطباعة أو الحفظ سيتم إضافته قريباً'),
      ),
    );
  }

  Future<bool?> _confirmDeleteInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                  backgroundColor: Theme.of(context).colorScheme.error,
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
