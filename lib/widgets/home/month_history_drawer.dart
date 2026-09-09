import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice_month_key.dart';
import '../../data/models/invoice_month_snapshot.dart';
import '../common/app_empty_state.dart';

class MonthHistoryDrawer extends StatelessWidget {
  final List<InvoiceMonthSnapshot> months;
  final InvoiceMonthKey selectedMonth;
  final ValueChanged<InvoiceMonthKey> onMonthSelected;

  const MonthHistoryDrawer({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final drawerWidth = screenWidth < 600 ? screenWidth * .88 : 380.0;

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
              if (months.isEmpty)
                const SliverFillRemaining(
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
                          selected: snapshot.month == selectedMonth,
                          onTap: () {
                            Navigator.of(context).pop();
                            onMonthSelected(snapshot.month);
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
