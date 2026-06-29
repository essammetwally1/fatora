import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/fixed_menu_item_model.dart';
import '../../providers/fixed_menu_provider.dart';
import 'fixed_menu_item_dialog.dart';

class FixedMenuSheet {
  const FixedMenuSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _FixedMenuSheetContent(),
    );
  }
}

class _FixedMenuState {
  final List<FixedMenuItemModel> items;
  final int version;
  final bool isMutating;

  const _FixedMenuState({
    required this.items,
    required this.version,
    required this.isMutating,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _FixedMenuState &&
            identical(items, other.items) &&
            version == other.version &&
            isMutating == other.isMutating;
  }

  @override
  int get hashCode => Object.hash(items, version, isMutating);
}

class _FixedMenuSheetContent extends StatelessWidget {
  const _FixedMenuSheetContent();

  @override
  Widget build(BuildContext context) {
    final state = context.select<FixedMenuProvider, _FixedMenuState>(
      (provider) => _FixedMenuState(
        items: provider.items,
        version: provider.version,
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
                    isMutating: state.isMutating,
                    onAdd: () => _openItemDialog(context),
                  ),
                ),
              ),
              if (state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFixedMenuState(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    MediaQuery.viewPaddingOf(context).bottom + 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 10);
                      }

                      final itemIndex = index ~/ 2;
                      final item = state.items[itemIndex];

                      return _FixedMenuItemTile(
                        key: ValueKey(item.key ?? item.displayName),
                        item: item,
                        isMutating: state.isMutating,
                        onEdit: () => _openItemDialog(context, item: item),
                        onDelete: () => _confirmAndDelete(context, item),
                      );
                    }, childCount: state.items.length * 2 - 1),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openItemDialog(
    BuildContext context, {
    FixedMenuItemModel? item,
  }) async {
    final provider = context.read<FixedMenuProvider>();

    if (provider.isMutating) return;

    final input = await showDialog<FixedMenuItemInput>(
      context: context,
      builder: (_) => FixedMenuItemDialog(initialItem: item),
    );

    if (input == null || !context.mounted) return;

    final saved = item == null
        ? await provider.createItem(name: input.name, price: input.price)
        : await provider.updateItem(
            item: item,
            name: input.name,
            price: input.price,
          );

    if (!context.mounted || saved) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الصنف، حاول مرة أخرى')),
      );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    FixedMenuItemModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الصنف'),
            content: Text('هل تريد حذف "${item.displayName}" من القائمة؟'),
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

    if (confirmed != true || !context.mounted) return;

    final deleted = await context.read<FixedMenuProvider>().deleteItem(item);

    if (!context.mounted || deleted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('تعذر حذف الصنف، حاول مرة أخرى')),
      );
  }
}

class _FixedMenuHeader extends StatelessWidget {
  final bool isMutating;
  final VoidCallback onAdd;

  const _FixedMenuHeader({required this.isMutating, required this.onAdd});

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
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: isMutating ? null : onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
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
  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedMenuItemTile({
    super.key,
    required this.item,
    required this.isMutating,
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
                  isMutating: isMutating,
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
  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedMenuTileActions({
    required this.isMutating,
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
          enabled: !isMutating,
          onPressed: onEdit,
        ),
        const SizedBox(height: 4),
        _FixedMenuActionButton(
          tooltip: 'حذف',
          icon: Icons.delete_outline_rounded,
          color: colorScheme.error,
          enabled: !isMutating,
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
      dimension: 34,
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

class _EmptyFixedMenuState extends StatelessWidget {
  final Color color;

  const _EmptyFixedMenuState({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu, color: color.withValues(alpha: .65), size: 54),
            const SizedBox(height: 10),
            Text(
              'لا توجد أصناف ثابتة بعد',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'اضغط إضافة لإنشاء أول صنف سريع.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
