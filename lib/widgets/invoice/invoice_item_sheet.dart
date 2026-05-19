import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/invoice_item_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../providers/invoice_provider.dart';
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
  late final TextEditingController _paymentAdjustmentController;
  late final TextEditingController _noteController;

  late bool _isPaid;

  bool get _isEditing => widget.existing != null;

  bool get _canAdjustPartialPayment =>
      _isEditing && !(widget.existing?.isPaid ?? false);

  double get _basePaidAmount => widget.existing?.paidValue ?? 0.0;

  double get _previewPrice => _parsePrice(_priceController.text) ?? 0.0;

  double get _previewPaidAmount {
    if (_isPaid) return _previewPrice;

    final adjustment =
        _parseSignedAmount(_paymentAdjustmentController.text) ?? 0.0;

    final paidAmount = _canAdjustPartialPayment
        ? _basePaidAmount + adjustment
        : _basePaidAmount;

    return _clampPaidAmount(paidAmount, _previewPrice);
  }

  double get _previewRemainingAmount => _previewPrice - _previewPaidAmount;

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
    _priceController.addListener(_refreshPreview);

    _paymentAdjustmentController = TextEditingController();
    _paymentAdjustmentController.addListener(_refreshPreview);

    _noteController = TextEditingController(text: existing?.note ?? '');

    // New item starts as paid by default.
    // Existing item keeps its old value.
    _isPaid = existing?.isPaid ?? true;
  }

  @override
  void dispose() {
    _customerController.dispose();
    _itemController.dispose();

    _priceController
      ..removeListener(_refreshPreview)
      ..dispose();

    _paymentAdjustmentController
      ..removeListener(_refreshPreview)
      ..dispose();

    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final paidColor = Colors.green;
    final unpaidColor = colorScheme.error;
    final activeColor = _isPaid ? paidColor : unpaidColor;

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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                AppTextFormField(
                  controller: _customerController,
                  label: 'العميل (اختياري)',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),

                AppTextFormField(
                  controller: _itemController,
                  label: 'اسم الصنف',
                  icon: Icons.inventory_2_outlined,
                  textInputAction: TextInputAction.next,
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
                    if (price == null || price <= 0) {
                      return 'السعر مطلوب ويجب أن يكون أكبر من صفر';
                    }
                    return null;
                  },
                ),

                if (_canAdjustPartialPayment) ...[
                  const SizedBox(height: 12),
                  AppTextFormField(
                    controller: _paymentAdjustmentController,
                    label: 'تعديل المدفوع (-)',
                    icon: Icons.add_card_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+.,-]')),
                    ],
                    validator: (value) {
                      final text = value ?? '';
                      final adjustment = _parseSignedAmount(text) ?? 0.0;
                      final price = _parsePrice(_priceController.text) ?? 0.0;
                      final paidAmount = _basePaidAmount + adjustment;

                      if (text.trim().isNotEmpty &&
                          _parseSignedAmount(text) == null) {
                        return 'اكتب مبلغ صحيح مثل +50 أو -20';
                      }

                      if (paidAmount < 0) {
                        return 'لا يمكن أن يكون المدفوع أقل من صفر';
                      }

                      if (paidAmount > price) {
                        return 'لا يمكن أن يكون المدفوع أكبر من السعر';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _PaymentPreview(
                    total: _previewPrice,
                    paid: _previewPaidAmount,
                    remaining: _previewRemainingAmount,
                  ),
                ],

                const SizedBox(height: 12),

                AppTextFormField(
                  controller: _noteController,
                  label: 'ملاحظات (اختياري)',
                  icon: Icons.edit_note_outlined,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),

                const SizedBox(height: 12),

                _PaidCheckboxCard(
                  value: _isPaid,
                  activeColor: activeColor,
                  onChanged: (value) {
                    setState(() {
                      _isPaid = value ?? true;
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

    final price = _parsePrice(_priceController.text)!;

    final item = InvoiceItemModel(
      date: widget.existing?.date,
      customerName: _nullableText(_customerController.text),
      itemName: _itemController.text.trim(),
      price: price,
      note: _nullableText(_noteController.text),
      isPaid: _isPaid || _previewPaidAmount >= price,
      paidAmount: _isPaid ? price : _previewPaidAmount,
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

  double? _parseSignedAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0.0;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  double _clampPaidAmount(double value, double price) {
    if (value < 0) return 0.0;
    if (value > price) return price;
    return value;
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }
}

class _PaidCheckboxCard extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final ValueChanged<bool?> onChanged;

  const _PaidCheckboxCard({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: activeColor.withValues(alpha: .28),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: activeColor,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(
                color: activeColor.withValues(alpha: .75),
                width: 1.6,
              ),
              onChanged: onChanged,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value ? 'تم الدفع' : 'غير مدفوع',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: activeColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value
                        ? 'سيتم تسجيل قيمة الصنف كمدفوعة بالكامل'
                        : 'سيتم تسجيل الصنف كمبلغ متبقي',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: activeColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentPreview extends StatelessWidget {
  final double total;
  final double paid;
  final double remaining;

  const _PaymentPreview({
    required this.total,
    required this.paid,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewRow(title: 'الإجمالي', value: total),
          const SizedBox(height: 6),
          _PreviewRow(title: 'المدفوع بعد التعديل', value: paid),
          const SizedBox(height: 6),
          _PreviewRow(title: 'المتبقي بعد التعديل', value: remaining),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String title;
  final double value;

  const _PreviewRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(Formatters.formatMoney(value)),
      ],
    );
  }
}
