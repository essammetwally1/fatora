import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';

class InvoicePaymentSummaryCard extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePaymentSummaryCard({super.key, required this.invoice});

  @override
  State<InvoicePaymentSummaryCard> createState() =>
      _InvoicePaymentSummaryCardState();
}

class _InvoicePaymentSummaryCardState extends State<InvoicePaymentSummaryCard> {
  late final TextEditingController _paymentController;
  late final FocusNode _paymentFocusNode;

  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _paymentController = TextEditingController();
    _paymentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    _paymentFocusNode.dispose();
    super.dispose();
  }

  double get _currentPaid => widget.invoice.paidTotal;

  double get _total => widget.invoice.total;

  double get _currentRemaining => widget.invoice.unpaidTotal;

  double get _enteredPayment {
    final parsed = double.tryParse(
      _paymentController.text.trim().replaceAll(',', '.'),
    );

    if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0.0;
    return parsed;
  }

  double get _validPaymentPreview {
    final entered = _enteredPayment;

    if (entered <= 0) return 0.0;
    if (entered > _currentRemaining) return _currentRemaining;

    return entered;
  }

  double get _paidAfterPreview {
    final value = _currentPaid + _validPaymentPreview;
    if (value > _total) return _total;
    return value;
  }

  double get _remainingAfterPreview {
    final value = _total - _paidAfterPreview;
    return value <= 0 ? 0.0 : value;
  }

  bool get _isComplete => _total > 0 && _paidAfterPreview >= _total;

  bool get _isPartial => _paidAfterPreview > 0 && !_isComplete;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(colorScheme);

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
            Row(
              children: [
                Icon(_statusIcon, color: statusColor, size: 21),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_paymentPercent()}%',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
                  value: Formatters.formatMoney(_paidAfterPreview),
                  color: Colors.green,
                ),
                const SizedBox(width: 7),
                _SummaryMiniBox(
                  title: 'متبقي',
                  value: Formatters.formatMoney(_remainingAfterPreview),
                  color: _remainingAfterPreview > 0
                      ? colorScheme.error
                      : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _paymentController,
              focusNode: _paymentFocusNode,
              enabled: _currentRemaining > 0 && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'دفعة جديدة',
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: widget.invoice.canEditItems
                      ? colorScheme.onSurfaceVariant
                      : Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                hintText: _currentRemaining <= 0
                    ? 'تم دفع الفاتورة بالكامل'
                    : 'اكتب مبلغ يخصم من المتبقي',
                errorText: _errorText,
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: Colors.green,
                ),
                suffixIcon: _paymentController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        onPressed: () {
                          _paymentController.clear();
                          setState(() => _errorText = null);
                        },
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
              ),
              onTapOutside: (_) => _paymentFocusNode.unfocus(),
              onChanged: (_) {
                setState(() => _errorText = _validatePaymentText());
              },
              onFieldSubmitted: (_) => _submitPayment(),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _SmallPaymentButton(
                    label: 'دفع كامل',
                    icon: Icons.done_all_rounded,
                    color: Colors.green,
                    filled: true,
                    loading: _saving,
                    onPressed: _saving || _currentRemaining <= 0
                        ? null
                        : _completePayment,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallPaymentButton(
                    label: 'حفظ دفعة',
                    icon: Icons.save_outlined,
                    color: statusColor,
                    filled: false,
                    loading: _saving,
                    onPressed: _saving || _currentRemaining <= 0
                        ? null
                        : _submitPayment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePaymentText() {
    final text = _paymentController.text.trim();

    if (text.isEmpty) return null;

    final value = double.tryParse(text.replaceAll(',', '.'));

    if (value == null || value.isNaN || value.isInfinite) {
      return 'اكتب مبلغ صحيح';
    }

    if (value <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر';
    }

    if (value > _currentRemaining) {
      return 'المبلغ أكبر من المتبقي';
    }

    return null;
  }

  Future<void> _submitPayment() async {
    _paymentFocusNode.unfocus();

    final error = _validatePaymentText();

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    final payment = _enteredPayment;

    if (payment <= 0 || _currentRemaining <= 0 || _saving) return;

    final nextPaidAmount = (_currentPaid + payment).clamp(0.0, _total);

    setState(() => _saving = true);

    final saved = await context.read<InvoiceProvider>().updateInvoicePaidAmount(
      invoice: widget.invoice,
      paidAmount: nextPaidAmount,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;

      if (saved) {
        _paymentController.clear();
        _errorText = null;
      }
    });
  }

  Future<void> _completePayment() async {
    _paymentFocusNode.unfocus();

    if (_saving || _currentRemaining <= 0) return;

    setState(() => _saving = true);

    final saved = await context.read<InvoiceProvider>().updateInvoicePaidAmount(
      invoice: widget.invoice,
      paidAmount: _total,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;

      if (saved) {
        _paymentController.clear();
        _errorText = null;
      }
    });
  }

  double _paymentProgress() {
    if (_total <= 0) return 0.0;
    return (_paidAfterPreview / _total).clamp(0.0, 1.0);
  }

  int _paymentPercent() {
    return (_paymentProgress() * 100).round();
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
            Text(
              value,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
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
