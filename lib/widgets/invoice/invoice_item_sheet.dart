import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/invoice_item_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../providers/invoice_provider.dart';
import 'app_text_form_field.dart';

Future<void> showInvoiceItemSheet(
  BuildContext context, {
  required InvoiceModel invoice,
  int? itemIndex,
}) {
  if (!invoice.canEditItems) {
    return Future.value();
  }
  final existing = itemIndex == null ? null : invoice.items[itemIndex];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) {
      return _InvoiceItemSheetContent(
        invoice: invoice,
        existing: existing,
        itemIndex: itemIndex,
      );
    },
  );
}

class _InvoiceItemSheetContent extends StatefulWidget {
  final InvoiceModel invoice;
  final InvoiceItemModel? existing;
  final int? itemIndex;

  const _InvoiceItemSheetContent({
    required this.invoice,
    required this.existing,
    required this.itemIndex,
  });

  @override
  State<_InvoiceItemSheetContent> createState() =>
      _InvoiceItemSheetContentState();
}

class _InvoiceItemSheetContentState extends State<_InvoiceItemSheetContent> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _itemController = TextEditingController(text: existing?.itemName ?? '');
    _priceController = TextEditingController(
      text: existing == null ? '' : _cleanNumber(existing.price),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
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
                  _isEditing ? 'تعديل عنصر' : 'إضافة عنصر',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  controller: _itemController,
                  label: 'اسم الصنف',
                  icon: Icons.inventory_2_outlined,
                  textInputAction: TextInputAction.next,
                  autofocus: !_isEditing,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'اسم الصنف مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextFormField(
                  controller: _priceController,
                  label: 'السعر',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (value) {
                    final price = _parsePrice(value ?? '');

                    if (price == null) {
                      return 'اكتب سعر صحيح';
                    }

                    if (price <= 0) {
                      return 'السعر يجب أن يكون أكبر من صفر';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextFormField(
                  controller: _noteController,
                  label: 'ملاحظات (اختياري)',
                  icon: Icons.edit_note_outlined,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveItem,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? 'حفظ التعديل' : 'حفظ العنصر'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final price = _parsePrice(_priceController.text)!;

    setState(() => _saving = true);

    final item = InvoiceItemModel(
      date: widget.existing?.date,
      itemName: _itemController.text.trim(),
      price: price,
      note: _nullableText(_noteController.text),

      // Payment is now controlled by InvoicePaymentSummaryCard only.
      isPaid: false,
      paidAmount: 0.0,
    );

    final provider = context.read<InvoiceProvider>();

    final saved = widget.itemIndex == null
        ? await provider.addItem(invoice: widget.invoice, item: item)
        : await provider.updateItem(
            invoice: widget.invoice,
            index: widget.itemIndex!,
            item: item,
          );

    if (!mounted) return;

    if (!saved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ العنصر، حاول مرة أخرى')),
      );
      return;
    }

    Navigator.pop(context);
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parsePrice(String value) {
    final clean = value.trim().replaceAll(',', '.');

    if (clean.isEmpty) return null;

    final parsed = double.tryParse(clean);

    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return null;
    }

    return parsed;
  }

  String _cleanNumber(double value) {
    if (value <= 0) return '';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}
