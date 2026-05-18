import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';

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
      margin: EdgeInsets.zero,
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.receipt_long, color: iconColor, size: 21),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${invoice.items.length} عنصر',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                SizedBox(
                  width: 92,
                  height: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _SmallCardIconButton(
                            tooltip: 'تصدير PDF قريباً',
                            icon: Icons.picture_as_pdf_outlined,
                            onPressed: onExport,
                          ),
                          const SizedBox(width: 10),
                          _SmallCardIconButton(
                            tooltip: 'تعديل الاسم',
                            icon: Icons.edit_outlined,
                            onPressed: onEdit,
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 92,
                        height: 18,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            Formatters.formatMoney(invoice.total),
                            maxLines: 1,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
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
    );
  }
}

class _SmallCardIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallCardIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }
}
