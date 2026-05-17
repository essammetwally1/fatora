import 'package:flutter/material.dart';

class InvoicesSectionHeader extends StatelessWidget {
  final int invoiceCount;

  const InvoicesSectionHeader({super.key, required this.invoiceCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الفواتير',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$invoiceCount فاتورة',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
