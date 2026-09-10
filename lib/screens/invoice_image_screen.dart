import 'dart:math' as math;

import 'package:fatora/core/utils/app_toast.dart';
import 'package:fatora/core/utils/responsive.dart';
import 'package:fatora/data/models/invoice_model.dart';
import 'package:fatora/data/services/files/app_file_saver.dart';
import 'package:fatora/data/services/pdf/invoice_image_exporter.dart';
import 'package:fatora/widgets/common/export_status_views.dart';
import 'package:flutter/material.dart';

enum _Tone { success, info, error }

/// Preview of the invoice rendered as image(s), with save and share.
///
/// The pages come from the same PDF the preview screen shows, so what is
/// shared is pixel-for-pixel the printed invoice. A long invoice is several
/// PDF pages and therefore several images, swiped through here one per page.
class InvoiceImageScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceImageScreen({super.key, required this.invoice});

  @override
  State<InvoiceImageScreen> createState() => _InvoiceImageScreenState();
}

class _InvoiceImageScreenState extends State<InvoiceImageScreen> {
  late Future<List<InvoiceImagePage>> _pagesFuture;

  final PageController _pageController = PageController();

  int _currentPage = 0;

  bool _isSaving = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();

    _pagesFuture = InvoiceImageExporter.render(widget.invoice);
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  void _retry() {
    setState(() {
      _currentPage = 0;
      _pagesFuture = InvoiceImageExporter.render(widget.invoice);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final pages = await _pagesFuture;

      final result = await InvoiceImageExporter.saveAll(
        invoice: widget.invoice,
        pages: pages,
      );

      if (!mounted) return;

      // Dismissing the system save dialog is a choice, not a failure, so it
      // is reported without the error styling.
      _show(
        result.messageAr,
        tone: result.savedNothing ? _Tone.info : _Tone.success,
      );
    } catch (error) {
      if (!mounted) return;

      _show(_messageFor(error, 'حدث خطأ أثناء حفظ الصورة'), tone: _Tone.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final pages = await _pagesFuture;

      await InvoiceImageExporter.shareAll(
        invoice: widget.invoice,
        pages: pages,
      );

      if (!mounted) return;

      _show('تم تجهيز صورة الفاتورة للمشاركة');
    } catch (error) {
      if (!mounted) return;

      _show(
        _messageFor(error, 'حدث خطأ أثناء مشاركة الصورة'),
        tone: _Tone.error,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// Export failures carry a message written for the user; anything else is
  /// reported with the generic wording rather than a raw exception string.
  static String _messageFor(Object error, String fallback) {
    if (error is InvoiceImageExportException) return error.messageAr;

    if (error is FileSaveCancelledException) return 'تم إلغاء الحفظ';

    return fallback;
  }

  void _show(String message, {_Tone tone = _Tone.success}) {
    if (!mounted) return;

    switch (tone) {
      case _Tone.success:
        AppToast.showSuccess(context, message: message);
      case _Tone.info:
        AppToast.showInfo(context, message: message);
      case _Tone.error:
        AppToast.showError(context, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = widget.invoice.title.trim().isEmpty
        ? 'صورة الفاتورة'
        : widget.invoice.title.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 8,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'حفظ الصورة',
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SmallLoader()
                  : Icon(
                      Icons.download_rounded,
                      color: theme.colorScheme.primary,
                    ),
            ),
            IconButton(
              tooltip: 'مشاركة الصورة',
              onPressed: _isSharing ? null : _share,
              icon: _isSharing
                  ? const SmallLoader()
                  : Icon(Icons.share_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: FutureBuilder<List<InvoiceImagePage>>(
          future: _pagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _PreparingView();
            }

            if (snapshot.hasError) {
              return ExportErrorView(
                icon: Icons.image_not_supported_outlined,
                message: 'تعذر تحويل الفاتورة إلى صورة',
                details: _messageFor(
                  snapshot.error!,
                  snapshot.error.toString(),
                ),
                onRetry: _retry,
              );
            }

            final pages = snapshot.data ?? const <InvoiceImagePage>[];

            if (pages.isEmpty) {
              return ExportErrorView(
                icon: Icons.image_not_supported_outlined,
                message: 'لا توجد صفحات للعرض',
                details: 'لم يتم إنشاء أي صورة لهذه الفاتورة.',
                onRetry: _retry,
              );
            }

            return _PagesView(
              pages: pages,
              controller: _pageController,
              currentPage: math.min(_currentPage, pages.length - 1),
              onPageChanged: (index) {
                if (index == _currentPage) return;

                setState(() => _currentPage = index);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            'جاري تجهيز صورة الفاتورة...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PagesView extends StatelessWidget {
  final List<InvoiceImagePage> pages;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _PagesView({
    required this.pages,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiPage = pages.length > 1;

    return ContentWidthLimiter(
      child: Column(
        children: [
          Expanded(
            child: isMultiPage
                ? PageView.builder(
                    controller: controller,
                    itemCount: pages.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, index) {
                      return _InvoicePageView(page: pages[index]);
                    },
                  )
                : _InvoicePageView(page: pages.first),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _PageCounter(
                label: isMultiPage
                    ? 'صفحة ${currentPage + 1} من ${pages.length}'
                    : 'صفحة واحدة',
                hint: isMultiPage
                    ? 'اسحب لعرض باقي الصفحات'
                    : 'قرّب بإصبعين للتكبير',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One page, zoomable and framed like a sheet of paper.
class _InvoicePageView extends StatelessWidget {
  /// Decoding a 150dpi A4 page at full size costs ~8MB of RAM for detail no
  /// phone screen can show, so it is decoded at the width it is drawn at,
  /// doubled to stay sharp under zoom.
  static const double _zoomHeadroom = 2;

  static const double _maxScale = 4;

  final InvoiceImagePage page;

  const _InvoicePageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth =
            constraints.maxWidth * devicePixelRatio * _zoomHeadroom;

        final cacheWidth = targetWidth.isFinite && targetWidth > 0
            ? math.min(targetWidth.round(), page.width)
            : page.width;

        return InteractiveViewer(
          minScale: 1,
          maxScale: _maxScale,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: AspectRatio(
                aspectRatio: page.aspectRatio,
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .16),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        page.bytes,
                        fit: BoxFit.contain,
                        cacheWidth: cacheWidth,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        semanticLabel: page.labelAr,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageCounter extends StatelessWidget {
  final String label;
  final String hint;

  const _PageCounter({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 17,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
