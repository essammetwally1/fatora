import 'package:flutter/material.dart';

import '../../core/utils/number_input_utils.dart';
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
  static const int _maxNameLength = 100;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  late final FocusNode _nameFocusNode;
  late final FocusNode _priceFocusNode;

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

    _nameFocusNode = FocusNode();
    _priceFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();

    _nameFocusNode.dispose();
    _priceFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(_isEditing ? 'تعديل صنف' : 'إضافة صنف للقائمة'),
        content: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                autofocus: true,
                enabled: !_isSubmitting,
                maxLength: _maxNameLength,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'اسم الصنف',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  counterText: '',
                ),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  _priceFocusNode.requestFocus();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                focusNode: _priceFocusNode,
                enabled: !_isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                inputFormatters: const [PositiveDecimalTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _validatePrice,
                onFieldSubmitted: (_) {
                  _submit();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    final cleanName = value?.trim() ?? '';

    if (cleanName.isEmpty) {
      return 'اسم الصنف مطلوب';
    }

    if (cleanName.length > _maxNameLength) {
      return 'اسم الصنف طويل جدًا';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    final price = _parsePrice(value ?? '');

    if (price == null) {
      return 'اكتب سعرًا صحيحًا';
    }

    if (price <= 0) {
      return 'السعر يجب أن يكون أكبر من صفر';
    }

    return null;
  }

  void _submit() {
    if (_isSubmitting) return;

    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final cleanName = _nameController.text.trim();
    final price = _parsePrice(_priceController.text);

    if (cleanName.isEmpty || price == null || price <= 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(
      context,
    ).pop(FixedMenuItemInput(name: cleanName, price: price));
  }

  double? _parsePrice(String value) => NumberInputUtils.parseAmount(value);

  String _cleanNumber(double value) => NumberInputUtils.formatForInput(value);
}
