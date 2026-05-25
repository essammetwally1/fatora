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

    final hasSearchQuery = searchQuery.isNotEmpty;

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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 108, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(visibleInvoices.length),
                  tween: Tween(begin: .94, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      alignment: AlignmentDirectional.centerStart,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          colorScheme.primary.withValues(alpha: .14),
                          colorScheme.primary.withValues(alpha: .06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: .16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: .08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        8,
                        6,
                        12,
                        6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: .22,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                              'تم عرض ${visibleInvoices.length} نتيجة مطابقة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
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
      ],
    );
  }
}
