import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/invoice_card.dart';
import 'invoice_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فواتيري'),
          actions: [
            IconButton(
              tooltip: 'تغيير المظهر',
              onPressed: context.read<SettingsProvider>().toggleTheme,
              icon: Icon(
                context.watch<SettingsProvider>().isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openInvoiceNameDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('فاتورة جديدة'),
        ),
        body: provider.invoices.isEmpty
            ? _EmptyState(color: colorScheme.primary)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: provider.invoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final invoice = provider.invoices[index];

                  return Dismissible(
                    key: ValueKey(invoice.key ?? index),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDeleteInvoice(context),
                    background: const _DeleteBackground(),
                    onDismissed: (_) {
                      context.read<InvoiceProvider>().deleteInvoice(index);
                    },
                    child: InvoiceCard(
                      invoice: invoice,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                InvoiceDetailsScreen(invoice: invoice),
                          ),
                        );
                      },
                      onEdit: () =>
                          _openInvoiceNameDialog(context, invoice: invoice),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<bool?> _confirmDeleteInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الفاتورة'),
          content: const Text(
            'هل أنت متأكد من حذف هذه الفاتورة؟ سيتم حذف كل العناصر المرتبطة بها.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
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
      builder: (_) => _InvoiceNameDialog(initialTitle: invoice?.title),
    );

    if (title == null || !context.mounted) {
      return;
    }

    final provider = context.read<InvoiceProvider>();

    if (invoice == null) {
      await provider.createInvoice(title);
    } else {
      await provider.updateInvoiceTitle(invoice: invoice, title: title);
    }
  }
}

class _InvoiceNameDialog extends StatefulWidget {
  final String? initialTitle;

  const _InvoiceNameDialog({this.initialTitle});

  @override
  State<_InvoiceNameDialog> createState() => _InvoiceNameDialogState();
}

class _InvoiceNameDialogState extends State<_InvoiceNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  bool get _isEditing => widget.initialTitle != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditing ? 'تعديل اسم الفاتورة' : 'إنشاء فاتورة'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'اسم الفاتورة',
              hintText: 'مثال: حسابات محمد',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'اسم الفاتورة مطلوب';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? 'حفظ' : 'إنشاء'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.pop(context, _controller.text.trim());
  }
}

class _EmptyState extends StatelessWidget {
  final Color color;

  const _EmptyState({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير حتى الآن',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على زر “فاتورة جديدة” لإنشاء فاتورة بقيمة ابتدائية 0 ج.م.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
