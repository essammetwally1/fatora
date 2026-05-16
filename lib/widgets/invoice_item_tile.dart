import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_item_model.dart';
import 'info_row.dart';

class InvoiceItemTile extends StatelessWidget {
  final InvoiceItemModel item;
  final VoidCallback onEdit;

  const InvoiceItemTile({super.key, required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = item.isPaid ? Colors.green : Colors.orange;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.isPaid ? 'تم الدفع' : 'لم يتم الدفع',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InfoRow(title: 'الصنف', value: item.displayItemName),
              const SizedBox(height: 8),
              InfoRow(
                title: 'التاريخ',
                value: Formatters.formatDate(item.date),
              ),
              const SizedBox(height: 8),
              InfoRow(title: 'ملاحظات', value: item.displayNote),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  Formatters.formatMoney(item.price),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
