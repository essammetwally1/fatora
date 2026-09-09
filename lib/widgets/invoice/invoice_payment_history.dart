import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoice_payment_entry_model.dart';
import '../../data/models/invoice_payment_line.dart';

/// Collapsible, read-only log of an invoice's payments and returns.
///
/// It shows exactly what the printed receipt will show, so the user can check
/// the breakdown before exporting. Read-only on purpose: the paid total is
/// owned by the add/return controls above it, and letting an entry be edited
/// here would give two places the power to change the same number.
///
/// Newest first, because the entry someone just recorded is the one they are
/// looking for. The printed receipt runs oldest first, which is the
/// conventional reading order for a statement.
class InvoicePaymentHistory extends StatefulWidget {
  /// Hard ceiling on the scrollable list, so a long history cannot squeeze the
  /// items list underneath it off the screen.
  static const double _maxListHeight = 188;

  /// Share of the viewport the list may take on a short screen.
  ///
  /// The card sits in a non-scrolling column above the invoice items, so a
  /// fixed ceiling that is comfortable on a tall phone would push the items
  /// off a small one. The cap scales down with the viewport instead.
  static const double _maxListHeightFraction = .22;

  static double maxListHeightFor(BuildContext context) {
    return math.min(
      _maxListHeight,
      MediaQuery.sizeOf(context).height * _maxListHeightFraction,
    );
  }

  final InvoiceModel invoice;

  const InvoicePaymentHistory({super.key, required this.invoice});

  @override
  State<InvoicePaymentHistory> createState() => _InvoicePaymentHistoryState();
}

class _InvoicePaymentHistoryState extends State<InvoicePaymentHistory> {
  bool _expanded = false;

  List<InvoicePaymentEntryModel>? _cachedEntriesReference;
  double _cachedPaidTotal = double.nan;
  List<InvoicePaymentLine> _cachedLines = const [];

  /// The payment card rebuilds on every keystroke in its amount field, and
  /// this widget rebuilds with it. Flattening the history means a sort and two
  /// list allocations, so it is done once per data change instead.
  ///
  /// Repository writes replace `payments` with a new list, exactly like
  /// `invoice.items`, so identity is a sound cache key. The paid total is part
  /// of the key because the carried-over opening line is derived from it.
  List<InvoicePaymentLine> _linesFor(InvoiceModel invoice) {
    final paidTotal = invoice.paidTotal;

    if (identical(_cachedEntriesReference, invoice.payments) &&
        _cachedPaidTotal == paidTotal) {
      return _cachedLines;
    }

    _cachedEntriesReference = invoice.payments;
    _cachedPaidTotal = paidTotal;
    _cachedLines = InvoicePaymentLine.fromInvoice(invoice);

    return _cachedLines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _linesFor(widget.invoice);

    if (lines.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Newest first for the screen; `fromInvoice` returns oldest first.
    final orderedLines = lines.reversed.toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 9),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: .5),
        ),
        _HistoryToggle(
          count: lines.length,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _HistoryList(lines: orderedLines)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _HistoryToggle extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _HistoryToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'سجل الدفعات والمرتجعات ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: expanded ? .5 : 0,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<InvoicePaymentLine> lines;

  const _HistoryList({required this.lines});

  @override
  Widget build(BuildContext context) {
    // Short histories size to their content; long ones scroll inside the cap
    // instead of pushing the invoice items off screen.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: InvoicePaymentHistory.maxListHeightFor(context),
      ),
      child: ListView.separated(
        primary: false,
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        physics: const ClampingScrollPhysics(),
        itemCount: lines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _HistoryRow(line: lines[index]),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final InvoicePaymentLine line;

  const _HistoryRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = line.isReturn
        ? colorScheme.error
        : context.statusColors.success;

    final occurredAt = line.occurredAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(
            line.isReturn
                ? Icons.undo_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.labelAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // A dash, never a guess: money paid before the app recorded
                  // payment times has no date to show.
                  occurredAt == null
                      ? 'بدون تاريخ مسجل'
                      : Formatters.formatPaymentDateTime(occurredAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: occurredAt == null ? null : TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                line.isReturn
                    ? '- ${Formatters.formatMoney(line.amount)}'
                    : Formatters.formatMoney(line.amount),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
