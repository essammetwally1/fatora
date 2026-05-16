import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/formatters.dart';
import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    context.watch<InvoiceProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(invoice.title),
          actions: [
            IconButton(
              tooltip: 'تعديل اسم الفاتورة',
              onPressed: () => _showEditInvoiceNameDialog(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showItemSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة عنصر'),
        ),
        body: Column(
          children: [
            _TotalsHeader(invoice: invoice),
            Expanded(
              child: invoice.items.isEmpty
                  ? _EmptyItemsState(color: colorScheme.primary)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: invoice.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = invoice.items[index];

                        return Dismissible(
                          key: ValueKey(
                            '${item.date.microsecondsSinceEpoch}-$index',
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteItem(context),
                          background: const _DeleteBackground(),
                          onDismissed: (_) {
                            context.read<InvoiceProvider>().deleteItem(
                              invoice: invoice,
                              index: index,
                            );
                          },
                          child: _InvoiceItemTile(
                            item: item,
                            onEdit: () =>
                                _showItemSheet(context, itemIndex: index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditInvoiceNameDialog(BuildContext context) async {
    final controller = TextEditingController(text: invoice.title);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل اسم الفاتورة'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم الفاتورة'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'اسم الفاتورة مطلوب';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(dialogContext);
                await context.read<InvoiceProvider>().updateInvoiceTitle(
                  invoice: invoice,
                  title: controller.text,
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<bool?> _confirmDeleteItem(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف العنصر'),
        content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
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
  }

  Future<void> _showItemSheet(BuildContext context, {int? itemIndex}) async {
    final existing = itemIndex == null ? null : invoice.items[itemIndex];
    final rootContext = context;
    final customerController = TextEditingController(
      text: existing?.customerName ?? '',
    );
    final itemController = TextEditingController(
      text: existing?.itemName ?? '',
    );
    final priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toString(),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    final formKey = GlobalKey<FormState>();
    bool isPaid = existing?.isPaid ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        existing == null ? 'إضافة عنصر' : 'تعديل عنصر',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _ArabicTextFormField(
                        controller: customerController,
                        label: 'اسم العميل',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'اسم العميل مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _ArabicTextFormField(
                        controller: itemController,
                        label: 'اسم الصنف (اختياري)',
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(height: 12),
                      _ArabicTextFormField(
                        controller: priceController,
                        label: 'السعر',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: (value) {
                          final price = _parsePrice(value ?? '');
                          if (price == null || price <= 0) {
                            return 'السعر مطلوب ويجب أن يكون أكبر من صفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _ArabicTextFormField(
                        controller: noteController,
                        label: 'ملاحظات (اختياري)',
                        icon: Icons.edit_note_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: isPaid,
                        title: const Text('تم الدفع'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setModalState(() => isPaid = value ?? false);
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final item = InvoiceItemModel(
                            date: existing?.date,
                            customerName: customerController.text.trim(),
                            itemName: _nullableText(itemController.text),
                            price: _parsePrice(priceController.text)!,
                            note: _nullableText(noteController.text),
                            isPaid: isPaid,
                          );

                          Navigator.pop(sheetContext);
                          final provider = rootContext.read<InvoiceProvider>();

                          if (itemIndex == null) {
                            await provider.addItem(
                              invoice: invoice,
                              item: item,
                            );
                          } else {
                            await provider.updateItem(
                              invoice: invoice,
                              index: itemIndex,
                              item: item,
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          existing == null ? 'حفظ العنصر' : 'حفظ التعديل',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    customerController.dispose();
    itemController.dispose();
    priceController.dispose();
    noteController.dispose();
  }

  static String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}

class _TotalsHeader extends StatelessWidget {
  final InvoiceModel invoice;

  const _TotalsHeader({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: .78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TotalBox(
              title: 'الإجمالي',
              value: Formatters.formatMoney(invoice.total),
              icon: Icons.receipt_long,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TotalBox(
              title: 'المدفوع',
              value: Formatters.formatMoney(invoice.paidTotal),
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TotalBox(
              title: 'المتبقي',
              value: Formatters.formatMoney(invoice.unpaidTotal),
              icon: Icons.pending_actions_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TotalBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceItemTile extends StatelessWidget {
  final InvoiceItemModel item;
  final VoidCallback onEdit;

  const _InvoiceItemTile({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = item.isPaid ? Colors.green : Colors.orange;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.isPaid ? 'تم الدفع' : 'لم يتم الدفع',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(title: 'الصنف', value: item.displayItemName),
              const SizedBox(height: 8),
              _InfoRow(
                title: 'التاريخ',
                value: Formatters.formatDate(item.date),
              ),
              const SizedBox(height: 8),
              _InfoRow(title: 'ملاحظات', value: item.displayNote),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  Formatters.formatMoney(item.price),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _ArabicTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ArabicTextFormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  final Color color;

  const _EmptyItemsState({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_outlined, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              'لا توجد عناصر بعد',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'أضف اسم العميل والسعر، وباقي البيانات اختيارية وسيتم حفظ تاريخ اليوم تلقائياً.',
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
