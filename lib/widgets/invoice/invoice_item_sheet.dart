import 'package:fatora/widgets/menu/fixed_menu_quick_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/number_input_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/fixed_menu_item_model.dart';
import '../../data/models/invoice_item_model.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
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
    // Colour and shape come from `bottomSheetTheme`; the constraint keeps the
    // form from stretching across a tablet.
    constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
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

  /// Menu items composing the line being built, in the order they were picked.
  /// The name and price fields are regenerated from this whenever it changes.
  final List<FixedMenuItemModel> _selectedMenuItems = <FixedMenuItemModel>[];

  /// Mirror of [_selectedMenuItems] keyed for O(1) lookup, because the picker
  /// asks "is this row selected?" for every visible row on every rebuild.
  final Set<Object> _selectedMenuKeys = <Object>{};

  bool get _isEditing => widget.existing != null;

  double get _selectedMenuTotal {
    var total = 0.0;

    for (final item in _selectedMenuItems) {
      total += NumberInputUtils.safePositive(item.price);
    }

    return total;
  }

  /// The composed line name, e.g. `عدسة + إطار`.
  String get _selectedMenuName {
    return _selectedMenuItems.map((item) => item.displayName).join(' + ');
  }

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
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: viewInsets.bottom + AppSpacing.lg,
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
                  selectedKeys: _selectedMenuKeys,
                  onToggle: _toggleFixedMenuItem,
                  onClearSelection: _selectedMenuItems.isEmpty
                      ? null
                      : _clearSelectedMenuItems,
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
                  inputFormatters: const [PositiveDecimalTextInputFormatter()],
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
                if (_selectedMenuItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SelectedFixedMenuHint(
                    name: _selectedMenuName,
                    total: _selectedMenuTotal,
                    count: _selectedMenuItems.length,
                    onClear: _saving ? null : _clearSelectedMenuItems,
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

  /// Adds or removes a menu item from the composed line.
  ///
  /// The name and price fields are then rewritten from the whole selection, so
  /// they always match what is ticked. That does discard a manual edit made in
  /// between, which is the predictable trade: the ticked rows are the visible
  /// source of truth, and a stale hand-typed total would be the dangerous one.
  void _toggleFixedMenuItem(FixedMenuItemModel item) {
    if (_saving) return;

    final itemKey = fixedMenuItemKey(item);

    setState(() {
      if (_selectedMenuKeys.remove(itemKey)) {
        _selectedMenuItems.removeWhere(
          (selected) => fixedMenuItemKey(selected) == itemKey,
        );
      } else {
        _selectedMenuKeys.add(itemKey);
        _selectedMenuItems.add(item);
      }

      _syncFieldsWithSelection();
    });

    _formKey.currentState?.validate();
  }

  void _clearSelectedMenuItems() {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedMenuItems.clear();
      _selectedMenuKeys.clear();
      _syncFieldsWithSelection();
    });

    _formKey.currentState?.reset();
  }

  /// Rewrites the name and price fields from the current selection.
  ///
  /// Emptying the selection restores the starting point rather than leaving
  /// the last composed text behind: the original values when editing, blank
  /// when creating. The note is never touched — it is the user's own text and
  /// no menu item has anything to say about it.
  void _syncFieldsWithSelection() {
    if (_selectedMenuItems.isEmpty) {
      final existing = widget.existing;

      _itemController.text = existing?.itemName ?? '';
      _priceController.text = existing == null
          ? ''
          : _cleanNumber(existing.price);

      return;
    }

    _itemController.text = _selectedMenuName;
    _priceController.text = _cleanNumber(_selectedMenuTotal);
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

      // Surface the provider's specific reason (paid-invoice lock, stale item,
      // bad price) instead of a generic failure message.
      _showMessage(
        provider.lastErrorMessage ?? 'تعذر حفظ العنصر، حاول مرة أخرى',
      );
      return;
    }

    Navigator.pop(context);
  }

  /// Shown while the sheet is still open, so it must be a toast: a `SnackBar`
  /// raised from inside a modal sheet renders behind it.
  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    if (isError) {
      AppToast.showError(context, message: message);
    } else {
      AppToast.showSuccess(context, message: message);
    }
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parsePrice(String value) => NumberInputUtils.parseAmount(value);

  String _cleanNumber(double value) => NumberInputUtils.formatForInput(value);
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
  final String name;
  final double total;
  final int count;
  final VoidCallback? onClear;

  const _SelectedFixedMenuHint({
    required this.name,
    required this.total,
    required this.count,
    required this.onClear,
  });

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? 'صنف واحد من القائمة'
                        : 'مجموع $count أصناف من القائمة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    // Two lines: a composed name grows fast, but an unbounded
                    // one would push the save button off a small screen.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Formatters.formatMoney(total),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
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
