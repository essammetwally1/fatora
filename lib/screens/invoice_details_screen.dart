import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/empty_items_state.dart';
import 'package:fatora/widgets/invoice_item_sheet.dart';
import 'package:fatora/widgets/invoice_item_tile.dart';
import 'package:fatora/widgets/totals_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_item_model.dart';
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
    final sortedItems = _sortedItemsWithOriginalIndexes(currentInvoice.items);

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
                      itemCount: sortedItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final sortedItem = sortedItems[index];
                        final item = sortedItem.item;
                        final originalIndex = sortedItem.originalIndex;

                        return Dismissible(
                          key: ValueKey(
                            '${item.date.microsecondsSinceEpoch}-$originalIndex',
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteItem(context),
                          background: const DeleteBackground(),
                          onDismissed: (_) {
                            context.read<InvoiceProvider>().deleteItem(
                              invoice: currentInvoice,
                              index: originalIndex,
                            );
                          },
                          child: InvoiceItemTile(
                            item: item,
                            onEdit: () => showInvoiceItemSheet(
                              context,
                              invoice: currentInvoice,
                              itemIndex: originalIndex,
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

  List<_IndexedInvoiceItem> _sortedItemsWithOriginalIndexes(
    List<InvoiceItemModel> items,
  ) {
    final indexedItems = [
      for (var index = 0; index < items.length; index++)
        _IndexedInvoiceItem(item: items[index], originalIndex: index),
    ];

    indexedItems.sort((a, b) {
      final paymentStatusComparison = _paymentSortRank(
        a.item,
      ).compareTo(_paymentSortRank(b.item));

      if (paymentStatusComparison != 0) {
        return paymentStatusComparison;
      }

      return b.item.date.compareTo(a.item.date);
    });

    return indexedItems;
  }

  int _paymentSortRank(InvoiceItemModel item) {
    if (!item.isPaid) return 0;
    return 1;
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

class _IndexedInvoiceItem {
  final InvoiceItemModel item;
  final int originalIndex;

  const _IndexedInvoiceItem({required this.item, required this.originalIndex});
}
