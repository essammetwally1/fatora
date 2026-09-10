import 'package:fatora/app/app_theme.dart';
import 'package:fatora/widgets/pdf_action_button.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/invoice_model.dart';
import '../invoice/invoice_star_button.dart';

class InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onExportPdf;
  final VoidCallback onExportImage;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onExportPdf,
    required this.onExportImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final invoiceStatus = _InvoiceStatus.fromInvoice(
      invoice,
      context.statusColors,
    );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On narrow phones the badge is dropped and the action column
              // tightened, so the title keeps a usable share of the row
              // instead of being squeezed to two or three characters.
              final isCompact =
                  constraints.maxWidth < Responsive.compactBreakpoint;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
                  vertical: 11,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isCompact) ...[
                      _InvoiceIconBadge(status: invoiceStatus, isDark: isDark),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: _InvoiceMainInfo(
                        invoice: invoice,
                        title: invoiceTitle,
                        titleColor: titleColor,
                        status: invoiceStatus,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _InvoiceActionsAndTotal(
                      // Three buttons instead of two, so the column is wider
                      // than it was; it still gives up less than the buttons
                      // take, because the row wraps before it overflows.
                      width: isCompact ? 104 : 118,
                      total: invoice.total,
                      totalBackgroundColor: totalBackgroundColor,
                      isDark: isDark,
                      onExportPdf: onExportPdf,
                      onExportImage: onExportImage,
                      onEdit: onEdit,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InvoiceMainInfo extends StatelessWidget {
  final InvoiceModel invoice;
  final String title;
  final Color titleColor;
  final _InvoiceStatus status;
  final bool isDark;

  const _InvoiceMainInfo({
    required this.invoice,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            // Beside the name rather than in the action column: three buttons
            // do not fit that column on a narrow phone, and a star reads as a
            // mark on the invoice, not as an action on it.
            InvoiceStarButton(invoice: invoice, size: 30, iconSize: 18),
          ],
        ),
        const SizedBox(height: 5),
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
  final double width;
  final double total;
  final Color totalBackgroundColor;
  final bool isDark;
  final VoidCallback onExportPdf;
  final VoidCallback onExportImage;
  final VoidCallback onEdit;

  const _InvoiceActionsAndTotal({
    required this.width,
    required this.total,
    required this.totalBackgroundColor,
    required this.isDark,
    required this.onExportPdf,
    required this.onExportImage,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A Wrap rather than a Row: at a large system font the three
          // buttons no longer fit one line on a narrow phone, and wrapping
          // onto a second line keeps them all reachable instead of painting
          // an overflow stripe.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              PdfActionButton(size: 30, onPressed: onExportPdf),
              ImageActionButton(
                size: 30,
                iconSize: 18,
                onPressed: onExportImage,
              ),
              _SmallCardIconButton(
                size: 30,
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
  final double size;
  final VoidCallback onPressed;

  const _SmallCardIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.square(size),
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

  factory _InvoiceStatus.fromInvoice(
    InvoiceModel invoice,
    AppStatusColors statusColors,
  ) {
    // No items, or items that all cost nothing: there is no payment to track
    // yet, so "unpaid / 0.00 remaining" would be misleading.
    if (invoice.items.isEmpty || invoice.total <= 0) {
      return const _InvoiceStatus(
        text: 'جديدة',
        remainingText: '',
        icon: Icons.add_circle_outline_rounded,
        badgeIcon: Icons.add_circle_outline_rounded,
        color: AppTheme.primary,
        iconColor: AppTheme.primary,
      );
    }

    final remaining = invoice.unpaidTotal;

    if (remaining <= 0) {
      return _InvoiceStatus(
        text: 'مكتملة',
        remainingText: '',
        icon: Icons.check_circle_outline_rounded,
        badgeIcon: Icons.receipt_long_rounded,
        color: statusColors.success,
        iconColor: statusColors.success,
      );
    }

    return _InvoiceStatus(
      text: 'غير مكتملة',
      remainingText: 'متبقي ${Formatters.formatMoney(remaining)}',
      icon: Icons.error_outline_rounded,
      badgeIcon: Icons.receipt_long_rounded,
      color: statusColors.danger,
      iconColor: statusColors.danger,
    );
  }
}
