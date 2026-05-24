import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final ValueListenable<bool> searchVisibleListenable;
  final ValueChanged<bool> onSearchVisibilityChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<InvoiceModel> onEditInvoice;

  const HomeBody({
    super.key,
    required this.invoices,
    required this.visibleInvoices,
    required this.totals,
    required this.searchController,
    required this.searchQuery,
    required this.searchVisibleListenable,
    required this.onSearchVisibilityChanged,
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

        ValueListenableBuilder<bool>(
          valueListenable: searchVisibleListenable,
          builder: (context, isVisible, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isVisible
                  ? CustomerSearchField(
                      key: const ValueKey('visible-search-field'),
                      controller: searchController,
                      enabled: true,
                      onClear: onClearSearch,
                      labelText: 'بحث في الفواتير',
                      enabledHintText: 'اكتب اسم الفاتورة فقط',
                      disabledHintText: 'أضف فواتير أولاً لتفعيل البحث',
                    )
                  : const SizedBox(
                      key: ValueKey('hidden-search-field'),
                      height: 0,
                    ),
            );
          },
        ),

        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.idle) {
                  onSearchVisibilityChanged(true);
                } else {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onSearchVisibilityChanged(false);
                }
              }

              if (notification is ScrollEndNotification) {
                onSearchVisibilityChanged(true);
              }

              return false;
            },
            child: InvoicesList(
              invoices: visibleInvoices,
              totalInvoiceCount: invoices.length,
              hasSearchQuery: hasSearchQuery,
              onEditInvoice: onEditInvoice,
            ),
          ),
        ),

        if (hasSearchQuery && visibleInvoices.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                'تم عرض ${visibleInvoices.length} نتيجة مطابقة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
