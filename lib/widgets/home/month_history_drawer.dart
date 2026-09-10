import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoice_month_key.dart';
import '../../data/models/invoice_month_snapshot.dart';
import '../common/app_empty_state.dart';

/// The side drawer: starred invoices first, then the month history.
///
/// Starred invoices are pinned above the months because that is the point of
/// starring one — reaching it without remembering which month it belongs to.
/// The section is collapsible so a long list of favourites cannot bury the
/// months underneath it.
class MonthHistoryDrawer extends StatefulWidget {
  final List<InvoiceMonthSnapshot> months;
  final InvoiceMonthKey selectedMonth;
  final ValueChanged<InvoiceMonthKey> onMonthSelected;
  final List<InvoiceModel> starredInvoices;
  final ValueChanged<InvoiceModel> onInvoiceSelected;

  const MonthHistoryDrawer({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onMonthSelected,
    required this.starredInvoices,
    required this.onInvoiceSelected,
  });

  @override
  State<MonthHistoryDrawer> createState() => _MonthHistoryDrawerState();
}

class _MonthHistoryDrawerState extends State<MonthHistoryDrawer> {
  bool _starredExpanded = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final drawerWidth = screenWidth < 600 ? screenWidth * .88 : 380.0;

    final starred = widget.starredInvoices;
    final months = widget.months;

    final hasStarred = starred.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        width: drawerWidth,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(child: _DrawerHeader()),
              if (hasStarred) ...[
                SliverToBoxAdapter(
                  child: _SectionToggle(
                    icon: Icons.star_rounded,
                    label: 'الفواتير المميزة (${starred.length})',
                    color: AppTheme.star,
                    expanded: _starredExpanded,
                    onTap: () {
                      setState(() => _starredExpanded = !_starredExpanded);
                    },
                  ),
                ),
                if (_starredExpanded)
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 6),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 8);
                          }

                          final invoice = starred[index ~/ 2];

                          return _StarredInvoiceTile(
                            key: ValueKey<Object>(
                              invoice.key ?? ObjectKey(invoice),
                            ),
                            invoice: invoice,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onInvoiceSelected(invoice);
                            },
                          );
                        },
                        childCount: starred.length * 2 - 1,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        addSemanticIndexes: false,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _SectionLabel(
                    icon: Icons.calendar_month_outlined,
                    label: 'شهور الفواتير',
                  ),
                ),
              ],
              if (months.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'لا توجد فواتير محفوظة بعد',
                    message: 'ستظهر شهور الفواتير هنا بمجرد إنشاء أول فاتورة.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 10);
                        }

                        final snapshot = months[index ~/ 2];

                        return _MonthCard(
                          key: ValueKey<String>('month-${snapshot.month}'),
                          snapshot: snapshot,
                          selected: snapshot.month == widget.selectedMonth,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onMonthSelected(snapshot.month);
                          },
                        );
                      },
                      childCount: months.length * 2 - 1,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
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

class _SectionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  const _SectionToggle({
    required this.icon,
    required this.label,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
      child: Semantics(
        button: true,
        expanded: expanded,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: expanded ? .5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One starred invoice, opened straight into the same details screen the
/// month list opens.
class _StarredInvoiceTile extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;

  const _StarredInvoiceTile({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColors = context.statusColors;

    final remaining = invoice.unpaidTotal;
    final isSettled = remaining <= 0;

    return Material(
      color: AppTheme.star.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.star.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 19, color: AppTheme.star),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.formatInvoiceDocumentDate(invoice.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.formatMoney(invoice.total),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSettled
                            ? 'مكتملة'
                            : 'متبقي ${Formatters.formatMoney(remaining)}',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSettled
                              ? statusColors.success
                              : colorScheme.error,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل الفواتير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'اختر الفترة المطلوبة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final InvoiceMonthSnapshot snapshot;
  final bool selected;
  final VoidCallback onTap;

  const _MonthCard({
    super.key,
    required this.snapshot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColors = context.statusColors;
    final totals = snapshot.totals;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: .11)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: .45)
                  : colorScheme.outlineVariant.withValues(alpha: .7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      snapshot.month.labelAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (snapshot.isCurrentMonth)
                    _Badge(text: 'الشهر الحالي', color: colorScheme.primary)
                  else if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'عدد الفواتير: '
                '${snapshot.invoiceCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: totals.collectionProgress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 10),
              _MoneyLine(
                label: 'الإجمالي',
                value: totals.total,
                color: colorScheme.primary,
              ),
              _MoneyLine(
                label: 'المدفوع',
                value: totals.paid,
                color: statusColors.success,
              ),
              _MoneyLine(
                label: 'المتبقي',
                value: totals.remaining,
                color: totals.remaining > 0
                    ? colorScheme.error
                    : statusColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MoneyLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 3),
      child: Row(
        children: [
          Text('$label: ', style: style?.copyWith(fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(
              Formatters.formatMoney(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
              style: style?.copyWith(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
