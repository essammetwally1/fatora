import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoices_totals.dart';
import '../common/app_empty_state.dart';
import '../customer_search_field.dart';
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
  final ValueChanged<InvoiceModel> onDeleteInvoice;
  final ScrollController invoiceListController;

  final bool allowCreateInvoice;

  final String emptyTitle;
  final String searchLabelText;

  const HomeBody({
    super.key,
    required this.invoices,
    required this.visibleInvoices,
    required this.totals,
    required this.searchController,
    required this.searchQuery,
    required this.onClearSearch,
    required this.onEditInvoice,
    required this.onDeleteInvoice,
    required this.invoiceListController,
    required this.allowCreateInvoice,
    this.emptyTitle = 'لا توجد فواتير في هذا الشهر',
    this.searchLabelText = 'بحث في فواتير الشهر',
  });

  @override
  Widget build(BuildContext context) {
    final hasInvoices = invoices.isNotEmpty;
    final hasSearchQuery = searchQuery.trim().isNotEmpty;

    final horizontalPadding = Responsive.horizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return ContentWidthLimiter(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.sm,
              horizontalPadding,
              AppSpacing.sm,
            ),
            child: HomeTotalsSection(totals: totals),
          ),
          CustomerSearchField(
            controller: searchController,
            enabled: hasInvoices,
            onClear: onClearSearch,
            labelText: searchLabelText,
            enabledHintText: 'اكتب اسم الفاتورة فقط',
            disabledHintText: 'لا توجد فواتير لتفعيل البحث',
          ),
          Expanded(
            child: hasInvoices
                ? InvoicesList(
                    invoices: visibleInvoices,
                    totalInvoiceCount: invoices.length,
                    hasSearchQuery: hasSearchQuery,
                    scrollController: invoiceListController,
                    onEditInvoice: onEditInvoice,
                    onDeleteInvoice: onDeleteInvoice,
                  )
                : AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: emptyTitle,
                    message: allowCreateInvoice
                        ? 'اضغط على زر “فاتورة جديدة” لإنشاء فاتورة لهذا الشهر.'
                        : 'لا توجد فواتير محفوظة ضمن هذا الشهر.',
                    bottomInset: allowCreateInvoice ? 72 : 0,
                  ),
          ),
          if (hasSearchQuery && visibleInvoices.isNotEmpty)
            _SearchResultIndicator(count: visibleInvoices.length),
        ],
      ),
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
