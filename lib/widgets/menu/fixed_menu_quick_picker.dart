import 'dart:math' as math;

import 'package:fatora/core/utils/formatters.dart';
import 'package:fatora/data/models/fixed_menu_item_model.dart';
import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FixedMenuQuickPicker extends StatelessWidget {
  final bool enabled;
  final ValueChanged<FixedMenuItemModel> onSelected;

  /// Kept for compatibility with previous Step 4 code.
  /// This UI intentionally shows name + price only.
  final ValueChanged<FixedMenuItemModel>? onQuickAdd;
  final Object? quickAddingKey;

  const FixedMenuQuickPicker({
    super.key,
    required this.enabled,
    required this.onSelected,
    this.onQuickAdd,
    this.quickAddingKey,
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
              color: colorScheme.primary,
            ),
            const SizedBox(height: 10),
            _FixedMenuItemsViewport(
              enabled: enabled,
              items: state.items,
              onSelected: onSelected,
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
  final Color color;

  const _PickerHeader({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'اختيار من القائمة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (count > 3)
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
  static const double _horizontalPadding = 20.0;

  final bool enabled;
  final List<FixedMenuItemModel> items;
  final ValueChanged<FixedMenuItemModel> onSelected;

  const _FixedMenuItemsViewport({
    required this.enabled,
    required this.items,
    required this.onSelected,
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

              return _FixedMenuListItem(
                key: ValueKey(item.key ?? '${item.displayName}-${item.price}'),
                item: item,
                enabled: enabled,
                onTap: () => onSelected(item),
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
  final VoidCallback onTap;

  const _FixedMenuListItem({
    super.key,
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: .15),
              ),
            ),
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
                  child: _PricePill(price: item.price),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final double price;

  const _PricePill({required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
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
            height: 1,
          ),
        ),
      ),
    );
  }
}
