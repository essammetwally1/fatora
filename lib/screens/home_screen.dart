import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/search_utils.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_body.dart';
import '../widgets/home/invoice_name_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    final nextQuery = SearchUtils.normalize(_searchController.text);

    if (nextQuery == _searchQuery) return;

    setState(() {
      _searchQuery = nextQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = context.watch<InvoiceProvider>().invoices;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const HomeAppBar(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openInvoiceNameDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('فاتورة جديدة'),
        ),
        body: HomeBody(
          invoices: invoices,
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
