import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/number_input_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_payment_history.dart';

enum _PaymentMode { add, subtract }

enum _PaymentSaveAction { manual, complete }

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

  _PaymentMode _mode = _PaymentMode.add;
  _PaymentSaveAction? _savingAction;

  double _typedAmount = 0.0;
  String? _errorText;

  bool get _saving => _savingAction != null;

  bool get _isSubtract => _mode == _PaymentMode.subtract;

  double get _currentPaid => widget.invoice.paidTotal;

  double get _total => widget.invoice.total;

  double get _currentRemaining => widget.invoice.unpaidTotal;

  double get _effectiveDelta {
    if (!_typedAmount.isFinite || _typedAmount <= 0) {
      return 0.0;
    }

    return _isSubtract ? -_typedAmount : _typedAmount;
  }

  double get _validDeltaPreview {
    final delta = _effectiveDelta;

    if (delta == 0) {
      return 0.0;
    }

    if (delta > 0) {
      return delta > _currentRemaining ? _currentRemaining : delta;
    }

    final subtractAmount = delta.abs();

    return subtractAmount > _currentPaid ? -_currentPaid : delta;
  }

  double get _previewPaid {
    final value = _currentPaid + _validDeltaPreview;

    if (!value.isFinite || value <= 0) {
      return 0.0;
    }

    if (value >= _total) {
      return _total;
    }

    return value;
  }

  double get _previewRemaining {
    final value = _total - _previewPaid;

    if (!value.isFinite || value <= 0) {
      return 0.0;
    }

    return value;
  }

  bool get _isComplete {
    return _total > 0 && _previewPaid >= _total;
  }

  bool get _isPartial {
    return _previewPaid > 0 && !_isComplete;
  }

  @override
  void initState() {
    super.initState();

    _mode = _preferredMode(widget.invoice);
  }

  @override
  void didUpdateWidget(covariant InvoicePaymentSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKey = oldWidget.invoice.key;
    final newKey = widget.invoice.key;

    final differentInvoice =
        oldKey != newKey ||
        (oldKey == null &&
            newKey == null &&
            !identical(oldWidget.invoice, widget.invoice));

    if (differentInvoice) {
      _amountController.clear();
      _typedAmount = 0.0;
      _errorText = null;
      _mode = _preferredMode(widget.invoice);
      return;
    }

    if (_saving) {
      return;
    }

    if (_amountController.text.isEmpty) {
      if (_mode == _PaymentMode.add &&
          _currentRemaining <= 0 &&
          _currentPaid > 0) {
        _mode = _PaymentMode.subtract;
      } else if (_mode == _PaymentMode.subtract &&
          _currentPaid <= 0 &&
          _currentRemaining > 0) {
        _mode = _PaymentMode.add;
      }
    }

    _errorText = _validateAmountText();
  }

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
    final statusColors = context.statusColors;

    final providerBusy = context.select<InvoiceProvider, bool>(
      (provider) => provider.isMutating,
    );

    final interactionEnabled =
        !_saving && !providerBusy && _total.isFinite && _total > 0;

    final canAdd =
        interactionEnabled &&
        _currentRemaining.isFinite &&
        _currentRemaining > 0;

    final canSubtract =
        interactionEnabled && _currentPaid.isFinite && _currentPaid > 0;

    final canWriteAmount = _isSubtract ? canSubtract : canAdd;

    final canCompletePayment = canAdd;

    final statusColor = _statusColor(colorScheme);
    final operationColor = _operationColor(colorScheme);

    // The same page inset the items list below uses, so the card and the item
    // cards share one left and right edge down the scroll view instead of
    // stepping in and out by a few pixels at each breakpoint.
    final horizontalPadding = Responsive.horizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
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
          mainAxisSize: MainAxisSize.min,
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
                      : statusColors.success,
                ),
                const SizedBox(width: 7),
                _SummaryMiniBox(
                  title: 'مدفوع',
                  value: Formatters.formatMoney(_previewPaid),
                  color: statusColors.success,
                ),
                const SizedBox(width: 7),
                _SummaryMiniBox(
                  title: 'متبقي',
                  value: Formatters.formatMoney(_previewRemaining),
                  color: _previewRemaining > 0
                      ? colorScheme.error
                      : statusColors.success,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PaymentModeSelector(
              mode: _mode,
              addEnabled: canAdd,
              subtractEnabled: canSubtract,
              onChanged: _changeMode,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              enabled: canWriteAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: const [PositiveDecimalTextInputFormatter()],
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
                  color: canWriteAmount
                      ? operationColor
                      : colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _amountController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        onPressed: canWriteAmount ? _clearAmountInput : null,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
              ),
              onTapOutside: (_) {
                _amountFocusNode.unfocus();
              },
              onChanged: _onAmountChanged,
              onFieldSubmitted: (_) {
                if (canWriteAmount) {
                  _submitPaymentChange();
                }
              },
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
                    loading: _savingAction == _PaymentSaveAction.manual,
                    onPressed: canWriteAmount ? _submitPaymentChange : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallPaymentButton(
                    label: 'دفع كامل',
                    icon: Icons.done_all_rounded,
                    color: statusColors.success,
                    filled: false,
                    loading: _savingAction == _PaymentSaveAction.complete,
                    onPressed: canCompletePayment ? _completePayment : null,
                  ),
                ),
              ],
            ),
            InvoicePaymentHistory(
              // Keyed by invoice so switching invoices collapses the log
              // rather than carrying the previous one's expanded state over.
              key: ValueKey<Object?>(widget.invoice.key),
              invoice: widget.invoice,
            ),
          ],
        ),
      ),
    );
  }

  String get _hintText {
    if (!_total.isFinite || _total <= 0) {
      return 'أضف عناصر أولاً';
    }

    if (_isSubtract) {
      if (!_currentPaid.isFinite || _currentPaid <= 0) {
        return 'لا يوجد مبلغ مدفوع للخصم منه';
      }

      return 'اكتب المبلغ المراد خصمه من المدفوع';
    }

    if (!_currentRemaining.isFinite || _currentRemaining <= 0) {
      return 'تم دفع الفاتورة بالكامل';
    }

    return 'اكتب المبلغ المراد إضافته إلى المدفوع';
  }

  void _changeMode(_PaymentMode mode) {
    if (_mode == mode || _saving) {
      return;
    }

    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      return;
    }

    final modeAvailable = mode == _PaymentMode.add
        ? _currentRemaining > 0
        : _currentPaid > 0;

    if (!modeAvailable) {
      return;
    }

    setState(() {
      _mode = mode;
      _syncTypedAmountFromText();
      _errorText = _validateAmountText();
    });

    _amountFocusNode.requestFocus();
  }

  void _onAmountChanged(String value) {
    if (_saving) {
      return;
    }

    setState(() {
      _syncTypedAmountFromText();
      _errorText = _validateAmountText();
    });
  }

  void _syncTypedAmountFromText() {
    final parsed = _parseAmount(_amountController.text);

    _typedAmount = parsed ?? 0.0;
  }

  void _clearAmountInput() {
    if (_saving) {
      return;
    }

    _amountController.clear();

    setState(() {
      _typedAmount = 0.0;
      _errorText = null;
    });
  }

  double? _parseAmount(String value) => NumberInputUtils.parseAmount(value);

  String? _validateAmountText({bool required = false}) {
    final text = _amountController.text.trim();

    if (text.isEmpty || text == '.' || text == '٫') {
      return required ? 'اكتب المبلغ أولاً' : null;
    }

    final amount = _parseAmount(text);

    if (amount == null) {
      return 'اكتب مبلغًا صحيحًا';
    }

    if (amount <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر';
    }

    if (_isSubtract) {
      if (!_currentPaid.isFinite || _currentPaid <= 0) {
        return 'لا يوجد مبلغ مدفوع للخصم منه';
      }

      if (amount > _currentPaid) {
        return 'المرتجع أكبر من المبلغ المدفوع';
      }

      return null;
    }

    if (!_currentRemaining.isFinite || _currentRemaining <= 0) {
      return 'تم دفع الفاتورة بالكامل';
    }

    if (amount > _currentRemaining) {
      return 'المبلغ أكبر من المتبقي';
    }

    return null;
  }

  Future<void> _submitPaymentChange() async {
    if (_saving || !_total.isFinite || _total <= 0) {
      return;
    }

    _amountFocusNode.unfocus();

    final error = _validateAmountText(required: true);

    if (error != null) {
      setState(() {
        _errorText = error;
      });

      return;
    }

    final amount = _parseAmount(_amountController.text);

    if (amount == null || amount <= 0) {
      return;
    }

    final delta = _isSubtract ? -amount : amount;

    await _saveDelta(delta, action: _PaymentSaveAction.manual);
  }

  Future<void> _completePayment() async {
    if (_saving || !_currentRemaining.isFinite || _currentRemaining <= 0) {
      return;
    }

    _amountFocusNode.unfocus();

    await _saveDelta(_currentRemaining, action: _PaymentSaveAction.complete);
  }

  Future<void> _saveDelta(
    double delta, {
    required _PaymentSaveAction action,
  }) async {
    if (_saving || !delta.isFinite || delta == 0) {
      return;
    }

    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      _showErrorMessage(
        provider.lastErrorMessage ?? 'توجد عملية حفظ أخرى قيد التنفيذ',
      );
      return;
    }

    setState(() {
      _savingAction = action;
    });

    var saved = false;

    try {
      saved = await provider.applyInvoicePaidDelta(
        invoice: widget.invoice,
        deltaAmount: delta,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'InvoicePaymentSummaryCard save failed:\n'
        'Error: $error\n'
        'StackTrace: $stackTrace',
      );
    }

    if (!mounted) {
      return;
    }

    final latestInvoice =
        provider.invoiceByKey(widget.invoice.key) ?? widget.invoice;

    setState(() {
      _savingAction = null;

      if (saved) {
        _typedAmount = 0.0;
        _errorText = null;
        _amountController.clear();
        _mode = _preferredMode(latestInvoice);
      }
    });

    if (!saved) {
      _showErrorMessage(
        provider.lastErrorMessage ?? 'تعذر حفظ العملية، حاول مرة أخرى',
      );
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) {
      return;
    }

    // Matches the toast feedback used everywhere else in the app.
    AppToast.showError(context, message: message);
  }

  Color _operationColor(ColorScheme colorScheme) {
    return _isSubtract ? colorScheme.error : context.statusColors.success;
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (_isComplete) {
      return context.statusColors.success;
    }

    if (_isPartial) {
      return context.statusColors.info;
    }

    return colorScheme.error;
  }

  String get _statusText {
    if (_isComplete) {
      return 'مدفوعة بالكامل';
    }

    if (_isPartial) {
      return 'مدفوعة جزئيًا';
    }

    return 'غير مدفوعة';
  }

  IconData get _statusIcon {
    if (_isComplete) {
      return Icons.check_circle_rounded;
    }

    if (_isPartial) {
      return Icons.timelapse_rounded;
    }

    return Icons.error_outline_rounded;
  }

  double _paymentProgress() {
    if (!_total.isFinite || _total <= 0) {
      return 0.0;
    }

    final progress = _previewPaid / _total;

    if (!progress.isFinite) {
      return 0.0;
    }

    return progress.clamp(0.0, 1.0);
  }

  int _paymentPercent() {
    return (_paymentProgress() * 100).round();
  }

  static _PaymentMode _preferredMode(InvoiceModel invoice) {
    if (invoice.unpaidTotal <= 0 && invoice.paidTotal > 0) {
      return _PaymentMode.subtract;
    }

    return _PaymentMode.add;
  }
}

class _PaymentModeSelector extends StatelessWidget {
  final _PaymentMode mode;
  final bool addEnabled;
  final bool subtractEnabled;
  final ValueChanged<_PaymentMode> onChanged;

  const _PaymentModeSelector({
    required this.mode,
    required this.addEnabled,
    required this.subtractEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChipButton(
            label: 'دفع دفعة',
            icon: Icons.add_rounded,
            selected: mode == _PaymentMode.add,
            enabled: addEnabled,
            color: context.statusColors.success,
            onTap: () {
              onChanged(_PaymentMode.add);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChipButton(
            label: 'مرتجع',
            icon: Icons.remove_rounded,
            selected: mode == _PaymentMode.subtract,
            enabled: subtractEnabled,
            color: Theme.of(context).colorScheme.error,
            onTap: () {
              onChanged(_PaymentMode.subtract);
            },
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

    final foreground = !enabled
        ? color.withValues(alpha: .38)
        : selected
        ? Colors.white
        : color;

    final background = !enabled
        ? color.withValues(alpha: .035)
        : selected
        ? color
        : color.withValues(alpha: .075);

    return SizedBox(
      height: 38,
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected && enabled
                  ? Colors.transparent
                  : color.withValues(alpha: enabled ? .24 : .08),
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
          mainAxisSize: MainAxisSize.min,
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
        onPressed: loading ? null : onPressed,
        icon: loading
            ? SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(icon, size: 17),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
