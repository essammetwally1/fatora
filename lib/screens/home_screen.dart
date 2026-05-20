import 'dart:async';

import 'package:fatora/data/models/invoices_totals.dart';
import 'package:fatora/widgets/liquid_floating_action_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/search_utils.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_body.dart';
import '../widgets/home/invoice_name_dialog.dart';

class _InvoicesState {
  final List<InvoiceModel> invoices;
  final int version;

  const _InvoicesState({required this.invoices, required this.version});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InvoicesState &&
            runtimeType == other.runtimeType &&
            identical(invoices, other.invoices) &&
            version == other.version;
  }

  @override
  int get hashCode => Object.hash(invoices, version);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  String _searchQuery = '';

  int? _lastSortVersion;
  List<InvoiceModel> _sortedInvoices = const [];

  int? _lastFilterVersion;
  String? _lastFilterQuery;
  List<InvoiceModel> _filteredInvoices = const [];

  int? _lastTotalsVersion;
  InvoicesTotals? _totals;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;

      final nextQuery = SearchUtils.normalize(_searchController.text);

      if (nextQuery == _searchQuery) return;

      setState(() {
        _searchQuery = nextQuery;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = context.select<InvoiceProvider, _InvoicesState>(
      (provider) => _InvoicesState(
        invoices: provider.invoices,
        version: provider.version,
      ),
    );

    final invoices = invoicesState.invoices;
    final version = invoicesState.version;

    final sortedInvoices = _getSortedInvoices(
      invoices: invoices,
      version: version,
    );

    final filteredInvoices = _getFilteredInvoices(
      sortedInvoices: sortedInvoices,
      version: version,
    );

    final totals = _getTotals(invoices: invoices, version: version);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const HomeAppBar(),
        floatingActionButton: LiquidFloatingActionButton(
          onPressed: () => _openInvoiceNameDialog(context),
          label: 'فاتورة جديدة',
          icon: Icons.add_rounded,
        ),
        body: HomeBody(
          invoices: invoices,
          visibleInvoices: filteredInvoices,
          totals: totals,
          searchController: _searchController,
          searchQuery: _searchQuery,
          onClearSearch: _searchController.clear,
          onEditInvoice: (invoice) {
            _openInvoiceNameDialog(context, invoice: invoice);
          },
        ),
      ),
    );
  }

  List<InvoiceModel> _getSortedInvoices({
    required List<InvoiceModel> invoices,
    required int version,
  }) {
    if (_lastSortVersion == version) {
      return _sortedInvoices;
    }

    final sorted = List<InvoiceModel>.of(invoices, growable: false);

    sorted.sort((a, b) {
      final aKey = a.key;
      final bKey = b.key;

      if (aKey is int && bKey is int) {
        return bKey.compareTo(aKey);
      }

      return 0;
    });

    _lastSortVersion = version;
    _sortedInvoices = sorted;

    return _sortedInvoices;
  }

  List<InvoiceModel> _getFilteredInvoices({
    required List<InvoiceModel> sortedInvoices,
    required int version,
  }) {
    if (_lastFilterVersion == version && _lastFilterQuery == _searchQuery) {
      return _filteredInvoices;
    }

    if (_searchQuery.isEmpty) {
      _filteredInvoices = sortedInvoices;
    } else {
      _filteredInvoices = sortedInvoices
          .where((invoice) {
            final title = SearchUtils.normalize(invoice.title);
            return title.contains(_searchQuery);
          })
          .toList(growable: false);
    }

    _lastFilterVersion = version;
    _lastFilterQuery = _searchQuery;

    return _filteredInvoices;
  }

  InvoicesTotals _getTotals({
    required List<InvoiceModel> invoices,
    required int version,
  }) {
    if (_lastTotalsVersion == version && _totals != null) {
      return _totals!;
    }

    _lastTotalsVersion = version;
    _totals = InvoicesTotals.fromInvoices(invoices);

    return _totals!;
  }

  Future<void> _openInvoiceNameDialog(
    BuildContext context, {
    InvoiceModel? invoice,
  }) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => InvoiceNameDialog(initialTitle: invoice?.title),
    );

    if (title == null || !context.mounted) return;

    final provider = context.read<InvoiceProvider>();

    if (invoice == null) {
      await provider.createInvoice(title);
    } else {
      await provider.updateInvoiceTitle(invoice: invoice, title: title);
    }
  }
}
