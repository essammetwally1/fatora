import 'package:fatora/widgets/menu/fixed_menu_quick_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/fixed_menu_item_model.dart';
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

  if (itemIndex != null &&
      (itemIndex < 0 || itemIndex >= invoice.items.length)) {
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;

  bool _saving = false;

  FixedMenuItemModel? _selectedMenuItem;
  Object? _quickAddingKey;

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
                const _SheetDragHandle(),
                const SizedBox(height: 18),
                Text(
                  _isEditing ? 'تعديل عنصر' : 'إضافة عنصر',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                FixedMenuQuickPicker(
                  enabled: !_saving,
                  onSelected: _applyFixedMenuItem,

                  // Quick add is only for creating a new item.
                  // When editing an existing item, user should save changes manually.
                  onQuickAdd: _isEditing ? null : _quickAddFixedMenuItem,
                  quickAddingKey: _quickAddingKey,
                ),

                const SizedBox(height: 12),
                AppTextFormField(
                  controller: _itemController,
                  label: 'اسم الصنف',
                  icon: Icons.inventory_2_outlined,
                  textInputAction: TextInputAction.next,

                  // Better UX:
                  // In create mode, let user see/pick from fixed menu first.
                  // In edit mode, focus field because user likely wants to edit.
                  autofocus: _isEditing,
                  validator: _validateItemName,
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
                  inputFormatters: const [_PositiveDecimalTextInputFormatter()],
                  validator: _validatePrice,
                ),
                const SizedBox(height: 12),
                AppTextFormField(
                  controller: _noteController,
                  label: 'ملاحظات (اختياري)',
                  icon: Icons.edit_note_outlined,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                if (_selectedMenuItem != null) ...[
                  const SizedBox(height: 10),
                  _SelectedFixedMenuHint(
                    item: _selectedMenuItem!,
                    onClear: _saving ? null : _clearSelectedMenuItem,
                  ),
                ],
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

  String? _validateItemName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'اسم الصنف مطلوب';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    final price = _parsePrice(value ?? '');

    if (price == null) {
      return 'اكتب سعر صحيح';
    }

    if (price <= 0) {
      return 'السعر يجب أن يكون أكبر من صفر';
    }

    return null;
  }

  void _applyFixedMenuItem(FixedMenuItemModel item) {
    if (_saving) return;

    final priceText = _cleanNumber(item.price);

    setState(() {
      _selectedMenuItem = item;
      _itemController.text = item.displayName;
      _priceController.text = priceText;
    });

    _formKey.currentState?.validate();
  }

  void _clearSelectedMenuItem() {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedMenuItem = null;

      if (_isEditing) {
        final existing = widget.existing;

        _itemController.text = existing?.itemName ?? '';
        _priceController.text = existing == null
            ? ''
            : _cleanNumber(existing.price);
        _noteController.text = existing?.note ?? '';
      } else {
        _clearFormInputs();
      }
    });

    _formKey.currentState?.reset();
  }

  Future<void> _quickAddFixedMenuItem(FixedMenuItemModel menuItem) async {
    if (_saving || _isEditing) return;

    final cleanName = menuItem.displayName.trim();
    final cleanPrice = _safePositive(menuItem.price);

    if (cleanName.isEmpty || cleanPrice <= 0) {
      _showSnackBar('بيانات الصنف غير صحيحة');
      return;
    }

    FocusScope.of(context).unfocus();

    final itemKey = menuItem.key ?? '${menuItem.displayName}-${menuItem.price}';

    setState(() {
      _saving = true;
      _quickAddingKey = itemKey;
      _selectedMenuItem = menuItem;
    });

    final invoiceItem = InvoiceItemModel(
      itemName: cleanName,
      price: cleanPrice,
      note: null,

      // Payment is controlled by InvoicePaymentSummaryCard only.
      isPaid: false,
      paidAmount: 0.0,
    );

    final saved = await context.read<InvoiceProvider>().addItem(
      invoice: widget.invoice,
      item: invoiceItem,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _quickAddingKey = null;

      if (saved) {
        _selectedMenuItem = null;
        _clearFormInputs();
        _formKey.currentState?.reset();
      }
    });

    _showSnackBar(
      saved
          ? 'تمت إضافة "$cleanName" للفاتورة'
          : 'تعذر إضافة الصنف، حاول مرة أخرى',
    );
  }

  Future<void> _saveItem() async {
    if (_saving) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    FocusScope.of(context).unfocus();

    final price = _parsePrice(_priceController.text);
    if (price == null || price <= 0) return;

    setState(() => _saving = true);

    final item = InvoiceItemModel(
      date: widget.existing?.date,
      itemName: _itemController.text.trim(),
      price: price,
      note: _nullableText(_noteController.text),

      // Payment is controlled by InvoicePaymentSummaryCard only.
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
      _showSnackBar('تعذر حفظ العنصر، حاول مرة أخرى');
      return;
    }

    Navigator.pop(context);
  }

  void _clearFormInputs() {
    _itemController.clear();
    _priceController.clear();
    _noteController.clear();
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parsePrice(String value) {
    var clean = value.trim().replaceAll('٫', '.').replaceAll(',', '.');
    clean = _normalizeDigits(clean);

    if (clean.isEmpty || clean == '.' || clean == ',') return null;

    final parsed = double.tryParse(clean);

    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  String _normalizeDigits(String value) {
    const replacements = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var result = value;

    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }

  double _safePositive(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0.0;
    return value;
  }

  String _cleanNumber(double value) {
    if (value <= 0) return '';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 5,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(50),
        ),
      ),
    );
  }
}

class _SelectedFixedMenuHint extends StatelessWidget {
  final FixedMenuItemModel item;
  final VoidCallback? onClear;

  const _SelectedFixedMenuHint({required this.item, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .13)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 8, 7),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'تم اختيار "${item.displayName}" من القائمة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'إزالة التحديد',
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositiveDecimalTextInputFormatter extends TextInputFormatter {
  const _PositiveDecimalTextInputFormatter();
  static final RegExp _validInput = RegExp(
    r'^[0-9٠-٩۰-۹]*([.,٫][0-9٠-٩۰-۹]{0,2})?$',
  );
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();

    if (text.isEmpty || _validInput.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
