import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';

enum _PaymentMode { add, subtract }

class InvoicePaymentSummaryCard extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePaymentSummaryCard({super.key, required this.invoice});

  @override
  State<InvoicePaymentSummaryCard> createState() =>
      _InvoicePaymentSummaryCardState();
}

class _InvoicePaymentSummaryCardState extends State<InvoicePaymentSummaryCard> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  bool _saving = false;
  String? _errorText;

  _PaymentMode _mode = _PaymentMode.add;
  double _typedAmount = 0.0;

  double get _currentPaid => widget.invoice.paidTotal;
  double get _total => widget.invoice.total;
  double get _currentRemaining => widget.invoice.unpaidTotal;

  bool get _canWriteAmount => _total > 0 && !_saving;
  bool get _canCompletePayment => _currentRemaining > 0 && !_saving;

  bool get _isSubtract => _mode == _PaymentMode.subtract;

  double get _effectiveDelta {
    if (_typedAmount <= 0) return 0.0;
    return _isSubtract ? -_typedAmount : _typedAmount;
  }

  double get _validDeltaPreview {
    final delta = _effectiveDelta;

    if (delta == 0) return 0.0;

    if (delta > 0) {
      if (delta > _currentRemaining) return _currentRemaining;
      return delta;
    }

    final subtractAmount = delta.abs();
    if (subtractAmount > _currentPaid) return -_currentPaid;

    return delta;
  }

  double get _previewPaid {
    final value = _currentPaid + _validDeltaPreview;

    if (value <= 0) return 0.0;
    if (value >= _total) return _total;

    return value;
  }

  double get _previewRemaining {
    final value = _total - _previewPaid;
    return value <= 0 ? 0.0 : value;
  }

  bool get _isComplete => _total > 0 && _previewPaid >= _total;
  bool get _isPartial => _previewPaid > 0 && !_isComplete;

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(colorScheme);
    final operationColor = _operationColor(colorScheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: statusColor, width: 1.25),
        ),
        child: Column(
          children: [
            _StatusHeader(
              icon: _statusIcon,
              text: _statusText,
              percent: _paymentPercent(),
              color: statusColor,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _paymentProgress(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: statusColor.withValues(alpha: .14),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SummaryMiniBox(
                  title: 'الإجمالي',
                  value: Formatters.formatMoney(_total),
                  color: widget.invoice.canEditItems
                      ? colorScheme.primary
                      : Colors.green,
                ),
                const SizedBox(width: 7),
                _SummaryMiniBox(
                  title: 'مدفوع',
                  value: Formatters.formatMoney(_previewPaid),
                  color: Colors.green,
                ),
                const SizedBox(width: 7),
                _SummaryMiniBox(
                  title: 'متبقي',
                  value: Formatters.formatMoney(_previewRemaining),
                  color: _previewRemaining > 0
                      ? colorScheme.error
                      : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PaymentModeSelector(
              mode: _mode,
              enabled: _canWriteAmount,
              onChanged: _changeMode,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              enabled: _canWriteAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: const [_SignedDecimalTextInputFormatter()],
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.right,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                isDense: true,
                labelText: _isSubtract ? 'المبلغ المرتجع' : 'المبلغ المدفوع',
                hintText: _hintText,
                hintTextDirection: TextDirection.rtl,
                errorText: _errorText,
                prefixIcon: Icon(
                  _isSubtract
                      ? Icons.remove_circle_outline_rounded
                      : Icons.payments_outlined,
                  size: 20,
                  color: operationColor,
                ),
                suffixIcon: _amountController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        onPressed: _clearAmountInput,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
              ),
              onTapOutside: (_) => _amountFocusNode.unfocus(),
              onChanged: _onAmountChanged,
              onFieldSubmitted: (_) => _submitPaymentChange(),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _SmallPaymentButton(
                    label: _isSubtract ? 'حفظ المرتجع' : 'حفظ الدفعة',
                    icon: _isSubtract
                        ? Icons.remove_rounded
                        : Icons.save_outlined,
                    color: operationColor,
                    filled: true,
                    loading: _saving,
                    onPressed: _canWriteAmount ? _submitPaymentChange : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallPaymentButton(
                    label: 'دفع كامل',
                    icon: Icons.done_all_rounded,
                    color: Colors.green,
                    filled: false,
                    loading: _saving,
                    onPressed: _canCompletePayment ? _completePayment : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _hintText {
    if (_total <= 0) return 'أضف عناصر أولاً';

    if (_isSubtract) {
      if (_currentPaid <= 0) return 'لا يوجد مبلغ مدفوع للخصم منه';
      return 'اكتب المبلغ المراد خصمه من المتبقي';
    }

    if (_currentRemaining <= 0) return 'تم دفع الفاتورة بالكامل';
    return 'اكتب المبلغ المراد إضافته الي المدفوع';
  }

  void _changeMode(_PaymentMode mode) {
    if (_mode == mode || _saving) return;

    final currentText = _amountController.text.trim();

    setState(() {
      _mode = mode;

      if (mode == _PaymentMode.add && currentText.startsWith('-')) {
        final nextText = currentText.substring(1);

        _amountController.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }

      _syncTypedAmountFromText();
      _errorText = _validateAmountText();
    });

    _amountFocusNode.requestFocus();
  }

  void _onAmountChanged(String value) {
    final clean = value.trim();

    if (clean.startsWith('-') && _mode != _PaymentMode.subtract) {
      setState(() {
        _mode = _PaymentMode.subtract;
      });
    }

    setState(() {
      _syncTypedAmountFromText();
      _errorText = _validateAmountText();
    });
  }

  void _syncTypedAmountFromText() {
    final parsed = _parseSignedAmount(_amountController.text);
    _typedAmount = parsed == null ? 0.0 : parsed.abs();
  }

  void _clearAmountInput() {
    _amountController.clear();

    setState(() {
      _typedAmount = 0.0;
      _errorText = null;
    });
  }

  double? _parseSignedAmount(String value) {
    final clean = value.trim().replaceAll(',', '.');

    if (clean.isEmpty || clean == '-' || clean == '.' || clean == '-.') {
      return null;
    }

    final parsed = double.tryParse(clean);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;

    return parsed;
  }

  String? _validateAmountText() {
    final text = _amountController.text.trim();

    if (text.isEmpty || text == '-' || text == '.' || text == '-.') {
      return null;
    }

    final signedValue = _parseSignedAmount(text);
    if (signedValue == null) return 'اكتب مبلغ صحيح';

    final amount = signedValue.abs();

    if (amount == 0) return 'المبلغ لا يمكن أن يكون صفر';

    if (_isSubtract) {
      if (_currentPaid <= 0) return 'لا يوجد مبلغ مدفوع للخصم منه';
      if (amount > _currentPaid) return 'الخصم أكبر من المدفوع';
      return null;
    }

    if (_currentRemaining <= 0) return 'تم دفع الفاتورة بالكامل';
    if (amount > _currentRemaining) return 'المبلغ أكبر من المتبقي';

    return null;
  }

  Future<void> _submitPaymentChange() async {
    if (_saving || _total <= 0) return;

    _amountFocusNode.unfocus();

    final error = _validateAmountText();
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    final signedValue = _parseSignedAmount(_amountController.text);
    if (signedValue == null || signedValue == 0) return;

    final amount = signedValue.abs();
    final delta = _isSubtract ? -amount : amount;

    await _saveDelta(delta);
  }

  Future<void> _completePayment() async {
    if (!_canCompletePayment) return;

    _amountFocusNode.unfocus();

    final delta = _currentRemaining;
    if (delta <= 0) return;

    await _saveDelta(delta);
  }

  Future<void> _saveDelta(double delta) async {
    setState(() => _saving = true);

    final saved = await context.read<InvoiceProvider>().applyInvoicePaidDelta(
      invoice: widget.invoice,
      deltaAmount: delta,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;

      if (saved) {
        _typedAmount = 0.0;
        _errorText = null;
        _amountController.clear();

        if (widget.invoice.unpaidTotal <= 0) {
          _mode = _PaymentMode.subtract;
        } else {
          _mode = _PaymentMode.add;
        }
      }
    });

    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تعذر حفظ العملية، حاول مرة أخرى')),
        );
    }
  }

  Color _operationColor(ColorScheme colorScheme) {
    return _isSubtract ? colorScheme.error : Colors.green;
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (_isComplete) return Colors.green;
    if (_isPartial) return Colors.blue;
    return colorScheme.error;
  }

  String get _statusText {
    if (_isComplete) return 'مدفوعة بالكامل';
    if (_isPartial) return 'مدفوعة جزئياً';
    return 'غير مدفوعة';
  }

  IconData get _statusIcon {
    if (_isComplete) return Icons.check_circle_rounded;
    if (_isPartial) return Icons.timelapse_rounded;
    return Icons.error_outline_rounded;
  }

  double _paymentProgress() {
    if (_total <= 0) return 0.0;
    return (_previewPaid / _total).clamp(0.0, 1.0);
  }

  int _paymentPercent() {
    return (_paymentProgress() * 100).round();
  }
}

class _PaymentModeSelector extends StatelessWidget {
  final _PaymentMode mode;
  final bool enabled;
  final ValueChanged<_PaymentMode> onChanged;

  const _PaymentModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChipButton(
            label: 'دفع دفعه',
            icon: Icons.add_rounded,
            selected: mode == _PaymentMode.add,
            enabled: enabled,
            color: Colors.green,
            onTap: () => onChanged(_PaymentMode.add),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChipButton(
            label: 'مرتجع',
            icon: Icons.remove_rounded,
            selected: mode == _PaymentMode.subtract,
            enabled: enabled,
            color: Theme.of(context).colorScheme.error,
            onTap: () => onChanged(_PaymentMode.subtract),
          ),
        ),
      ],
    );
  }
}

class _ModeChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _ModeChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? Colors.white : color;
    final background = selected ? color : color.withValues(alpha: .075);

    return SizedBox(
      height: 38,
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground.withValues(alpha: .38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected
                  ? Colors.transparent
                  : color.withValues(alpha: .24),
            ),
          ),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SignedDecimalTextInputFormatter extends TextInputFormatter {
  const _SignedDecimalTextInputFormatter();

  static final RegExp _validInput = RegExp(r'^-?\d*([.,]\d*)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();

    if (text.isEmpty || text == '-' || _validInput.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}

class _StatusHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  final int percent;
  final Color color;

  const _StatusHeader({
    required this.icon,
    required this.text,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$percent%',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SummaryMiniBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryMiniBox({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .075),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallPaymentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool loading;
  final VoidCallback? onPressed;

  const _SmallPaymentButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    final background = filled ? color : color.withValues(alpha: .075);

    return SizedBox(
      height: 38,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: loading
            ? SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground.withValues(alpha: .45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: filled ? Colors.transparent : color.withValues(alpha: .25),
            ),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
