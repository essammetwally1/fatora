import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

class InvoiceDayHeader extends StatelessWidget {
  final DateTime date;
  final bool isLegacy;
  final int invoiceCount;

  const InvoiceDayHeader({
    super.key,
    required this.date,
    required this.isLegacy,
    required this.invoiceCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = Formatters.formatInvoiceDayLabel(date, isLegacy: isLegacy);
    final countText = invoiceCount == 1
        ? 'فاتورة واحدة'
        : '$invoiceCount فواتير';

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: .75),
            ),
          ),
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: .14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLegacy
                        ? Icons.history_rounded
                        : Icons.calendar_month_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$title • $countText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: .75),
            ),
          ),
        ],
      ),
    );
  }
}
