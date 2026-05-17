import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../data/models/invoice_model.dart';

class InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onEdit,
    required this.onExport,
  });

  bool get _hasUnpaidItems {
    return invoice.items.any((item) => !item.isPaid && item.remainingValue > 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final iconBackgroundColor = _hasUnpaidItems
        ? Colors.red.withValues(alpha: .08)
        : Colors.white.withValues(alpha: .16);

    final iconColor = _hasUnpaidItems
        ? AppTheme.red.withValues(alpha: .7)
        : Colors.white;

    return Card(
      elevation: 0,
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.receipt_long, color: iconColor),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${invoice.items.length} عنصر',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تصدير PDF قريباً',
                        onPressed: onExport,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: 'تعديل الاسم',
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.formatMoney(invoice.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
