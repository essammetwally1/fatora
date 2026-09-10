import 'package:fatora/app/app_theme.dart';
import 'package:fatora/core/utils/app_toast.dart';
import 'package:fatora/core/utils/responsive.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/files/app_file_saver.dart';
import 'package:fatora/data/services/pdf/invoice_image_exporter.dart';
import 'package:fatora/data/services/pdf/pdf_service.dart';
import 'package:fatora/screens/invoice_image_screen.dart';
import 'package:fatora/screens/invoice_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which document the sheet produces.
///
/// The two formats are the same three actions over the same invoice, so they
/// share one sheet rather than two near-identical copies. Everything that
/// differs between them — wording, icon, accent, and the work each action
/// does — is gathered here.
enum InvoiceExportFormat {
  pdf(
    label: 'ملف PDF',
    accent: AppTheme.red,
    previewTitle: 'معاينة PDF',
    previewSubtitle: 'افتح صفحة المعاينة قبل الحفظ أو المشاركة',
    saveTitle: 'حفظ على الجهاز',
    saveSubtitle: 'تنزيل الفاتورة كملف PDF',
    shareTitle: 'مشاركة / Export',
    shareSubtitle: 'إرسال الفاتورة عبر واتساب أو تليجرام أو غيره',
    saveErrorMessage: 'حدث خطأ أثناء حفظ ملف PDF',
    shareErrorMessage: 'حدث خطأ أثناء مشاركة ملف PDF',
  ),
  image(
    label: 'صورة الفاتورة',
    accent: AppTheme.blue,
    previewTitle: 'معاينة الصورة',
    previewSubtitle: 'اعرض صفحات الفاتورة كصور قبل الحفظ أو المشاركة',
    saveTitle: 'حفظ كصورة',
    saveSubtitle: 'تنزيل الفاتورة كصورة PNG، صفحة لكل صورة',
    shareTitle: 'مشاركة كصورة',
    shareSubtitle: 'إرسال الفاتورة كصورة جاهزة للعرض في المحادثة',
    saveErrorMessage: 'حدث خطأ أثناء حفظ صورة الفاتورة',
    shareErrorMessage: 'حدث خطأ أثناء مشاركة صورة الفاتورة',
  );

  const InvoiceExportFormat({
    required this.label,
    required this.accent,
    required this.previewTitle,
    required this.previewSubtitle,
    required this.saveTitle,
    required this.saveSubtitle,
    required this.shareTitle,
    required this.shareSubtitle,
    required this.saveErrorMessage,
    required this.shareErrorMessage,
  });

  final String label;

  /// Colour of the icon button that opens this sheet, carried through to the
  /// sheet so the user can see which of the two they landed in.
  final Color accent;

  final String previewTitle;
  final String previewSubtitle;
  final String saveTitle;
  final String saveSubtitle;
  final String shareTitle;
  final String shareSubtitle;
  final String saveErrorMessage;
  final String shareErrorMessage;

  bool get isPdf => this == InvoiceExportFormat.pdf;
}

/// How the caller should announce what the sheet did.
enum _OutcomeTone { success, info, error }

/// What the sheet did before it closed, so the caller can report it.
class _ExportOutcome {
  final String message;
  final _OutcomeTone tone;

  const _ExportOutcome({
    required this.message,
    this.tone = _OutcomeTone.success,
  });
}

/// Which long-running action is currently in flight.
///
/// One field instead of a bool per action: only one export can run at a time,
/// and a single value cannot drift into a state where two spinners show.
enum _ExportAction { preview, save, share }

/// Preview, save and share for one invoice in one format.
class InvoiceExportSheet extends StatefulWidget {
  final InvoiceModel invoice;
  final InvoiceExportFormat format;

  const InvoiceExportSheet({
    super.key,
    required this.invoice,
    required this.format,
  });

  static Future<void> show({
    required BuildContext context,
    required InvoiceModel invoice,
    required InvoiceExportFormat format,
  }) async {
    final outcome = await showModalBottomSheet<_ExportOutcome>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      // Colour and shape come from `bottomSheetTheme`.
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (_) => InvoiceExportSheet(invoice: invoice, format: format),
    );

    // Feedback is raised here, from the caller's still-mounted context, rather
    // than from inside the sheet after it has popped itself.
    if (outcome == null || !context.mounted) return;

    switch (outcome.tone) {
      case _OutcomeTone.success:
        AppToast.showSuccess(context, message: outcome.message);
      case _OutcomeTone.info:
        AppToast.showInfo(context, message: outcome.message);
      case _OutcomeTone.error:
        AppToast.showError(context, message: outcome.message);
    }
  }

  @override
  State<InvoiceExportSheet> createState() => _InvoiceExportSheetState();
}

class _InvoiceExportSheetState extends State<InvoiceExportSheet> {
  static const String _pdfIcon = 'assets/icons/pdf.svg';
  static const String _downloadIcon = 'assets/icons/download.svg';
  static const String _exportIcon = 'assets/icons/export.svg';

  _ExportAction? _runningAction;

  bool get _isBusy => _runningAction != null;

  InvoiceExportFormat get _format => widget.format;

  /// Closes the sheet and hands [outcome] back to `show`, which reports it.
  void _closeWith(_ExportOutcome? outcome) {
    if (!mounted) return;

    Navigator.of(context).pop(outcome);
  }

  /// Runs one export, keeping the spinner, the busy lock and the error
  /// wording in one place instead of repeating them per action.
  Future<void> _run({
    required _ExportAction action,
    required Future<_ExportOutcome> Function() task,
    required String errorMessage,
  }) async {
    if (_isBusy) return;

    setState(() => _runningAction = action);

    try {
      _closeWith(await task());
    } catch (error) {
      if (!mounted) return;

      setState(() => _runningAction = null);

      // Dismissing the system save dialog is a choice, not a failure.
      if (error is FileSaveCancelledException) {
        _closeWith(
          const _ExportOutcome(
            message: 'تم إلغاء الحفظ',
            tone: _OutcomeTone.info,
          ),
        );

        return;
      }

      _closeWith(
        _ExportOutcome(
          message: error is InvoiceImageExportException
              ? error.messageAr
              : errorMessage,
          tone: _OutcomeTone.error,
        ),
      );
    }
  }

  Future<void> _openPreview() async {
    if (_isBusy) return;

    setState(() => _runningAction = _ExportAction.preview);

    // The navigator is resolved *before* popping, because `context` is defunct
    // the moment the sheet leaves the tree.
    final navigator = Navigator.of(context);

    final invoice = widget.invoice;
    final format = _format;

    navigator.pop();

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => format.isPdf
            ? InvoicePdfScreen(invoice: invoice)
            : InvoiceImageScreen(invoice: invoice),
      ),
    );
  }

  Future<void> _save() {
    return _run(
      action: _ExportAction.save,
      errorMessage: _format.saveErrorMessage,
      task: () async {
        if (_format.isPdf) {
          final result = await PdfService.saveInvoice(widget.invoice);

          return _ExportOutcome(message: 'تم حفظ الملف: ${result.fileName}');
        }

        final pages = await InvoiceImageExporter.render(widget.invoice);

        final result = await InvoiceImageExporter.saveAll(
          invoice: widget.invoice,
          pages: pages,
        );

        return _ExportOutcome(
          message: result.messageAr,
          tone: result.savedNothing ? _OutcomeTone.info : _OutcomeTone.success,
        );
      },
    );
  }

  Future<void> _share() {
    return _run(
      action: _ExportAction.share,
      errorMessage: _format.shareErrorMessage,
      task: () async {
        if (_format.isPdf) {
          await PdfService.shareInvoice(widget.invoice);

          return const _ExportOutcome(
            message: 'تم تجهيز الفاتورة للمشاركة بنجاح',
          );
        }

        final pages = await InvoiceImageExporter.render(widget.invoice);

        await InvoiceImageExporter.shareAll(
          invoice: widget.invoice,
          pages: pages,
        );

        return _ExportOutcome(
          message: pages.length == 1
              ? 'تم تجهيز صورة الفاتورة للمشاركة'
              : 'تم تجهيز ${pages.length} صور للمشاركة',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceTitle = widget.invoice.title.trim().isEmpty
        ? 'فاتورة بدون عنوان'
        : widget.invoice.title.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        // Three actions plus a header still outgrow a small phone once the
        // system font is scaled up, so the sheet scrolls rather than
        // overflowing.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                invoiceTitle: invoiceTitle,
                format: _format,
                pdfIconAsset: _pdfIcon,
              ),

              // Says so before the file is made, rather than leaving the user
              // to notice the missing breakdown after sending it.
              if (widget.invoice.hidePaymentDetailsInExport)
                const _HiddenDetailsNotice(),

              const SizedBox(height: 14),

              _ExportActionTile(
                accent: _format.accent,
                icon: Icon(
                  _format.isPdf
                      ? Icons.visibility_rounded
                      : Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                title: _format.previewTitle,
                subtitle: _format.previewSubtitle,
                isLoading: _runningAction == _ExportAction.preview,
                enabled: !_isBusy,
                onTap: _openPreview,
              ),

              const SizedBox(height: 10),

              _ExportActionTile(
                accent: _format.accent,
                icon: _format.isPdf
                    ? const _ActionSvgIcon(assetName: _downloadIcon)
                    : const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                title: _format.saveTitle,
                subtitle: _format.saveSubtitle,
                isLoading: _runningAction == _ExportAction.save,
                enabled: !_isBusy,
                onTap: _save,
              ),

              const SizedBox(height: 10),

              _ExportActionTile(
                accent: _format.accent,
                icon: _format.isPdf
                    ? const _ActionSvgIcon(assetName: _exportIcon)
                    : const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                title: _format.shareTitle,
                subtitle: _format.shareSubtitle,
                isLoading: _runningAction == _ExportAction.share,
                enabled: !_isBusy,
                onTap: _share,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warns that this invoice's exports leave the dated breakdown out.
class _HiddenDetailsNotice extends StatelessWidget {
  const _HiddenDetailsNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 19,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'تفاصيل الدفعات مخفية في الملف المصدَّر — الإجمالي فقط',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String invoiceTitle;
  final InvoiceExportFormat format;
  final String pdfIconAsset;

  const _SheetHeader({
    required this.invoiceTitle,
    required this.format,
    required this.pdfIconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: format.accent.withValues(alpha: isDark ? .18 : .10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: format.accent.withValues(alpha: isDark ? .32 : .22),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: format.accent.withValues(alpha: .22),
              child: format.isPdf
                  ? SvgPicture.asset(pdfIconAsset, width: 23, height: 23)
                  : Icon(Icons.image_outlined, size: 24, color: format.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    invoiceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Names the format, so a sheet opened from the wrong icon is
                  // obvious before anything is exported.
                  Text(
                    format.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: format.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportActionTile extends StatelessWidget {
  final Color accent;
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _ExportActionTile({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('icon'),
                      width: 22,
                      height: 22,
                      child: Center(child: icon),
                    ),
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          trailing: Icon(Icons.chevron_left_rounded, color: accent),
        ),
      ),
    );
  }
}

class _ActionSvgIcon extends StatelessWidget {
  final String assetName;

  const _ActionSvgIcon({required this.assetName});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      width: 22,
      height: 22,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}
