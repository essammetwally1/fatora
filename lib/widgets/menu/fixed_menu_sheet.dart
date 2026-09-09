import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_toast.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/fixed_menu_item_model.dart';
import '../../providers/fixed_menu_provider.dart';
import '../common/app_empty_state.dart';
import 'fixed_menu_item_dialog.dart';

class FixedMenuSheet {
  const FixedMenuSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      // Colour, radius and clipping now come from `bottomSheetTheme`.
      // On tablets the sheet stops short of full width instead of spanning it.
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (_) => const _FixedMenuSheetContent(),
    );
  }
}

class _FixedMenuState {
  final List<FixedMenuItemModel> items;
  final int version;
  final bool isLoading;
  final bool isMutating;

  const _FixedMenuState({
    required this.items,
    required this.version,
    required this.isLoading,
    required this.isMutating,
  });

  bool get isBusy => isLoading || isMutating;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _FixedMenuState &&
            identical(items, other.items) &&
            version == other.version &&
            isLoading == other.isLoading &&
            isMutating == other.isMutating;
  }

  @override
  int get hashCode {
    return Object.hash(items, version, isLoading, isMutating);
  }
}

class _FixedMenuSheetContent extends StatelessWidget {
  const _FixedMenuSheetContent();

  @override
  Widget build(BuildContext context) {
    final state = context.select<FixedMenuProvider, _FixedMenuState>(
      (provider) => _FixedMenuState(
        items: provider.items,
        version: provider.version,
        isLoading: provider.isLoading,
        isMutating: provider.isMutating,
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .42,
        maxChildSize: .94,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _FixedMenuHeader(
                    isBusy: state.isBusy,
                    onAdd: () {
                      _openItemDialog(context);
                    },
                  ),
                ),
              ),
              if (state.isBusy)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ),
              if (state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.menu_book_outlined,
                    isLoading: state.isLoading,
                    title: state.isLoading
                        ? 'جاري تحميل القائمة'
                        : 'لا توجد أصناف ثابتة بعد',
                    message: state.isLoading
                        ? null
                        : 'اضغط “إضافة” لإنشاء أول صنف سريع.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 10);
                        }

                        final itemIndex = index ~/ 2;
                        final item = state.items[itemIndex];

                        return _FixedMenuItemTile(
                          key: _itemKey(item),
                          item: item,
                          isBusy: state.isBusy,
                          onEdit: () {
                            _openItemDialog(context, item: item);
                          },
                          onDelete: () {
                            _confirmAndDelete(context, item);
                          },
                        );
                      },
                      childCount: state.items.length * 2 - 1,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Key _itemKey(FixedMenuItemModel item) {
    final key = item.key;

    if (key != null) {
      return ValueKey<Object>(key);
    }

    // Stable while filtering, sorting, or editing another item.
    return ObjectKey(item);
  }

  Future<void> _openItemDialog(
    BuildContext context, {
    FixedMenuItemModel? item,
  }) async {
    final provider = context.read<FixedMenuProvider>();

    if (provider.isLoading || provider.isMutating) {
      _showMessage(
        context,
        provider.lastErrorMessage ?? 'توجد عملية أخرى قيد التنفيذ',
      );
      return;
    }

    FixedMenuItemModel? currentItem;

    if (item != null) {
      final itemKey = item.key;

      if (itemKey == null) {
        _showMessage(context, 'تعذر تحديد الصنف المطلوب تعديله');
        return;
      }

      currentItem = provider.itemByKey(itemKey);

      if (currentItem == null) {
        _showMessage(context, 'لم يعد الصنف موجودًا');
        return;
      }
    }

    final input = await showDialog<FixedMenuItemInput>(
      context: context,
      builder: (_) {
        return FixedMenuItemDialog(initialItem: currentItem);
      },
    );

    if (input == null || !context.mounted) {
      return;
    }

    if (provider.isMutating) {
      _showMessage(context, 'توجد عملية حفظ أخرى قيد التنفيذ');
      return;
    }

    bool saved;

    if (currentItem == null) {
      saved = await provider.createItem(name: input.name, price: input.price);
    } else {
      final latestItem = provider.itemByKey(currentItem.key);

      if (latestItem == null) {
        _showMessage(context, 'لم يعد الصنف موجودًا');
        return;
      }

      saved = await provider.updateItem(
        item: latestItem,
        name: input.name,
        price: input.price,
      );
    }

    if (!context.mounted || saved) {
      return;
    }

    _showMessage(
      context,
      provider.lastErrorMessage ?? 'تعذر حفظ الصنف، حاول مرة أخرى',
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    FixedMenuItemModel item,
  ) async {
    final provider = context.read<FixedMenuProvider>();

    if (provider.isLoading || provider.isMutating) {
      _showMessage(
        context,
        provider.lastErrorMessage ?? 'توجد عملية أخرى قيد التنفيذ',
      );
      return;
    }

    final itemKey = item.key;

    if (itemKey == null) {
      _showMessage(context, 'تعذر تحديد الصنف المطلوب حذفه');
      return;
    }

    final currentItem = provider.itemByKey(itemKey);

    if (currentItem == null) {
      _showMessage(context, 'لم يعد الصنف موجودًا');
      return;
    }

    final confirmed = await _showDeleteDialog(context, currentItem);

    if (confirmed != true || !context.mounted) {
      return;
    }

    final latestItem = provider.itemByKey(itemKey);

    if (latestItem == null) {
      _showMessage(context, 'تم حذف الصنف بالفعل');
      return;
    }

    final deleted = await provider.deleteItem(latestItem);

    if (!context.mounted || deleted) {
      return;
    }

    _showMessage(
      context,
      provider.lastErrorMessage ?? 'تعذر حذف الصنف، حاول مرة أخرى',
    );
  }

  Future<bool?> _showDeleteDialog(
    BuildContext context,
    FixedMenuItemModel item,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            scrollable: true,
            title: const Text('حذف الصنف'),
            content: Text(
              'هل تريد حذف '
              '"${item.displayName}" '
              'من القائمة؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
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

  /// Uses the toast overlay rather than a `SnackBar`.
  ///
  /// A `SnackBar` raised from inside a modal bottom sheet is drawn by the
  /// scaffold underneath it, so the user never saw these messages.
  void _showMessage(BuildContext context, String message) {
    AppToast.showError(context, message: message);
  }
}

class _FixedMenuHeader extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onAdd;

  const _FixedMenuHeader({required this.isBusy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final scaledFontSize = MediaQuery.textScalerOf(context).scale(14);

            final compact = constraints.maxWidth < 350 || scaledFontSize > 19;

            final identity = Expanded(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.menu, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'القائمة الثابتة',
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );

            final addButton = SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('إضافة', maxLines: 1),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [identity]),
                  const SizedBox(height: 10),
                  addButton,
                ],
              );
            }

            return Row(
              children: [identity, const SizedBox(width: 8), addButton],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'أضف الأصناف المتكررة لاستخدامها بسرعة داخل أي فاتورة.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FixedMenuItemTile extends StatelessWidget {
  final FixedMenuItemModel item;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedMenuItemTile({
    super.key,
    required this.item,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FixedMenuTileIcon(color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tooltip(
                        message: item.displayName,
                        waitDuration: const Duration(milliseconds: 450),
                        child: Text(
                          item.displayName,
                          maxLines: compact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _FixedMenuPricePill(price: item.price),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _FixedMenuTileActions(
                  isBusy: isBusy,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FixedMenuTileIcon extends StatelessWidget {
  final Color color;

  const _FixedMenuTileIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.inventory_2_outlined, color: color, size: 22),
    );
  }
}

class _FixedMenuPricePill extends StatelessWidget {
  final double price;

  const _FixedMenuPricePill({required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .13)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          Formatters.formatMoney(price),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _FixedMenuTileActions extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedMenuTileActions({
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FixedMenuActionButton(
          tooltip: 'تعديل',
          icon: Icons.edit_outlined,
          color: colorScheme.primary,
          enabled: !isBusy,
          onPressed: onEdit,
        ),
        const SizedBox(height: 4),
        _FixedMenuActionButton(
          tooltip: 'حذف',
          icon: Icons.delete_outline_rounded,
          color: colorScheme.error,
          enabled: !isBusy,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _FixedMenuActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _FixedMenuActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: .075),
          foregroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: .035),
          disabledForegroundColor: color.withValues(alpha: .35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }
}
