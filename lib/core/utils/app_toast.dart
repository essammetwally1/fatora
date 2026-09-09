import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../app/app_theme.dart';

enum AppToastType { success, error, info }

class AppToast {
  AppToast._();

  static final FToast _fToast = FToast();

  static void showSuccess(BuildContext context, {required String message}) {
    _show(context, message: message, type: AppToastType.success);
  }

  static void showError(BuildContext context, {required String message}) {
    _show(
      context,
      message: message,
      type: AppToastType.error,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(BuildContext context, {required String message}) {
    _show(context, message: message, type: AppToastType.info);
  }

  static void hide() {
    _fToast.removeCustomToast();
    _fToast.removeQueuedCustomToasts();
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    _fToast.init(context);

    // Prevent old messages from accumulating in a queue.
    _fToast.removeCustomToast();
    _fToast.removeQueuedCustomToasts();

    _fToast.showToast(
      gravity: ToastGravity.CENTER,
      toastDuration: duration,
      fadeDuration: const Duration(milliseconds: 220),
      ignorePointer: true,
      isDismissible: true,
      child: _AppToastContent(message: cleanMessage, type: type),
    );
  }
}

class _AppToastContent extends StatelessWidget {
  final String message;
  final AppToastType type;

  const _AppToastContent({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColors = context.statusColors;

    final foregroundColor = _foregroundColor(colorScheme, statusColors);
    final backgroundColor = _backgroundColor(colorScheme, statusColors);
    final borderColor = _borderColor(colorScheme, statusColors);
    final icon = _icon;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Semantics(
        liveRegion: true,
        label: message,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54, maxWidth: 520),
            child: Material(
              color: backgroundColor,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: foregroundColor.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: foregroundColor, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (type) {
      AppToastType.success => Icons.check_circle_outline_rounded,
      AppToastType.error => Icons.error_outline_rounded,
      AppToastType.info => Icons.info_outline_rounded,
    };
  }

  /// Success used fixed `Colors.green` shades, which stayed light-mode green on
  /// a dark surface. It now follows the themed status palette like the rest.
  Color _foregroundColor(ColorScheme colorScheme, AppStatusColors status) {
    return switch (type) {
      AppToastType.success => status.success,
      AppToastType.error => colorScheme.error,
      AppToastType.info => colorScheme.primary,
    };
  }

  Color _backgroundColor(ColorScheme colorScheme, AppStatusColors status) {
    return switch (type) {
      AppToastType.success => Color.alphaBlend(
        status.success.withValues(alpha: .12),
        colorScheme.surface,
      ),
      AppToastType.error => colorScheme.errorContainer,
      AppToastType.info => colorScheme.primaryContainer,
    };
  }

  Color _borderColor(ColorScheme colorScheme, AppStatusColors status) {
    return switch (type) {
      AppToastType.success => status.success.withValues(alpha: .30),
      AppToastType.error => colorScheme.error.withValues(alpha: .28),
      AppToastType.info => colorScheme.primary.withValues(alpha: .25),
    };
  }
}
