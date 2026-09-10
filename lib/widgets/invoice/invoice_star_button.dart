import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/invoice_model.dart';
import '../../providers/invoice_provider.dart';

/// Marks an invoice as one to come back to, and unmarks it.
///
/// One widget for every place the star appears — the invoice card and the
/// details header — so the two cannot drift apart on what a tap does, what it
/// looks like once starred, or what happens when the write fails.
///
/// Success is silent: the star itself changes, and a toast on every tap would
/// be noise in a list. Only a failure has something to say. Until the write
/// lands the star is replaced by a spinner, so a tap is never a button that
/// looks like it did nothing.
class InvoiceStarButton extends StatefulWidget {
  final InvoiceModel invoice;
  final double size;
  final double iconSize;

  const InvoiceStarButton({
    super.key,
    required this.invoice,
    this.size = 32,
    this.iconSize = 19,
  });

  @override
  State<InvoiceStarButton> createState() => _InvoiceStarButtonState();
}

class _InvoiceStarButtonState extends State<InvoiceStarButton> {
  /// Whether *this* button started the write that is running.
  ///
  /// Every star in the list is disabled while any invoice is being written,
  /// but only the one that was tapped spins — the same rule the payment log
  /// uses for its delete buttons.
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isStarred = widget.invoice.isStarred;

    final isMutating = context.select<InvoiceProvider, bool>(
      (provider) => provider.isMutating,
    );

    final color = isStarred
        ? AppTheme.star
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox.square(
      dimension: widget.size,
      child: IconButton(
        tooltip: isStarred ? 'إلغاء التمييز' : 'تمييز الفاتورة',
        onPressed: isMutating || _saving ? null : _toggle,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.square(widget.size),
          backgroundColor: isStarred
              ? AppTheme.star.withValues(alpha: isDark ? .18 : .12)
              : Colors.transparent,
          foregroundColor: color,
          disabledForegroundColor: color.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: color.withValues(alpha: isStarred ? .32 : .18),
            ),
          ),
        ),
        icon: _saving
            ? SizedBox.square(
                dimension: widget.iconSize - 3,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.star,
                ),
              )
            : Icon(
                isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                size: widget.iconSize,
              ),
      ),
    );
  }

  Future<void> _toggle() async {
    final provider = context.read<InvoiceProvider>();

    if (_saving || provider.isMutating) return;

    unawaited(HapticFeedback.selectionClick());

    setState(() => _saving = true);

    final saved = await provider.setInvoiceStarred(
      invoice: widget.invoice,
      starred: !widget.invoice.isStarred,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    if (saved) return;

    AppToast.showError(
      context,
      message: provider.lastErrorMessage ?? 'تعذر حفظ التمييز، حاول مرة أخرى',
    );
  }
}
