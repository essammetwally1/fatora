import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/invoice_item_model.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import 'app_text_form_field.dart';

Future<void> showInvoiceItemSheet(
  BuildContext context, {
  required InvoiceModel invoice,
  int? itemIndex,
}) {
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

  late final TextEditingController _customerController;
  late final TextEditingController _itemController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;

  late bool _isPaid;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _customerController = TextEditingController(
      text: existing?.customerName ?? '',
    );

    _itemController = TextEditingController(text: existing?.itemName ?? '');

    _priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toString(),
    );

    _noteController = TextEditingController(text: existing?.note ?? '');

    _isPaid = existing?.isPaid ?? false;
  }

  @override
  void dispose() {
    _customerController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                AppTextFormField(
                  controller: _customerController,
                  label: 'اسم العميل',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'اسم العميل مطلوب';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                AppTextFormField(
                  controller: _itemController,
                  label: 'اسم الصنف (اختياري)',
                  icon: Icons.inventory_2_outlined,
                  textInputAction: TextInputAction.next,
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
                    if (price == null || price <= 0) {
                      return 'السعر مطلوب ويجب أن يكون أكبر من صفر';
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

                const SizedBox(height: 12),

                CheckboxListTile(
                  value: _isPaid,
                  title: const Text('تم الدفع'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      _isPaid = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _saveItem,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditing ? 'حفظ التعديل' : 'حفظ العنصر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final item = InvoiceItemModel(
      date: widget.existing?.date,
      customerName: _customerController.text.trim(),
      itemName: _nullableText(_itemController.text),
      price: _parsePrice(_priceController.text)!,
      note: _nullableText(_noteController.text),
      isPaid: _isPaid,
    );

    final provider = context.read<InvoiceProvider>();

    if (widget.itemIndex == null) {
      await provider.addItem(invoice: widget.invoice, item: item);
    } else {
      await provider.updateItem(
        invoice: widget.invoice,
        index: widget.itemIndex!,
        item: item,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}
