import 'dart:async';

import 'package:fatora/core/utils/app_toast.dart';
import 'package:fatora/core/utils/ui_feed_back_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/search_utils.dart';
import '../data/models/invoice_model.dart';
import '../data/models/invoice_month_key.dart';
import '../data/models/invoice_month_snapshot.dart';
import '../data/models/invoices_totals.dart';
import '../providers/invoice_provider.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_body.dart';
import '../widgets/home/invoice_name_dialog.dart';
import '../widgets/home/month_history_drawer.dart';
import '../widgets/home/scroll_to_top.dart';
import '../widgets/liquid_floating_action_button.dart';

class _InvoicesState {
  final List<InvoiceModel> currentInvoices;
  final InvoicesTotals currentTotals;
  final InvoiceMonthKey currentMonth;
  final List<InvoiceMonthSnapshot> months;
  final int version;

  const _InvoicesState({
    required this.currentInvoices,
    required this.currentTotals,
    required this.currentMonth,
    required this.months,
    required this.version,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InvoicesState &&
            identical(currentInvoices, other.currentInvoices) &&
            identical(months, other.months) &&
            currentTotals == other.currentTotals &&
            currentMonth == other.currentMonth &&
            version == other.version;
  }

  @override
  int get hashCode {
    return Object.hash(
      currentInvoices,
      currentTotals,
      currentMonth,
      months,
      version,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration _searchDelay = Duration(milliseconds: 180);

  static const Duration _scrollTopDuration = Duration(milliseconds: 280);

  static const double _scrollTopVisibilityOffset = 260;

  static const double _scrollTopTolerance = 2;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();

  final ScrollController _invoiceListController = ScrollController();

  Timer? _searchDebounce;
  Timer? _monthRolloverTimer;

  String _searchQuery = '';

  int? _lastFilterVersion;
  List<InvoiceModel>? _lastFilterInvoices;
  String? _lastFilterQuery;

  List<InvoiceModel> _filteredInvoices = const [];

  bool _showScrollTopButton = false;
  bool _scrollToTopScheduled = false;
  bool _selectedMonthResetScheduled = false;

  InvoiceMonthKey? _selectedMonth;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _searchController.addListener(_onSearchChanged);

    _invoiceListController.addListener(_onInvoiceListScrolled);

    _scheduleNextMonthRolloverCheck();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = context.read<InvoiceProvider>();

      if (provider.version == 0 && !provider.isLoading) {
        provider.loadInvoices();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _monthRolloverTimer?.cancel();
    _searchDebounce?.cancel();

    _invoiceListController
      ..removeListener(_onInvoiceListScrolled)
      ..dispose();

    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCurrentMonthIfNeeded();
      _scheduleNextMonthRolloverCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = context.select<InvoiceProvider, _InvoicesState>(
      (provider) => _InvoicesState(
        currentInvoices: provider.currentMonthInvoices,
        currentTotals: provider.currentMonthTotals,
        currentMonth: provider.currentMonth,
        months: provider.invoiceMonths,
        version: provider.version,
      ),
    );

    final provider = context.read<InvoiceProvider>();

    final requestedMonth = _selectedMonth ?? invoicesState.currentMonth;

    final historicalSnapshot = requestedMonth == invoicesState.currentMonth
        ? null
        : provider.monthSnapshot(requestedMonth);

    if (_selectedMonth != null && historicalSnapshot == null) {
      _scheduleMissingMonthReset(_selectedMonth!);
    }

    final isCurrentMonth = historicalSnapshot == null;

    final effectiveMonth =
        historicalSnapshot?.month ?? invoicesState.currentMonth;

    final invoices =
        historicalSnapshot?.invoices ?? invoicesState.currentInvoices;

    final totals = historicalSnapshot?.totals ?? invoicesState.currentTotals;

    final filteredInvoices = _getFilteredInvoices(
      invoices: invoices,
      version: invoicesState.version,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,

        // In RTL, drawer is the right-side drawer.
        drawerEnableOpenDragGesture: false,
        drawer: MonthHistoryDrawer(
          months: invoicesState.months,
          selectedMonth: effectiveMonth,
          onMonthSelected: _selectMonth,
        ),

        appBar: HomeAppBar(
          monthLabel: effectiveMonth.labelAr,
          isCurrentMonth: isCurrentMonth,
          onOpenMonthHistory: _openMonthHistoryDrawer,
          onShowCurrentMonth: _showCurrentMonth,
        ),

        floatingActionButton: isCurrentMonth
            ? Selector<InvoiceProvider, bool>(
                selector: (_, provider) {
                  return provider.isMutating;
                },
                builder: (context, isMutating, _) {
                  return LiquidFloatingActionButton(
                    onPressed: () {
                      if (isMutating) {
                        return;
                      }

                      _openInvoiceNameDialog(context);
                    },
                    label: isMutating ? 'جاري الحفظ...' : 'فاتورة جديدة',
                    icon: isMutating
                        ? Icons.hourglass_top_rounded
                        : Icons.add_rounded,
                  );
                },
              )
            : null,

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
              onDeleteInvoice: _confirmAndDeleteInvoice,
              allowCreateInvoice: isCurrentMonth,
              emptyTitle: 'لا توجد فواتير في هذا الشهر',
              searchLabelText: 'بحث في فواتير الشهر',
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

  Future<void> _confirmAndDeleteInvoice(InvoiceModel invoice) async {
    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      AppToast.showInfo(context, message: 'توجد عملية حفظ أخرى قيد التنفيذ');
      return;
    }

    unawaited(HapticFeedback.selectionClick());

    final invoiceKey = invoice.key;

    final currentInvoice = invoiceKey == null
        ? invoice
        : provider.invoiceByKey(invoiceKey) ?? invoice;

    final confirmed = await UiFeedbackUtils.showDeleteInvoiceConfirmation(
      context: context,
      invoiceTitle: currentInvoice.displayTitle,
      itemCount: currentInvoice.itemCount,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final deleted = await provider.deleteInvoice(currentInvoice);

    if (!mounted) {
      return;
    }

    if (deleted) {
      unawaited(HapticFeedback.mediumImpact());

      AppToast.showSuccess(context, message: 'تم حذف الفاتورة بنجاح');

      return;
    }

    unawaited(HapticFeedback.vibrate());

    AppToast.showError(
      context,
      message: provider.lastErrorMessage ?? 'تعذر حذف الفاتورة، حاول مرة أخرى',
    );
  }

  void _scheduleNextMonthRolloverCheck() {
    _monthRolloverTimer?.cancel();

    final now = DateTime.now();

    final nextMonthStart = DateTime(
      now.year,
      now.month + 1,
      1,
    ).add(const Duration(seconds: 1));

    final delay = nextMonthStart.difference(now);

    _monthRolloverTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;

      _refreshCurrentMonthIfNeeded();
      _scheduleNextMonthRolloverCheck();
    });
  }

  void _refreshCurrentMonthIfNeeded() {
    final provider = context.read<InvoiceProvider>();

    final changed = provider.refreshCurrentMonthIfNeeded();

    if (!changed || !mounted) {
      return;
    }

    final selectedMonth = _selectedMonth;

    if (selectedMonth != null &&
        provider.monthSnapshot(selectedMonth) != null) {
      return;
    }

    _clearSearchControllerSilently();

    setState(() {
      _selectedMonth = null;
      _searchQuery = '';
      _invalidateFilterCache();
      _showScrollTopButton = false;
    });

    _requestInvoicesScrollToTop();
  }

  void _scheduleMissingMonthReset(InvoiceMonthKey missingMonth) {
    if (_selectedMonthResetScheduled) {
      return;
    }

    _selectedMonthResetScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedMonthResetScheduled = false;

      if (!mounted || _selectedMonth != missingMonth) {
        return;
      }

      _showCurrentMonth();
    });
  }

  void _openMonthHistoryDrawer() {
    final scaffoldState = _scaffoldKey.currentState;

    if (scaffoldState == null || scaffoldState.isDrawerOpen) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    scaffoldState.openDrawer();
  }

  void _selectMonth(InvoiceMonthKey month) {
    final provider = context.read<InvoiceProvider>();

    final nextSelectedMonth = month == provider.currentMonth ? null : month;

    if (nextSelectedMonth != null &&
        provider.monthSnapshot(nextSelectedMonth) == null) {
      AppToast.showError(
        context,
        message: provider.lastErrorMessage ?? 'لم يعد هذا الشهر متاحًا',
      );
      return;
    }

    if (_selectedMonth == nextSelectedMonth) {
      return;
    }

    _clearSearchControllerSilently();

    setState(() {
      _selectedMonth = nextSelectedMonth;
      _searchQuery = '';
      _showScrollTopButton = false;
      _invalidateFilterCache();
    });

    _requestInvoicesScrollToTop();
  }

  void _showCurrentMonth() {
    if (_selectedMonth == null &&
        _searchQuery.isEmpty &&
        _searchController.text.isEmpty) {
      return;
    }

    _clearSearchControllerSilently();

    setState(() {
      _selectedMonth = null;
      _searchQuery = '';
      _showScrollTopButton = false;
      _invalidateFilterCache();
    });

    _requestInvoicesScrollToTop();
  }

  void _onInvoiceListScrolled() {
    if (!_invoiceListController.hasClients) {
      return;
    }

    final position = _invoiceListController.position;

    if (!position.hasPixels) {
      return;
    }

    final shouldShow = position.pixels > _scrollTopVisibilityOffset;

    if (shouldShow == _showScrollTopButton) {
      return;
    }

    setState(() {
      _showScrollTopButton = shouldShow;
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(_searchDelay, () {
      if (!mounted) return;

      final nextQuery = SearchUtils.normalize(_searchController.text);

      if (nextQuery == _searchQuery) {
        return;
      }

      setState(() {
        _searchQuery = nextQuery;
        _invalidateFilterCache();
      });

      _requestInvoicesScrollToTop();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();

    _clearSearchControllerSilently();

    if (_searchQuery.isEmpty) {
      _requestInvoicesScrollToTop();
      return;
    }

    setState(() {
      _searchQuery = '';
      _invalidateFilterCache();
    });

    _requestInvoicesScrollToTop();
  }

  void _clearSearchControllerSilently() {
    if (_searchController.text.isEmpty) {
      return;
    }

    _searchController.removeListener(_onSearchChanged);

    _searchController.clear();

    _searchController.addListener(_onSearchChanged);
  }

  void _invalidateFilterCache() {
    _lastFilterVersion = null;
    _lastFilterInvoices = null;
    _lastFilterQuery = null;
  }

  void _requestInvoicesScrollToTop() {
    if (!mounted || _scrollToTopScheduled) {
      return;
    }

    _scrollToTopScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTopScheduled = false;

      if (!mounted) return;

      _scrollInvoicesToTop();
    });
  }

  void _scrollInvoicesToTop() {
    if (!_invoiceListController.hasClients) {
      return;
    }

    final position = _invoiceListController.position;

    if (!position.hasPixels) {
      return;
    }

    final target = position.minScrollExtent;

    final current = position.pixels;

    if ((current - target).abs() <= _scrollTopTolerance) {
      if (_showScrollTopButton) {
        setState(() {
          _showScrollTopButton = false;
        });
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
    if (_lastFilterVersion == version &&
        identical(_lastFilterInvoices, invoices) &&
        _lastFilterQuery == _searchQuery) {
      return _filteredInvoices;
    }

    if (_searchQuery.isEmpty) {
      _filteredInvoices = invoices;
    } else {
      _filteredInvoices = invoices
          .where((invoice) {
            final normalizedTitle = SearchUtils.normalize(invoice.title);

            return normalizedTitle.contains(_searchQuery);
          })
          .toList(growable: false);
    }

    _lastFilterVersion = version;
    _lastFilterInvoices = invoices;
    _lastFilterQuery = _searchQuery;

    return _filteredInvoices;
  }

  Future<void> _openInvoiceNameDialog(
    BuildContext context, {
    InvoiceModel? invoice,
  }) async {
    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      return;
    }

    if (invoice == null && _selectedMonth != null) {
      AppToast.showInfo(
        context,
        message: 'ارجع إلى الشهر الحالي لإضافة فاتورة جديدة',
      );
      return;
    }

    InvoiceModel? currentInvoice;

    if (invoice != null) {
      final invoiceKey = invoice.key;

      currentInvoice = invoiceKey == null
          ? invoice
          : provider.invoiceByKey(invoiceKey) ?? invoice;
    }

    final title = await showDialog<String>(
      context: context,
      builder: (_) {
        return InvoiceNameDialog(initialTitle: currentInvoice?.title);
      },
    );

    if (title == null || !context.mounted) {
      return;
    }

    final success = currentInvoice == null
        ? await provider.createInvoice(title)
        : await provider.updateInvoiceTitle(
            invoice: currentInvoice,
            title: title,
          );

    if (!context.mounted) {
      return;
    }

    if (success) {
      if (currentInvoice == null) {
        _requestInvoicesScrollToTop();
      }

      return;
    }

    AppToast.showError(
      context,
      message: provider.lastErrorMessage ?? 'تعذر حفظ الفاتورة، حاول مرة أخرى',
    );
  }
}
