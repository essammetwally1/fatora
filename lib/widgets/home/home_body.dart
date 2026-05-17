import 'package:fatora/data/models/invoices_totals.dart';
import 'package:flutter/material.dart';

import '../../core/utils/search_utils.dart';
import '../../data/models/invoice_model.dart';
import '../customer_search_field.dart';
import 'home_empty_state.dart';
import 'home_totals_section.dart';
import 'invoices_list.dart';

class HomeBody extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;
  final ValueChanged<InvoiceModel> onEditInvoice;

  const HomeBody({
    super.key,
    required this.invoices,
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

    final sortedInvoices = _sortInvoicesNewestFirst(invoices);
    final filteredInvoices = _filterInvoices(sortedInvoices, searchQuery);
    final hasSearchQuery = searchQuery.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: HomeTotalsSection(
            totals: InvoicesTotals.fromInvoices(invoices),
          ),
        ),
        CustomerSearchField(
          controller: searchController,
          enabled: invoices.isNotEmpty,
          onClear: onClearSearch,
          labelText: 'بحث في الفواتير',
          enabledHintText: 'اكتب اسم الفاتورة فقط',
          disabledHintText: 'أضف فواتير أولاً لتفعيل البحث',
        ),
        Expanded(
          child: InvoicesList(
            invoices: filteredInvoices,
            totalInvoiceCount: invoices.length,
            hasSearchQuery: hasSearchQuery,
            onEditInvoice: onEditInvoice,
          ),
        ),
        if (hasSearchQuery && filteredInvoices.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                'تم عرض ${filteredInvoices.length} نتيجة مطابقة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  List<InvoiceModel> _sortInvoicesNewestFirst(List<InvoiceModel> invoices) {
    final sorted = List<InvoiceModel>.of(invoices);

    sorted.sort((a, b) {
      final aKey = a.key;
      final bKey = b.key;

      if (aKey is int && bKey is int) {
        return bKey.compareTo(aKey);
      }

      return 0;
    });

    return sorted;
  }

  List<InvoiceModel> _filterInvoices(
    List<InvoiceModel> invoices,
    String query,
  ) {
    if (query.isEmpty) return invoices;

    return [
      for (final invoice in invoices)
        if (_invoiceTitleMatchesQuery(invoice, query)) invoice,
    ];
  }

  bool _invoiceTitleMatchesQuery(InvoiceModel invoice, String query) {
    final title = SearchUtils.normalize(invoice.title);
    return title.contains(query);
  }
}
