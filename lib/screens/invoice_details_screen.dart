import 'dart:async';

import 'package:fatora/core/utils/app_toast.dart';
import 'package:fatora/core/utils/ui_feed_back_utils.dart';
import 'package:fatora/widgets/delete_background.dart';
import 'package:fatora/widgets/invoice/empty_items_state.dart';
import 'package:fatora/widgets/invoice/invoice_item_sheet.dart';
import 'package:fatora/widgets/invoice/invoice_item_tile.dart';
import 'package:fatora/widgets/invoice/invoice_payment_summary_card.dart';
import 'package:fatora/widgets/liquid_floating_action_button.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final ValueChanged<InvoiceModel> onExport;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
    required this.onExport,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final Set<String> _selectedItemIds = <String>{};

  List<InvoiceItemModel>? _cachedItemsReference;
  List<_IndexedInvoiceItem> _cachedSortedItems = const [];

  @override
  void didUpdateWidget(covariant InvoiceDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.invoice.key != widget.invoice.key) {
      _selectedItemIds.clear();
      _clearItemsCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    /*
     * We include provider.version in the selected state because InvoiceModel is
     * mutable. The version ensures that this screen rebuilds after a successful
     * invoice mutation even when the Hive object reference remains unchanged.
     */
    final providerState = context
        .select<
          InvoiceProvider,
          ({InvoiceModel? invoice, bool isMutating, int version})
        >(
          (provider) => (
            invoice: provider.invoiceByKey(widget.invoice.key),
            isMutating: provider.isMutating,
            version: provider.version,
          ),
        );

    final currentInvoice = providerState.invoice ?? widget.invoice;

    final isMutating = providerState.isMutating;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sortedItems = _sortedItemsFor(currentInvoice.items);
    final validSelectedItemIds = _validSelectedIds(currentInvoice);

    final isSelectionMode = validSelectedItemIds.isNotEmpty;
    final canEditItems = currentInvoice.canEditItems;

    final allSelectableItemIds = _selectableItemIds(currentInvoice);

    final areAllItemsSelected =
        allSelectableItemIds.isNotEmpty &&
        validSelectedItemIds.length == allSelectableItemIds.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !isSelectionMode,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          if (isSelectionMode) {
            _clearSelection();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isSelectionMode,
            leading: isSelectionMode
                ? IconButton(
                    tooltip: 'إلغاء التحديد',
                    onPressed: isMutating ? null : _clearSelection,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isSelectionMode
                  ? Text(
                      '${validSelectedItemIds.length} محدد',
                      key: const ValueKey<String>('selected-items-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : Text(
                      currentInvoice.displayTitle,
                      key: ValueKey<String>(
                        'invoice-title-${currentInvoice.key}',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: currentInvoice.isPaymentCompleted
                            ? Colors.green
                            : colorScheme.onSurface,
                      ),
                    ),
            ),
            actions: isSelectionMode
                ? _buildSelectionActions(
                    invoice: currentInvoice,
                    selectedItemIds: validSelectedItemIds,
                    areAllItemsSelected: areAllItemsSelected,
                    isMutating: isMutating,
                  )
                : [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 15),
                      child: PdfActionButton(
                        size: 36,
                        iconSize: 19,
                        onPressed: () {
                          if (isMutating) return;

                          widget.onExport(currentInvoice);
                        },
                      ),
                    ),
                  ],
          ),
          floatingActionButton: canEditItems && !isSelectionMode && !isMutating
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
                  canEditItems: canEditItems,
                  isMutating: isMutating,
                  isSelectionMode: isSelectionMode,
                  selectedItemIds: validSelectedItemIds,
                  onStartSelection: _startSelection,
                  onToggleSelection: _toggleSelection,
                  onSwipeDelete: (originalIndex) {
                    return _confirmAndDeleteSingleItem(
                      invoice: currentInvoice,
                      originalIndex: originalIndex,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSelectionActions({
    required InvoiceModel invoice,
    required Set<String> selectedItemIds,
    required bool areAllItemsSelected,
    required bool isMutating,
  }) {
    if (isMutating) {
      return const [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 20),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ];
    }

    final colorScheme = Theme.of(context).colorScheme;

    return [
      IconButton(
        tooltip: areAllItemsSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
        onPressed: () {
          _toggleSelectAll(
            invoice: invoice,
            areAllItemsSelected: areAllItemsSelected,
          );
        },
        icon: Icon(
          areAllItemsSelected
              ? Icons.deselect_rounded
              : Icons.select_all_rounded,
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: IconButton.filledTonal(
          tooltip: 'حذف العناصر المحددة',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
          onPressed: selectedItemIds.isEmpty
              ? null
              : () {
                  _confirmAndDeleteSelectedItems(
                    invoice: invoice,
                    selectedItemIds: selectedItemIds,
                  );
                },
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    ];
  }

  Set<String> _selectableItemIds(InvoiceModel invoice) {
    return invoice.items
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Set<String> _validSelectedIds(InvoiceModel invoice) {
    final availableIds = _selectableItemIds(invoice);

    return _selectedItemIds.intersection(availableIds);
  }

  void _startSelection(String itemId) {
    final cleanId = itemId.trim();

    if (cleanId.isEmpty) return;
    if (_selectedItemIds.contains(cleanId)) return;

    /*
     * mediumImpact gives a deliberate but not excessively strong response.
     * The device decides the exact haptic strength and duration.
     */
    unawaited(HapticFeedback.mediumImpact());

    setState(() {
      _selectedItemIds.add(cleanId);
    });
  }

  void _toggleSelection(String itemId) {
    final cleanId = itemId.trim();

    if (cleanId.isEmpty) return;

    unawaited(HapticFeedback.selectionClick());

    setState(() {
      if (!_selectedItemIds.add(cleanId)) {
        _selectedItemIds.remove(cleanId);
      }
    });
  }

  void _toggleSelectAll({
    required InvoiceModel invoice,
    required bool areAllItemsSelected,
  }) {
    final allItemIds = _selectableItemIds(invoice);

    if (allItemIds.isEmpty) return;

    unawaited(HapticFeedback.selectionClick());

    setState(() {
      _selectedItemIds.clear();

      if (!areAllItemsSelected) {
        _selectedItemIds.addAll(allItemIds);
      }
    });
  }

  void _clearSelection() {
    if (_selectedItemIds.isEmpty) return;

    setState(_selectedItemIds.clear);
  }

  Future<void> _confirmAndDeleteSelectedItems({
    required InvoiceModel invoice,
    required Set<String> selectedItemIds,
  }) async {
    if (selectedItemIds.isEmpty) return;
    if (!invoice.canEditItems) return;

    final itemIdsToDelete = Set<String>.unmodifiable(selectedItemIds);

    final selectedCount = itemIdsToDelete.length;

    final confirmed = await UiFeedbackUtils.showDeleteConfirmation(
      context: context,
      itemCount: selectedCount,
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<InvoiceProvider>();

    final deleted = await provider.deleteItems(
      invoice: invoice,
      itemIds: itemIdsToDelete,
    );

    if (!mounted) return;

    if (deleted) {
      unawaited(HapticFeedback.mediumImpact());

      _clearSelection();

      AppToast.showSuccess(
        context,
        message: selectedCount == 1
            ? 'تم حذف العنصر بنجاح'
            : 'تم حذف $selectedCount عناصر بنجاح',
      );

      return;
    }

    unawaited(HapticFeedback.vibrate());

    AppToast.showError(
      context,
      message:
          provider.lastErrorMessage ??
          'تعذر حذف العناصر المحددة، حاول مرة أخرى',
    );
  }

  Future<bool> _confirmAndDeleteSingleItem({
    required InvoiceModel invoice,
    required int originalIndex,
  }) async {
    if (!invoice.canEditItems) return false;

    if (originalIndex < 0 || originalIndex >= invoice.items.length) {
      AppToast.showError(context, message: 'العنصر لم يعد موجودًا');

      return false;
    }

    final confirmed = await UiFeedbackUtils.showDeleteConfirmation(
      context: context,
      itemCount: 1,
    );

    if (!confirmed || !mounted) {
      return false;
    }

    final provider = context.read<InvoiceProvider>();

    final deleted = await provider.deleteItem(
      invoice: invoice,
      index: originalIndex,
    );

    if (!mounted) return deleted;

    if (deleted) {
      unawaited(HapticFeedback.mediumImpact());

      AppToast.showSuccess(context, message: 'تم حذف العنصر بنجاح');

      return true;
    }

    unawaited(HapticFeedback.vibrate());

    AppToast.showError(
      context,
      message: provider.lastErrorMessage ?? 'تعذر حذف العنصر، حاول مرة أخرى',
    );

    return false;
  }

  List<_IndexedInvoiceItem> _sortedItemsFor(List<InvoiceItemModel> items) {
    /*
     * Repository mutations replace invoice.items with a new list.
     * Therefore, identity is a safe and inexpensive cache key here.
     *
     * Selecting another item rebuilds the screen but does not sort the
     * invoice items again.
     */
    if (identical(_cachedItemsReference, items)) {
      return _cachedSortedItems;
    }

    _cachedItemsReference = items;
    _cachedSortedItems = _sortedItemsWithOriginalIndexes(items);

    return _cachedSortedItems;
  }

  void _clearItemsCache() {
    _cachedItemsReference = null;
    _cachedSortedItems = const [];
  }

  static List<_IndexedInvoiceItem> _sortedItemsWithOriginalIndexes(
    List<InvoiceItemModel> items,
  ) {
    if (items.isEmpty) return const [];

    final indexedItems = <_IndexedInvoiceItem>[
      for (var index = 0; index < items.length; index++)
        _IndexedInvoiceItem(item: items[index], originalIndex: index),
    ];

    indexedItems.sort((a, b) {
      final dateCompare = b.item.date.compareTo(a.item.date);

      if (dateCompare != 0) {
        return dateCompare;
      }

      return b.originalIndex.compareTo(a.originalIndex);
    });

    return List<_IndexedInvoiceItem>.unmodifiable(indexedItems);
  }
}

class _ItemsList extends StatelessWidget {
  /*
   * A larger threshold makes deletion more deliberate and reduces accidental
   * swipes. Both RTL swipe directions use the same threshold.
   */
  static const double _dismissThreshold = 0.8;

  static const Duration _movementDuration = Duration(milliseconds: 800);

  static const Duration _resizeDuration = Duration(milliseconds: 500);

  final InvoiceModel invoice;
  final List<_IndexedInvoiceItem> items;
  final Color emptyColor;
  final bool canEditItems;
  final bool isMutating;
  final bool isSelectionMode;
  final Set<String> selectedItemIds;
  final ValueChanged<String> onStartSelection;
  final ValueChanged<String> onToggleSelection;
  final Future<bool> Function(int originalIndex) onSwipeDelete;

  const _ItemsList({
    required this.invoice,
    required this.items,
    required this.emptyColor,
    required this.canEditItems,
    required this.isMutating,
    required this.isSelectionMode,
    required this.selectedItemIds,
    required this.onStartSelection,
    required this.onToggleSelection,
    required this.onSwipeDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (invoice.items.isEmpty) {
      return EmptyItemsState(color: emptyColor);
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        canEditItems && !isSelectionMode ? 96 : 24,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final indexedItem = items[index];
        final item = indexedItem.item;
        final originalIndex = indexedItem.originalIndex;

        final itemId = item.id.trim();
        final isSelected = selectedItemIds.contains(itemId);

        final canSelect = itemId.isNotEmpty && canEditItems && !isMutating;

        final canSwipeDelete = canEditItems && !isSelectionMode && !isMutating;

        final dismissibleKey = itemId.isNotEmpty
            ? '${invoice.key}-$itemId'
            : '${invoice.key}-legacy-'
                  '${item.date.microsecondsSinceEpoch}-'
                  '$originalIndex';

        return RepaintBoundary(
          child: Dismissible(
            key: ValueKey<String>(dismissibleKey),
            direction: canSwipeDelete
                ? DismissDirection.horizontal
                : DismissDirection.none,

            /*
             * Dismissible follows the finger while dragging. These settings
             * make the completed dismissal and return animation slower, while
             * the 68% threshold requires a more deliberate swipe.
             */
            movementDuration: _movementDuration,
            resizeDuration: _resizeDuration,
            dismissThresholds: const {
              DismissDirection.startToEnd: _dismissThreshold,
              DismissDirection.endToStart: _dismissThreshold,
            },
            confirmDismiss: (_) {
              if (!canSwipeDelete) {
                return Future<bool>.value(false);
              }

              return onSwipeDelete(originalIndex);
            },
            background: const DeleteBackground(),
            secondaryBackground: const DeleteBackground(),
            child: Semantics(
              selected: isSelected,
              button: true,
              label: isSelected
                  ? '${item.displayItemName}، محدد'
                  : item.displayItemName,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: canSelect ? () => onStartSelection(itemId) : null,
                onTap: isSelectionMode && canSelect
                    ? () => onToggleSelection(itemId)
                    : null,
                child: AbsorbPointer(
                  absorbing: isSelectionMode,
                  child: _SelectionFrame(
                    isSelected: isSelected,
                    child: InvoiceItemTile(
                      item: item,
                      canEdit: canEditItems && !isSelectionMode && !isMutating,
                      onEdit: () {
                        if (!canEditItems || isSelectionMode || isMutating) {
                          return;
                        }

                        showInvoiceItemSheet(
                          context,
                          invoice: invoice,
                          itemIndex: originalIndex,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionFrame extends StatelessWidget {
  final bool isSelected;
  final Widget child;

  const _SelectionFrame({required this.isSelected, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final selectionColor = colorScheme.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: isSelected ? 2.5 : 2,
          color: isSelected ? selectionColor : Colors.transparent,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: selectionColor.withValues(alpha: .16),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSelected ? .90 : 1,
            child: child,
          ),
          if (isSelected)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, badge) {
                  return Transform.scale(scale: value, child: badge);
                },
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: selectionColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: selectionColor.withValues(alpha: .28),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: colorScheme.onError,
                    size: 19,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IndexedInvoiceItem {
  final InvoiceItemModel item;
  final int originalIndex;

  const _IndexedInvoiceItem({required this.item, required this.originalIndex});
}
