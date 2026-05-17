import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/formatters.dart';
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
    final invoices = provider.invoices;
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
              icon: Selector<SettingsProvider, bool>(
                selector: (_, settings) => settings.isDark,
                builder: (_, isDark, _) => Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openInvoiceNameDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('فاتورة جديدة'),
        ),
        body: invoices.isEmpty
            ? _EmptyState(color: colorScheme.primary)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: invoices.length + 2,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _HomeTotalsSection(
                      totals: _InvoicesTotals.fromInvoices(invoices),
                    );
                  }

                  if (index == 1) {
                    return _InvoicesSectionHeader(
                      invoiceCount: invoices.length,
                    );
                  }

                  final invoiceIndex = index - 2;
                  final invoice = invoices[invoiceIndex];

                  return Dismissible(
                    key: ValueKey(invoice.key ?? invoiceIndex),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDeleteInvoice(context),
                    background: const _DeleteBackground(),
                    onDismissed: (_) {
                      context.read<InvoiceProvider>().deleteInvoice(invoice);
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
                      onExport: () => _showPdfExportComingSoon(context),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showPdfExportComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تصدير PDF للطباعة أو الحفظ سيتم إضافته قريباً'),
      ),
    );
  }

  Future<bool?> _confirmDeleteInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
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
        );
      },
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

class _HomeTotalsSection extends StatelessWidget {
  final _InvoicesTotals totals;

  const _HomeTotalsSection({required this.totals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: .82),
            colorScheme.secondary.withValues(alpha: .72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: -24,
            child: _DecorativeCircle(
              size: 76,
              color: Colors.white.withValues(alpha: .10),
            ),
          ),
          Positioned(
            right: -24,
            bottom: -34,
            child: _DecorativeCircle(
              size: 92,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي كل الفواتير',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مجموع أسعار كل العناصر',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                Formatters.formatMoney(totals.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      title: 'الفواتير',
                      value: '${totals.invoiceCount}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStatCard(
                      title: 'العناصر',
                      value: '${totals.itemCount}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoicesSectionHeader extends StatelessWidget {
  final int invoiceCount;

  const _InvoicesSectionHeader({required this.invoiceCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الفواتير',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$invoiceCount فاتورة',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _InvoicesTotals {
  final int invoiceCount;
  final int itemCount;
  final double total;

  const _InvoicesTotals({
    required this.invoiceCount,
    required this.itemCount,
    required this.total,
  });

  factory _InvoicesTotals.fromInvoices(List<InvoiceModel> invoices) {
    var itemCount = 0;
    var total = 0.0;

    for (final invoice in invoices) {
      for (final item in invoice.items) {
        itemCount++;
        total += item.price;
      }
    }

    return _InvoicesTotals(
      invoiceCount: invoices.length,
      itemCount: itemCount,
      total: total,
    );
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
              hintText: 'مثال: حسابات عصام',
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
