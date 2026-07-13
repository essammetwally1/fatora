import 'package:fatora/widgets/home/invoice_card.dart';
import 'package:fatora/widgets/home/invoice_day_header.dart';
import 'package:fatora/widgets/home/invoice_pdf_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../screens/invoice_details_screen.dart';
import '../nosearch_result_state.dart';
import 'invoices_section_header.dart';

class InvoicesList extends StatefulWidget {
  final List<InvoiceModel> invoices;
  final int totalInvoiceCount;
  final bool hasSearchQuery;
  final ScrollController scrollController;
  final ValueChanged<InvoiceModel> onEditInvoice;

  const InvoicesList({
    super.key,
    required this.invoices,
    required this.totalInvoiceCount,
    required this.hasSearchQuery,
    required this.scrollController,
    required this.onEditInvoice,
  });

  @override
  State<InvoicesList> createState() => _InvoicesListState();
}

class _InvoicesListState extends State<InvoicesList> {
  late List<_InvoiceListEntry> _entries;

  @override
  void initState() {
    super.initState();

    _entries = _InvoiceListEntry.buildEntries(widget.invoices);
  }

  @override
  void didUpdateWidget(covariant InvoicesList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // InvoiceProvider creates a new unmodifiable list whenever data changes.
    // Therefore, identity comparison safely avoids rebuilding grouped entries
    // during unrelated parent rebuilds.
    if (!identical(oldWidget.invoices, widget.invoices)) {
      _entries = _InvoiceListEntry.buildEntries(widget.invoices);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invoices.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),

      // Invoice cards do not require off-screen state retention.
      addAutomaticKeepAlives: false,

      itemCount: _entries.length + 1,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return InvoicesSectionHeader(
            invoiceCount: widget.hasSearchQuery
                ? widget.invoices.length
                : widget.totalInvoiceCount,
          );
        }

        final entry = _entries[index - 1];

        if (entry.isHeader) {
          return InvoiceDayHeader(
            key: ValueKey<String>(
              'invoice-day-'
              '${entry.day!.millisecondsSinceEpoch}-'
              '${entry.isLegacy}',
            ),
            date: entry.day!,
            isLegacy: entry.isLegacy,
            invoiceCount: entry.count,
          );
        }

        final invoice = entry.invoice!;

        return InvoiceCard(
          key: _invoiceKey(invoice),
          invoice: invoice,
          onTap: () {
            _openInvoiceDetails(context, invoice);
          },
          onLongPress: () {
            _deleteInvoiceByLongPress(context, invoice);
          },
          onEdit: () {
            widget.onEditInvoice(invoice);
          },
          onExport: () {
            _showInvoicePdfActions(context, invoice);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Keep the controller attached even when no invoices are visible.
    // This lets HomeScreen reset the scroll position and hide its
    // scroll-to-top button correctly.
    return CustomScrollView(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: NoSearchResultsState(
            color: colorScheme.primary,
            title: widget.hasSearchQuery
                ? 'لا توجد فواتير مطابقة'
                : 'لا توجد فواتير بعد',
            message: widget.hasSearchQuery
                ? 'جرّب البحث باسم فاتورة مختلف'
                : 'ابدأ بإضافة أول فاتورة',
          ),
        ),
      ],
    );
  }

  Key _invoiceKey(InvoiceModel invoice) {
    final invoiceKey = invoice.key;

    if (invoiceKey != null) {
      return ValueKey<Object>(invoiceKey);
    }

    // Unlike index-based keys, ObjectKey remains stable when filtering
    // or deleting another invoice from the list.
    return ObjectKey(invoice);
  }

  Future<void> _openInvoiceDetails(
    BuildContext context,
    InvoiceModel invoice,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (detailsContext) {
          return InvoiceDetailsScreen(
            invoice: invoice,
            onExport: (selectedInvoice) {
              _showInvoicePdfActions(detailsContext, selectedInvoice);
            },
          );
        },
      ),
    );
  }

  static Future<void> _showInvoicePdfActions(
    BuildContext context,
    InvoiceModel invoice,
  ) {
    return InvoicePdfActionsSheet.show(context: context, invoice: invoice);
  }

  Future<void> _deleteInvoiceByLongPress(
    BuildContext context,
    InvoiceModel invoice,
  ) async {
    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      _showMessage(
        context,
        provider.lastErrorMessage ?? 'توجد عملية أخرى قيد التنفيذ',
      );
      return;
    }

    final invoiceKey = invoice.key;

    // Use the latest provider instance in case the invoice changed
    // since this list item was built.
    final currentInvoice = invoiceKey == null
        ? invoice
        : provider.invoiceByKey(invoiceKey) ?? invoice;

    final confirmed = await _confirmDeleteInvoice(context, currentInvoice);

    if (confirmed != true || !context.mounted) {
      return;
    }

    final deleted = await provider.deleteInvoice(currentInvoice);

    if (!context.mounted) {
      return;
    }

    if (!deleted) {
      _showMessage(
        context,
        provider.lastErrorMessage ?? 'تعذر حذف الفاتورة، حاول مرة أخرى',
      );
    }
  }

  Future<bool?> _confirmDeleteInvoice(
    BuildContext context,
    InvoiceModel invoice,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            scrollable: true,
            title: const Text('حذف الفاتورة'),
            content: Text(
              'هل أنت متأكد من حذف '
              '"${invoice.displayTitle}"؟\n\n'
              'سيتم حذف جميع العناصر المرتبطة بها.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InvoiceListEntry {
  final DateTime? day;
  final bool isLegacy;
  final int count;
  final InvoiceModel? invoice;

  const _InvoiceListEntry.header({
    required this.day,
    required this.isLegacy,
    required this.count,
  }) : invoice = null;

  const _InvoiceListEntry.invoice(this.invoice)
    : day = null,
      isLegacy = false,
      count = 0;

  bool get isHeader => day != null;

  static List<_InvoiceListEntry> buildEntries(List<InvoiceModel> invoices) {
    if (invoices.isEmpty) {
      return const [];
    }

    final entries = <_InvoiceListEntry>[];

    var index = 0;

    while (index < invoices.length) {
      final firstInvoice = invoices[index];
      final day = _startOfDay(firstInvoice.listDate);
      final isLegacy = firstInvoice.isLegacyDate;

      var groupEnd = index + 1;

      while (groupEnd < invoices.length) {
        final nextInvoice = invoices[groupEnd];

        final sameDay = Formatters.isSameDay(nextInvoice.listDate, day);

        final sameLegacyState = nextInvoice.isLegacyDate == isLegacy;

        if (!sameDay || !sameLegacyState) {
          break;
        }

        groupEnd++;
      }

      entries.add(
        _InvoiceListEntry.header(
          day: day,
          isLegacy: isLegacy,
          count: groupEnd - index,
        ),
      );

      for (var invoiceIndex = index; invoiceIndex < groupEnd; invoiceIndex++) {
        entries.add(_InvoiceListEntry.invoice(invoices[invoiceIndex]));
      }

      index = groupEnd;
    }

    return List<_InvoiceListEntry>.unmodifiable(entries);
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
