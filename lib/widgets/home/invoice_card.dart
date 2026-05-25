import 'package:fatora/app/app_theme.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';

class InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final invoiceStatus = _InvoiceStatus.fromInvoice(invoice);

    final invoiceTitle = invoice.title.trim().isEmpty
        ? 'فاتورة بدون عنوان'
        : invoice.title.trim();

    final cardStartColor = isDark
        ? const Color(0xFF1D2148)
        : AppTheme.primary.withValues(alpha: .14);

    final cardEndColor = isDark
        ? const Color(0xFF11152F)
        : AppTheme.primary.withValues(alpha: .04);

    final borderColor = AppTheme.primary.withValues(alpha: isDark ? .30 : .20);
    final titleColor = isDark ? Colors.white : const Color(0xFF22264A);

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
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _InvoiceIconBadge(status: invoiceStatus, isDark: isDark),
                const SizedBox(width: 10),
                Expanded(
                  child: _InvoiceMainInfo(
                    title: invoiceTitle,
                    titleColor: titleColor,
                    status: invoiceStatus,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                _InvoiceActionsAndTotal(
                  total: invoice.total,
                  totalBackgroundColor: totalBackgroundColor,
                  isDark: isDark,
                  onExport: onExport,
                  onEdit: onEdit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceMainInfo extends StatelessWidget {
  final String title;
  final Color titleColor;
  final _InvoiceStatus status;
  final bool isDark;

  const _InvoiceMainInfo({
    required this.title,
    required this.titleColor,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusBackgroundColor = status.color.withValues(
      alpha: isDark ? .16 : .10,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: statusBackgroundColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(status.icon, size: 13, color: status.color),
                  const SizedBox(width: 4),
                  Text(
                    status.text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (status.remainingText.isNotEmpty)
              Expanded(
                child: Text(
                  status.remainingText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceActionsAndTotal extends StatelessWidget {
  final double total;
  final Color totalBackgroundColor;
  final bool isDark;
  final VoidCallback onExport;
  final VoidCallback onEdit;

  const _InvoiceActionsAndTotal({
    required this.total,
    required this.totalBackgroundColor,
    required this.isDark,
    required this.onExport,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PdfActionButton(onPressed: onExport),
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
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: totalBackgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: isDark ? .22 : .12),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                Formatters.formatMoney(total),
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
    );
  }
}

class _InvoiceIconBadge extends StatelessWidget {
  final _InvoiceStatus status;
  final bool isDark;

  const _InvoiceIconBadge({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: status.iconColor.withValues(alpha: isDark ? .18 : .11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.iconColor.withValues(alpha: isDark ? .26 : .18),
        ),
      ),
      child: Icon(status.badgeIcon, color: status.iconColor, size: 24),
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

    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size.square(32),
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

class _InvoiceStatus {
  final String text;
  final String remainingText;
  final IconData icon;
  final IconData badgeIcon;
  final Color color;
  final Color iconColor;

  const _InvoiceStatus({
    required this.text,
    required this.remainingText,
    required this.icon,
    required this.badgeIcon,
    required this.color,
    required this.iconColor,
  });

  factory _InvoiceStatus.fromInvoice(InvoiceModel invoice) {
    if (invoice.items.isEmpty) {
      return const _InvoiceStatus(
        text: 'جديدة',
        remainingText: '',
        icon: Icons.add_circle_outline_rounded,
        badgeIcon: Icons.add_circle_outline_rounded,
        color: AppTheme.primary,
        iconColor: AppTheme.primary,
      );
    }

    var unpaidAmount = 0.0;

    for (final item in invoice.items) {
      if (!item.isPaid && item.remainingValue > 0) {
        unpaidAmount += item.remainingValue;
      }
    }

    if (unpaidAmount > 0) {
      return _InvoiceStatus(
        text: 'غير مكتملة',
        remainingText: 'متبقي ${Formatters.formatMoney(unpaidAmount)}',
        icon: Icons.error_outline_rounded,
        badgeIcon: Icons.receipt_long_rounded,
        color: AppTheme.red,
        iconColor: AppTheme.red,
      );
    }

    return const _InvoiceStatus(
      text: 'مكتملة',
      remainingText: '',
      icon: Icons.check_circle_outline_rounded,
      badgeIcon: Icons.receipt_long_rounded,
      color: AppTheme.green,
      iconColor: AppTheme.primary,
    );
  }
}
