import 'package:flutter/material.dart';

class CustomerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onClear;
  final String labelText;
  final String enabledHintText;
  final String disabledHintText;

  const CustomerSearchField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onClear,
    this.labelText = 'بحث باسم العميل',
    this.enabledHintText = 'اكتب اسم العميل لعرض العناصر المطابقة',
    this.disabledHintText = 'أضف عناصر أولاً لتفعيل البحث',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withValues(alpha: .72),
            ],
          ),
          border: Border.all(
            color: enabled
                ? colorScheme.primary.withValues(alpha: .22)
                : colorScheme.outlineVariant.withValues(alpha: .45),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? .12 : .08,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;

            return TextField(
              controller: controller,
              enabled: enabled,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant.withValues(alpha: .62),
                fontWeight: FontWeight.w600,
              ),
              cursorColor: colorScheme.primary,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: enabled ? enabledHintText : disabledHintText,
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: enabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                suffixIcon: hasText
                    ? IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: onClear,
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: colorScheme.primary.withValues(alpha: .65),
                    width: 1.2,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
