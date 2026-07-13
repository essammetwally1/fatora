import 'dart:async';

import 'package:fatora/data/models/invoices_totals.dart';
import 'package:fatora/widgets/home/scroll_to_top.dart';
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
  static const Duration _searchDelay = Duration(milliseconds: 180);
  static const Duration _scrollTopDuration = Duration(milliseconds: 280);

  static const double _scrollTopVisibilityOffset = 260.0;
  static const double _scrollTopTolerance = 2.0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _invoiceListController = ScrollController();

  Timer? _searchDebounce;

  String _searchQuery = '';

  int? _lastFilterVersion;
  String? _lastFilterQuery;
  List<InvoiceModel> _filteredInvoices = const [];

  int? _lastTotalsVersion;
  InvoicesTotals? _totals;

  bool _showScrollTopButton = false;
  bool _scrollToTopScheduled = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    _invoiceListController.addListener(_onInvoiceListScrolled);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InvoiceProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _invoiceListController
      ..removeListener(_onInvoiceListScrolled)
      ..dispose();

    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onInvoiceListScrolled() {
    if (!_invoiceListController.hasClients) return;

    final position = _invoiceListController.position;

    if (!position.hasPixels) return;

    final shouldShow = position.pixels > _scrollTopVisibilityOffset;

    if (shouldShow == _showScrollTopButton) return;

    setState(() {
      _showScrollTopButton = shouldShow;
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(_searchDelay, () {
      if (!mounted) return;

      final nextQuery = SearchUtils.normalize(_searchController.text);

      if (nextQuery == _searchQuery) return;

      setState(() {
        _searchQuery = nextQuery;
      });

      _requestInvoicesScrollToTop();
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

    final filteredInvoices = _getFilteredInvoices(
      invoices: invoices,
      version: version,
    );

    final totals = _getTotals(invoices: invoices, version: version);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const HomeAppBar(),
        floatingActionButton: Selector<InvoiceProvider, bool>(
          selector: (_, provider) => provider.isMutating,
          builder: (context, isMutating, _) {
            return LiquidFloatingActionButton(
              onPressed: () {
                if (isMutating) return;
                _openInvoiceNameDialog(context);
              },
              label: isMutating ? 'جاري الحفظ...' : 'فاتورة جديدة',
              icon: isMutating
                  ? Icons.hourglass_top_rounded
                  : Icons.add_rounded,
            );
          },
        ),
        body: Stack(
          children: [
            HomeBody(
              invoices: invoices,
              visibleInvoices: filteredInvoices,
              totals: totals,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onClearSearch: _clearSearch,
              onEditInvoice: (invoice) {
                _openInvoiceNameDialog(context, invoice: invoice);
              },
              invoiceListController: _invoiceListController,
            ),
            ScrollToTopButton(
              visible: _showScrollTopButton,
              onPressed: _requestInvoicesScrollToTop,
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) return;

    _searchDebounce?.cancel();
    _searchController.clear();

    if (_searchQuery.isEmpty) {
      _requestInvoicesScrollToTop();
      return;
    }

    setState(() {
      _searchQuery = '';
    });

    _requestInvoicesScrollToTop();
  }

  void _requestInvoicesScrollToTop() {
    if (!mounted) return;

    if (_scrollToTopScheduled) return;

    _scrollToTopScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTopScheduled = false;

      if (!mounted) return;

      _scrollInvoicesToTop();
    });
  }

  void _scrollInvoicesToTop() {
    if (!_invoiceListController.hasClients) return;

    final position = _invoiceListController.position;

    if (!position.hasPixels) return;

    final target = position.minScrollExtent;
    final current = position.pixels;

    if ((current - target).abs() <= _scrollTopTolerance) {
      if (_showScrollTopButton) {
        setState(() => _showScrollTopButton = false);
      }
      return;
    }

    unawaited(
      _invoiceListController.animateTo(
        target,
        duration: _scrollTopDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  List<InvoiceModel> _getFilteredInvoices({
    required List<InvoiceModel> invoices,
    required int version,
  }) {
    if (_lastFilterVersion == version && _lastFilterQuery == _searchQuery) {
      return _filteredInvoices;
    }

    if (_searchQuery.isEmpty) {
      _filteredInvoices = invoices;
    } else {
      _filteredInvoices = invoices
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
    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) return;

    final title = await showDialog<String>(
      context: context,
      builder: (_) => InvoiceNameDialog(initialTitle: invoice?.title),
    );

    if (title == null || !context.mounted) return;

    final success = invoice == null
        ? await provider.createInvoice(title)
        : await provider.updateInvoiceTitle(invoice: invoice, title: title);

    if (!context.mounted) return;

    if (success) {
      if (invoice == null) {
        _requestInvoicesScrollToTop();
      }
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الفاتورة، حاول مرة أخرى')),
      );
  }
}
