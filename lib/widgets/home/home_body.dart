import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';

import '../../data/models/invoice_model.dart';
import '../customer_search_field.dart';
import 'home_empty_state.dart';
import 'home_totals_section.dart';
import 'invoices_list.dart';

class HomeBody extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final List<InvoiceModel> visibleInvoices;
  final InvoicesTotals totals;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;
  final ValueChanged<InvoiceModel> onEditInvoice;

  const HomeBody({
    super.key,
    required this.invoices,
    required this.visibleInvoices,
    required this.totals,
    required this.searchController,
    required this.searchQuery,
    required this.onClearSearch,
    required this.onEditInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (invoices.isEmpty) {
      return HomeEmptyState(color: colorScheme.primary);
    }

    final hasSearchQuery = searchQuery.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: HomeTotalsSection(totals: totals),
        ),
        CustomerSearchField(
          controller: searchController,
          enabled: true,
          onClear: onClearSearch,
          labelText: 'بحث في الفواتير',
          enabledHintText: 'اكتب اسم الفاتورة فقط',
          disabledHintText: 'أضف فواتير أولاً لتفعيل البحث',
        ),
        Expanded(
          child: InvoicesList(
            invoices: visibleInvoices,
            totalInvoiceCount: invoices.length,
            hasSearchQuery: hasSearchQuery,
            onEditInvoice: onEditInvoice,
          ),
        ),
        if (hasSearchQuery && visibleInvoices.isNotEmpty)
          _SearchResultIndicator(count: visibleInvoices.length),
      ],
    );
  }
}

class _SearchResultIndicator extends StatelessWidget {
  final int count;

  const _SearchResultIndicator({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 108, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TweenAnimationBuilder<double>(
            key: ValueKey<int>(count),
            tween: Tween<double>(begin: .94, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                alignment: AlignmentDirectional.centerStart,
                child: child,
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: .18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .07),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.manage_search_rounded,
                          color: colorScheme.onPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'تم عرض $count نتيجة مطابقة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
