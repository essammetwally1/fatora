import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/fixed_menu_item_model.dart';

class FixedMenuItemInput {
  final String name;
  final double price;

  const FixedMenuItemInput({required this.name, required this.price});
}

class FixedMenuItemDialog extends StatefulWidget {
  final FixedMenuItemModel? initialItem;

  const FixedMenuItemDialog({super.key, this.initialItem});

  @override
  State<FixedMenuItemDialog> createState() => _FixedMenuItemDialogState();
}

class _FixedMenuItemDialogState extends State<FixedMenuItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  bool _isSubmitting = false;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();

    final item = widget.initialItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(
      text: item == null ? '' : _cleanNumber(item.price),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditing ? 'تعديل صنف' : 'إضافة صنف للقائمة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم الصنف',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _validatePrice,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isEditing ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم الصنف مطلوب';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    final price = _parsePrice(value ?? '');

    if (price == null) return 'اكتب سعر صحيح';
    if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';

    return null;
  }

  void _submit() {
    if (_isSubmitting) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final price = _parsePrice(_priceController.text);
    if (price == null || price <= 0) return;

    setState(() => _isSubmitting = true);

    FocusScope.of(context).unfocus();

    Navigator.pop(
      context,
      FixedMenuItemInput(name: _nameController.text.trim(), price: price),
    );
  }

  double? _parsePrice(String value) {
    final clean = value.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;

    final parsed = double.tryParse(clean);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;

    return parsed;
  }

  String _cleanNumber(double value) {
    if (value <= 0) return '';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}
