import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/invoice_item_model.dart';

class InvoiceItemTile extends StatelessWidget {
  final InvoiceItemModel item;
  final VoidCallback onEdit;

  const InvoiceItemTile({super.key, required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = _PaymentStatus.fromItem(item);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: theme.brightness == Brightness.dark ? 0 : 1,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shadowColor: colorScheme.primary.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: .65),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showItemDetailsDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(status.icon, color: status.color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.displayCustomerName != 'عميل غير معروف') ...[
                        Text(
                          item.displayCustomerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      Text(
                        item.displayItemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              Formatters.formatMoney(item.price),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          if (item.hasPartialPayment) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.circle,
                              size: 4,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'المتبقي ${Formatters.formatMoney(item.remainingValue)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showItemDetailsDialog(BuildContext context) {
    final status = _PaymentStatus.fromItem(item);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayCustomerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogValueRow(
                    label: 'اسم العميل',
                    value: item.displayCustomerName,
                    icon: Icons.person_outline,
                  ),
                  _DialogValueRow(
                    label: 'الصنف',
                    value: item.displayItemName,
                    icon: Icons.inventory_2_outlined,
                  ),
                  _DialogValueRow(
                    label: 'السعر',
                    value: Formatters.formatMoney(item.price),
                    icon: Icons.payments_outlined,
                  ),
                  _DialogValueRow(
                    label: 'المدفوع',
                    value: Formatters.formatMoney(item.paidValue),
                    icon: Icons.price_check_outlined,
                  ),
                  _DialogValueRow(
                    label: 'المتبقي',
                    value: Formatters.formatMoney(item.remainingValue),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _DialogValueRow(
                    label: 'التاريخ',
                    value: Formatters.formatDate(item.date),
                    icon: Icons.calendar_today_outlined,
                  ),
                  _DialogValueRow(
                    label: 'ملاحظات',
                    value: item.displayNote,
                    icon: Icons.edit_note_outlined,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _PaymentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: status.color.withValues(alpha: .22)),
      ),
      child: Text(
        status.text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: status.color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DialogValueRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DialogValueRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withValues(alpha: .55)
              : colorScheme.surfaceContainerHighest.withValues(alpha: .70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? .35 : .65,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatus {
  final String text;
  final Color color;
  final IconData icon;

  const _PaymentStatus({
    required this.text,
    required this.color,
    required this.icon,
  });

  factory _PaymentStatus.fromItem(InvoiceItemModel item) {
    if (item.isPaid) {
      return const _PaymentStatus(
        text: 'مدفوع',
        color: AppTheme.green,
        icon: Icons.check_circle_outline,
      );
    }

    if (item.hasPartialPayment) {
      return const _PaymentStatus(
        text: 'باقي',
        color: AppTheme.blue,
        icon: Icons.timelapse_outlined,
      );
    }

    return const _PaymentStatus(
      text: 'غير مدفوع',
      color: AppTheme.red,
      icon: Icons.pending_outlined,
    );
  }
}
