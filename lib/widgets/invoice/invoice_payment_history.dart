import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feed_back_utils.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoice_payment_entry_model.dart';
import '../../data/models/invoice_payment_line.dart';
import '../../providers/invoice_provider.dart';

/// Collapsible log of an invoice's payments and returns.
///
/// It shows exactly what the printed receipt will show, so the user can check
/// the breakdown before exporting — and, from here, change it: an entry
/// recorded by mistake can be removed, and the whole breakdown can be kept off
/// the exported file.
///
/// The paid total stays owned by the add/return controls above: an entry is
/// never edited here, only deleted, and deleting it takes its money back out
/// of the total rather than leaving the two disagreeing.
///
/// Newest first, because the entry someone just recorded is the one they are
/// looking for. The printed receipt runs oldest first, which is the
/// conventional reading order for a statement.
class InvoicePaymentHistory extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoicePaymentHistory({super.key, required this.invoice});

  @override
  State<InvoicePaymentHistory> createState() => _InvoicePaymentHistoryState();
}

class _InvoicePaymentHistoryState extends State<InvoicePaymentHistory> {
  bool _expanded = false;

  /// The entry a delete is running for, so only its own row shows a spinner
  /// and a second tap on it cannot start the same delete twice.
  String? _deletingEntryId;

  bool _savingExportVisibility = false;

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

    final providerBusy = context.select<InvoiceProvider, bool>(
      (provider) => provider.isMutating,
    );

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
        _ExportDetailsToggle(
          printsDetails: widget.invoice.printsPaymentDetails,
          saving: _savingExportVisibility,
          enabled: !providerBusy && !_savingExportVisibility,
          onChanged: _setExportDetailsVisible,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _HistoryList(
                  lines: orderedLines,
                  deletingEntryId: _deletingEntryId,
                  canDelete: !providerBusy && _deletingEntryId == null,
                  onDelete: _confirmAndDeleteEntry,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Future<void> _setExportDetailsVisible(bool visible) async {
    if (_savingExportVisibility) return;

    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      AppToast.showInfo(context, message: 'توجد عملية حفظ أخرى قيد التنفيذ');
      return;
    }

    setState(() => _savingExportVisibility = true);

    final saved = await provider.setPaymentDetailsHiddenInExport(
      invoice: widget.invoice,
      hidden: !visible,
    );

    if (!mounted) return;

    setState(() => _savingExportVisibility = false);

    if (!saved) {
      AppToast.showError(
        context,
        message: provider.lastErrorMessage ?? 'تعذر حفظ الإعداد، حاول مرة أخرى',
      );

      return;
    }

    AppToast.showSuccess(
      context,
      message: visible
          ? 'ستظهر تفاصيل الدفعات في الملف المصدَّر'
          : 'لن تظهر تفاصيل الدفعات في الملف المصدَّر',
    );
  }

  Future<void> _confirmAndDeleteEntry(InvoicePaymentLine line) async {
    final entryId = line.entryId;

    if (entryId == null || entryId.isEmpty) return;
    if (_deletingEntryId != null) return;

    final provider = context.read<InvoiceProvider>();

    if (provider.isMutating) {
      AppToast.showInfo(context, message: 'توجد عملية حفظ أخرى قيد التنفيذ');
      return;
    }

    final confirmed = await UiFeedbackUtils.showDeletePaymentEntryConfirmation(
      context: context,
      amount: line.amount,
      isReturn: line.isReturn,
      occurredAt: line.occurredAt,
      paidTotalAfter: _paidTotalAfterRemoving(line),
    );

    if (!confirmed || !mounted) return;

    setState(() => _deletingEntryId = entryId);

    final deleted = await provider.deletePaymentEntry(
      invoice: widget.invoice,
      entryId: entryId,
    );

    if (!mounted) return;

    setState(() => _deletingEntryId = null);

    if (!deleted) {
      AppToast.showError(
        context,
        message: provider.lastErrorMessage ?? 'تعذر حذف العملية، حاول مرة أخرى',
      );

      return;
    }

    AppToast.showSuccess(
      context,
      message: line.isReturn ? 'تم حذف المرتجع' : 'تم حذف الدفعة',
    );
  }

  /// What the paid total becomes once [line] is gone.
  ///
  /// Mirrors the repository's clamp so the confirmation dialog promises the
  /// number the user will actually see, including on an invoice whose paid
  /// total is already pinned to its own total.
  double _paidTotalAfterRemoving(InvoicePaymentLine line) {
    final invoice = widget.invoice;

    final next = invoice.paidTotal - line.signedAmount;

    if (!next.isFinite || next <= 0) return 0.0;

    return next > invoice.total ? invoice.total : next;
  }
}

/// Chooses whether the exported PDF and image carry the dated breakdown.
class _ExportDetailsToggle extends StatelessWidget {
  final bool printsDetails;
  final bool saving;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ExportDetailsToggle({
    required this.printsDetails,
    required this.saving,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accent = printsDetails
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            printsDetails
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طباعة التفاصيل في PDF والصورة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Says what the file will contain, not what the switch is:
                  // the user is deciding what the customer will read.
                  printsDetails
                      ? 'الملف المصدَّر يعرض كل دفعة ومرتجع'
                      : 'الملف المصدَّر يعرض الإجمالي فقط',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            Switch(value: printsDetails, onChanged: enabled ? onChanged : null),
        ],
      ),
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
  final String? deletingEntryId;
  final bool canDelete;
  final ValueChanged<InvoicePaymentLine> onDelete;

  const _HistoryList({
    required this.lines,
    required this.deletingEntryId,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // The log used to be capped and scrollable in its own right, because the
    // card could not grow past its share of a non-scrolling screen. The page
    // scrolls as one now, so the log simply lays out at its full height and
    // scrolls with everything else — no scroll region nested inside another
    // one for a finger to get caught in.
    //
    // Every row is built at once rather than lazily. A payment log runs to a
    // handful of entries, it is collapsed until asked for, and the rows are
    // cheap; that is a better trade than a viewport inside a viewport.
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const SizedBox(height: 6),
            _HistoryRow(
              line: lines[index],
              deleting:
                  lines[index].entryId != null &&
                  lines[index].entryId == deletingEntryId,
              canDelete: canDelete && lines[index].isDeletable,
              onDelete: () => onDelete(lines[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final InvoicePaymentLine line;
  final bool deleting;
  final bool canDelete;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.line,
    required this.deleting,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = line.isReturn
        ? colorScheme.error
        : context.statusColors.success;

    final occurredAt = line.occurredAt;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 4, 7),
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
          // The opening line is derived from a balance rather than stored, so
          // there is no entry behind it to delete. It keeps the same width as
          // the rows that do, so the amounts stay in one column.
          SizedBox.square(
            dimension: 32,
            child: deleting
                ? const Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : line.isDeletable
                ? IconButton(
                    tooltip: line.isReturn ? 'حذف المرتجع' : 'حذف الدفعة',
                    onPressed: canDelete ? onDelete : null,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size.square(32),
                      foregroundColor: colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
