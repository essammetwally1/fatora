import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// One empty / "nothing found" / loading placeholder for the whole app.
///
/// Replaces `HomeEmptyState`, `NoSearchResultsState`, `EmptyItemsState`,
/// `_EmptyFixedMenuState` and `_EmptyMonthsState`, which were five copies of
/// the same icon + title + message column with slightly different paddings and
/// icon sizes.
///
/// It is always scrollable so it never overflows when the keyboard is open or
/// the user has a large text scale.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Tints the icon. Defaults to the theme primary colour.
  final Color? color;

  /// Shows a spinner in place of [icon] while content is loading.
  final bool isLoading;

  /// Optional call-to-action rendered under the message.
  final Widget? action;

  /// Extra bottom padding, used to clear a floating action button.
  final double bottomInset;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color,
    this.isLoading = false,
    this.action,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox.square(
                        dimension: 44,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    else
                      _IconHalo(icon: icon, color: effectiveColor),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft tinted disc behind the icon. Reads as intentional rather than as a
/// bare glyph floating in whitespace.
class _IconHalo extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconHalo({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .09),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Icon(icon, size: 44, color: color),
    );
  }
}
