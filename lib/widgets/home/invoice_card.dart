import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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
    for (final item in invoice.items) {
      if (!item.isPaid && item.remainingValue > 0) {
        return true;
      }
    }

    return false;
  }

  double get _unpaidAmount {
    return invoice.items.fold<double>(0, (sum, item) {
      if (!item.isPaid && item.remainingValue > 0) {
        return sum + item.remainingValue;
      }

      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isNewInvoice = invoice.items.isEmpty;
    final hasUnpaidItems = _hasUnpaidItems;
    final unpaidAmount = _unpaidAmount;

    final invoiceTitle = invoice.title.trim().isEmpty
        ? 'فاتورة بدون عنوان'
        : invoice.title.trim();

    final statusText = isNewInvoice
        ? 'جديدة'
        : hasUnpaidItems
        ? 'غير مكتملة'
        : 'مكتملة';

    final statusIcon = isNewInvoice
        ? Icons.add_circle_outline_rounded
        : hasUnpaidItems
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    final statusColor = isNewInvoice
        ? AppTheme.primary
        : hasUnpaidItems
        ? AppTheme.red
        : AppTheme.green;

    final cardStartColor = isDark
        ? const Color(0xFF1D2148)
        : AppTheme.primary.withValues(alpha: .14);

    final cardEndColor = isDark
        ? const Color(0xFF11152F)
        : AppTheme.primary.withValues(alpha: .04);

    final borderColor = AppTheme.primary.withValues(alpha: isDark ? .30 : .20);

    final titleColor = isDark ? Colors.white : const Color(0xFF22264A);

    final statusBackgroundColor = statusColor.withValues(
      alpha: isDark ? .16 : .10,
    );

    final totalBackgroundColor = AppTheme.primary.withValues(
      alpha: isDark ? .20 : .10,
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [cardStartColor, cardEndColor],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: isDark ? .12 : .08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _InvoiceIconBadge(
                  isNewInvoice: isNewInvoice,
                  hasUnpaidItems: hasUnpaidItems,
                  isDark: isDark,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoiceTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusBackgroundColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 13, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isNewInvoice
                                  ? ''
                                  : hasUnpaidItems
                                  ? 'متبقي ${Formatters.formatMoney(unpaidAmount)}'
                                  : '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                SizedBox(
                  width: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PdfActionButton(onPressed: onExport),
                          const SizedBox(width: 8),
                          _SmallCardIconButton(
                            tooltip: 'تعديل الاسم',
                            icon: Icons.edit_outlined,
                            color: AppTheme.primary,
                            onPressed: onEdit,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: totalBackgroundColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.primary.withValues(
                              alpha: isDark ? .22 : .12,
                            ),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            Formatters.formatMoney(invoice.total),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.primary,
                              fontSize: 12.5,
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

class _InvoiceIconBadge extends StatelessWidget {
  final bool isNewInvoice;
  final bool hasUnpaidItems;
  final bool isDark;

  const _InvoiceIconBadge({
    required this.isNewInvoice,
    required this.hasUnpaidItems,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNewInvoice
        ? AppTheme.primary
        : hasUnpaidItems
        ? AppTheme.red
        : AppTheme.primary;

    final icon = isNewInvoice
        ? Icons.add_circle_outline_rounded
        : Icons.receipt_long_rounded;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? .18 : .11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? .26 : .18)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _PdfActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PdfActionButton({required this.onPressed});

  static const String _pdfIcon = 'assets/icons/pdf.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: 'خيارات PDF',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.red.withValues(alpha: isDark ? .18 : .10),
          foregroundColor: AppTheme.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppTheme.red.withValues(alpha: isDark ? .28 : .18),
            ),
          ),
        ),
        icon: SvgPicture.asset(_pdfIcon, width: 18, height: 18),
      ),
    );
  }
}

class _SmallCardIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _SmallCardIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: isDark ? .18 : .10),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: color.withValues(alpha: isDark ? .26 : .16),
            ),
          ),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
