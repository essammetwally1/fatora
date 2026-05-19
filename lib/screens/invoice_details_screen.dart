import 'package:fatora/core/utils/search_utils.dart';
import 'package:fatora/widgets/customer_search_field.dart';
import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/invoice/empty_items_state.dart';
import 'package:fatora/widgets/invoice/invoice_item_sheet.dart';
import 'package:fatora/widgets/invoice/invoice_item_tile.dart';
import 'package:fatora/widgets/nosearch_result_state.dart';
import 'package:fatora/widgets/invoice/totals_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fatora/widgets/liquid_floating_action_button.dart';
import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    final nextQuery = SearchUtils.normalize(_searchController.text);

    if (nextQuery == _searchQuery) return;

    setState(() {
      _searchQuery = nextQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    final currentInvoice =
        provider.invoiceByKey(widget.invoice.key) ?? widget.invoice;

    final colorScheme = Theme.of(context).colorScheme;

    final sortedItems = _sortedItemsWithOriginalIndexes(currentInvoice.items);
    final filteredItems = _filterItemsByCustomerName(sortedItems, _searchQuery);
    final hasSearchQuery = _searchQuery.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(currentInvoice.title)),
        floatingActionButton: LiquidFloatingActionButton(
          onPressed: () {
            showInvoiceItemSheet(context, invoice: currentInvoice);
          },
          label: 'إضافة عنصر',
          icon: Icons.add_rounded,
        ),
        body: Column(
          children: [
            TotalsHeader(invoice: currentInvoice),
            CustomerSearchField(
              controller: _searchController,
              enabled: currentInvoice.items.isNotEmpty,
              onClear: _searchController.clear,
              labelText: 'بحث باسم العميل',
              enabledHintText: 'اكتب اسم العميل لعرض العناصر المطابقة',
              disabledHintText: 'أضف عناصر أولاً لتفعيل البحث',
            ),
            Expanded(
              child: _buildItemsList(
                context: context,
                colorScheme: colorScheme,
                currentInvoice: currentInvoice,
                filteredItems: filteredItems,
              ),
            ),
            if (hasSearchQuery && filteredItems.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'تم عرض ${filteredItems.length} نتيجة مطابقة لاسم العميل',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList({
    required BuildContext context,
    required ColorScheme colorScheme,
    required InvoiceModel currentInvoice,
    required List<_IndexedInvoiceItem> filteredItems,
  }) {
    if (currentInvoice.items.isEmpty) {
      return EmptyItemsState(color: colorScheme.primary);
    }

    if (filteredItems.isEmpty) {
      return NoSearchResultsState(
        color: colorScheme.primary,
        title: 'لا توجد عناصر مطابقة',
        message:
            'جرّب كتابة اسم العميل بطريقة مختلفة أو امسح البحث لعرض كل العناصر.',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: filteredItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sortedItem = filteredItems[index];
        final item = sortedItem.item;
        final originalIndex = sortedItem.originalIndex;

        return Dismissible(
          key: ValueKey('${item.date.microsecondsSinceEpoch}-$originalIndex'),
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
            onEdit: () {
              showInvoiceItemSheet(
                context,
                invoice: currentInvoice,
                itemIndex: originalIndex,
              );
            },
          ),
        );
      },
    );
  }

  List<_IndexedInvoiceItem> _filterItemsByCustomerName(
    List<_IndexedInvoiceItem> sortedItems,
    String query,
  ) {
    if (query.isEmpty) return sortedItems;

    return [
      for (final indexedItem in sortedItems)
        if (_customerNameMatchesQuery(indexedItem.item, query)) indexedItem,
    ];
  }

  bool _customerNameMatchesQuery(InvoiceItemModel item, String query) {
    final customerName = SearchUtils.normalize(item.displayCustomerName);
    return customerName.contains(query);
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
    return item.isPaid ? 1 : 0;
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
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
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
