import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/invoice/empty_items_state.dart';
import 'package:fatora/widgets/invoice/invoice_item_sheet.dart';
import 'package:fatora/widgets/invoice/invoice_item_tile.dart';
import 'package:fatora/widgets/invoice/invoice_payment_summary_card.dart';
import 'package:fatora/widgets/liquid_floating_action_button.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final InvoiceModel invoice;
  final ValueChanged<InvoiceModel> onExport;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    final currentInvoice = provider.invoiceByKey(invoice.key) ?? invoice;

    final colorScheme = Theme.of(context).colorScheme;
    final sortedItems = _sortedItemsWithOriginalIndexes(currentInvoice.items);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            currentInvoice.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: currentInvoice.unpaidTotal == 0
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 15),
              child: PdfActionButton(
                size: 36,
                iconSize: 19,

                onPressed: () => onExport(currentInvoice),
              ),
            ),
          ],
        ),
        floatingActionButton: currentInvoice.canEditItems
            ? LiquidFloatingActionButton(
                onPressed: () {
                  showInvoiceItemSheet(context, invoice: currentInvoice);
                },
                label: 'إضافة عنصر',
                icon: Icons.add_rounded,
              )
            : null,
        body: Column(
          children: [
            InvoicePaymentSummaryCard(invoice: currentInvoice),
            Expanded(
              child: _ItemsList(
                invoice: currentInvoice,
                items: sortedItems,
                emptyColor: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_IndexedInvoiceItem> _sortedItemsWithOriginalIndexes(
    List<InvoiceItemModel> items,
  ) {
    final indexedItems = [
      for (var index = 0; index < items.length; index++)
        _IndexedInvoiceItem(item: items[index], originalIndex: index),
    ];

    indexedItems.sort((a, b) {
      final statusComparison = _paymentSortRank(
        a.item,
      ).compareTo(_paymentSortRank(b.item));

      if (statusComparison != 0) return statusComparison;

      return b.item.date.compareTo(a.item.date);
    });

    return indexedItems;
  }

  static int _paymentSortRank(InvoiceItemModel item) {
    if (!item.isPaid && item.remainingValue > 0) return 0;
    return 1;
  }
}

class _ItemsList extends StatelessWidget {
  final InvoiceModel invoice;
  final List<_IndexedInvoiceItem> items;
  final Color emptyColor;

  const _ItemsList({
    required this.invoice,
    required this.items,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    if (invoice.items.isEmpty) {
      return EmptyItemsState(color: emptyColor);
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final indexedItem = items[index];
        final item = indexedItem.item;
        final originalIndex = indexedItem.originalIndex;

        return Dismissible(
          key: ValueKey(
            '${invoice.key}-${item.date.microsecondsSinceEpoch}-$originalIndex',
          ),
          direction: DismissDirection.horizontal,
          confirmDismiss: (_) {
            return _confirmAndDeleteItem(
              context: context,
              invoice: invoice,
              index: originalIndex,
            );
          },
          background: const DeleteBackground(),
          secondaryBackground: const DeleteBackground(),
          child: InvoiceItemTile(
            item: item,
            canEdit: invoice.unpaidTotal > 0,
            onEdit: () {
              if (invoice.unpaidTotal <= 0) return;

              showInvoiceItemSheet(
                context,
                invoice: invoice,
                itemIndex: originalIndex,
              );
            },
          ),
        );
      },
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

  Future<bool> _confirmAndDeleteItem({
    required BuildContext context,
    required InvoiceModel invoice,
    required int index,
  }) async {
    final confirmed = await _confirmDeleteItem(context);

    if (confirmed != true || !context.mounted) return false;

    final deleted = await context.read<InvoiceProvider>().deleteItem(
      invoice: invoice,
      index: index,
    );

    if (!context.mounted) return deleted;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف العنصر، حاول مرة أخرى')),
      );
    }

    return deleted;
  }
}

class _IndexedInvoiceItem {
  final InvoiceItemModel item;
  final int originalIndex;

  const _IndexedInvoiceItem({required this.item, required this.originalIndex});
}
