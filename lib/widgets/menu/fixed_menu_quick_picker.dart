import 'dart:math' as math;

import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/fixed_menu_item_model.dart';
import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Identity of a menu item for selection purposes.
///
/// Hive's box key is used when the item is stored, which it always is when it
/// comes from the provider. The name/price fallback only matters for an item
/// built in a test or detached from its box, and keeps selection working there
/// instead of collapsing every such item onto a single `null` key.
Object fixedMenuItemKey(FixedMenuItemModel item) {
  return item.key ?? '${item.displayName}-${item.price}';
}

/// Multi-select list of the saved fixed-menu items.
///
/// Selecting several rows composes them into one invoice line — "عدسة + إطار"
/// priced at the sum — which is how the shop actually sells: one job made of
/// several standard parts, charged as a single figure. Tapping a selected row
/// again removes it, so a mis-tap costs one tap to undo rather than forcing
/// the user to clear and start over.
class FixedMenuQuickPicker extends StatelessWidget {
  final bool enabled;

  /// Keys, per [fixedMenuItemKey], of the currently selected rows.
  final Set<Object> selectedKeys;

  final ValueChanged<FixedMenuItemModel> onToggle;

  /// Clears the whole selection. Hidden when nothing is selected.
  final VoidCallback? onClearSelection;

  const FixedMenuQuickPicker({
    super.key,
    required this.enabled,
    required this.selectedKeys,
    required this.onToggle,
    this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.select<FixedMenuProvider, _FixedMenuPickerState>(
      (provider) => _FixedMenuPickerState(
        items: provider.items,
        version: provider.version,
      ),
    );

    if (state.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .13)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerHeader(
              count: state.items.length,
              selectedCount: selectedKeys.length,
              color: colorScheme.primary,
              onClearSelection: enabled ? onClearSelection : null,
            ),
            const SizedBox(height: 10),
            _FixedMenuItemsViewport(
              enabled: enabled,
              items: state.items,
              selectedKeys: selectedKeys,
              onToggle: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedMenuPickerState {
  final List<FixedMenuItemModel> items;
  final int version;

  const _FixedMenuPickerState({required this.items, required this.version});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _FixedMenuPickerState &&
            identical(items, other.items) &&
            version == other.version;
  }

  @override
  int get hashCode => Object.hash(items, version);
}

class _PickerHeader extends StatelessWidget {
  final int count;
  final int selectedCount;
  final Color color;
  final VoidCallback? onClearSelection;

  const _PickerHeader({
    required this.count,
    required this.selectedCount,
    required this.color,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasSelection = selectedCount > 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            hasSelection
                ? 'تم اختيار $selectedCount من القائمة'
                : 'اختيار من القائمة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (hasSelection && onClearSelection != null)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              onPressed: onClearSelection,
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('مسح'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.error,
                textStyle: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
        else if (count > 3)
          Text(
            'اسحب للمزيد',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _FixedMenuItemsViewport extends StatelessWidget {
  static const int _maxVisibleItems = 3;
  static const double _separatorHeight = 8.0;

  /// Row padding plus the width the selection indicator and its gap take out
  /// of the line, so the measured text width matches what is actually drawn.
  static const double _horizontalPadding = 20.0 + 22.0 + 10.0;

  final bool enabled;
  final List<FixedMenuItemModel> items;
  final Set<Object> selectedKeys;
  final ValueChanged<FixedMenuItemModel> onToggle;

  const _FixedMenuItemsViewport({
    required this.enabled,
    required this.items,
    required this.selectedKeys,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(items.length, _maxVisibleItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTextWidth = math.max(
          80.0,
          constraints.maxWidth - _horizontalPadding,
        );

        final viewportHeight = _calculateViewportHeight(
          context: context,
          items: items.take(visibleCount).toList(growable: false),
          maxTextWidth: maxTextWidth,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: viewportHeight),
          child: ListView.separated(
            primary: false,
            shrinkWrap: true,
            physics: items.length > _maxVisibleItems
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: _separatorHeight),
            itemBuilder: (context, index) {
              final item = items[index];
              final itemKey = fixedMenuItemKey(item);

              return _FixedMenuListItem(
                key: ValueKey<Object>(itemKey),
                item: item,
                enabled: enabled,
                selected: selectedKeys.contains(itemKey),
                onTap: () => onToggle(item),
              );
            },
          ),
        );
      },
    );
  }

  double _calculateViewportHeight({
    required BuildContext context,
    required List<FixedMenuItemModel> items,
    required double maxTextWidth,
  }) {
    if (items.isEmpty) return 0;

    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context);

    final nameStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.25,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1.25,
        );

    final priceStyle =
        theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1,
        ) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, height: 1);

    double height = 0;

    for (final item in items) {
      height += _measureTextHeight(
        text: item.displayName,
        style: nameStyle,
        maxWidth: maxTextWidth,
        textScale: textScale,
      );

      height += 8; // space between name and price

      height += _measureTextHeight(
        text: Formatters.formatMoney(item.price),
        style: priceStyle,
        maxWidth: maxTextWidth,
        textScale: textScale,
      );

      height += 24; // vertical padding inside item
    }

    height += _separatorHeight * math.max(0, items.length - 1);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxAllowedHeight = screenHeight * .34;

    return math.min(math.max(height, 74.0), math.max(190.0, maxAllowedHeight));
  }

  double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScale,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScale,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }
}

class _FixedMenuListItem extends StatelessWidget {
  final FixedMenuItemModel item;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  const _FixedMenuListItem({
    super.key,
    required this.item,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Semantics(
        checked: selected,
        label: item.displayName,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(15),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary.withValues(alpha: .12)
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  width: selected ? 1.6 : 1,
                  color: colorScheme.primary.withValues(
                    alpha: selected ? .55 : .15,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelectionIndicator(selected: selected),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.displayName,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.start,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _PricePill(
                            price: item.price,
                            selected: selected,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          width: selected ? 0 : 1.6,
          color: selected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: .9),
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: colorScheme.onPrimary)
          : null,
    );
  }
}

class _PricePill extends StatelessWidget {
  final double price;
  final bool selected;

  const _PricePill({required this.price, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: selected ? .16 : .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: selected ? .3 : .13),
        ),
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
            height: 1,
          ),
        ),
      ),
    );
  }
}
