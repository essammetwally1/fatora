import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/empty_items_state.dart';
import 'package:fatora/widgets/invoice_item_sheet.dart';
import 'package:fatora/widgets/invoice_item_tile.dart';
import 'package:fatora/widgets/totals_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    final currentInvoice = provider.invoiceByKey(invoice.key) ?? invoice;
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(currentInvoice.title)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              showInvoiceItemSheet(context, invoice: currentInvoice),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة عنصر'),
        ),
        body: Column(
          children: [
            TotalsHeader(invoice: currentInvoice),
            Expanded(
              child: currentInvoice.items.isEmpty
                  ? EmptyItemsState(color: colorScheme.primary)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: currentInvoice.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = currentInvoice.items[index];

                        return Dismissible(
                          key: ValueKey(
                            '${item.date.microsecondsSinceEpoch}-$index',
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteItem(context),
                          background: const DeleteBackground(),
                          onDismissed: (_) {
                            context.read<InvoiceProvider>().deleteItem(
                              invoice: currentInvoice,
                              index: index,
                            );
                          },
                          child: InvoiceItemTile(
                            item: item,
                            onEdit: () => showInvoiceItemSheet(
                              context,
                              invoice: currentInvoice,
                              itemIndex: index,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteItem(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف العنصر'),
            content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
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
