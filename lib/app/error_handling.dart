import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Process-wide error handling, installed once from `main`.
///
/// Without this, two things reach the user as raw Flutter internals. A build
/// error paints the grey `ErrorWidget` box with an English exception and a
/// stack trace in the middle of the screen, and an unhandled error on a
/// platform callback tears down the isolate. Neither is something an optician
/// standing in front of a customer can act on, and neither says the invoices
/// are safe — which is the only question they actually have.
void installErrorHandling() {
  // Keeps the red screen and the console dump in debug, where they are the
  // point, and reduces release builds to a logged line so a single bad frame
  // cannot take the app down.
  FlutterError.onError = (details) {
    if (kReleaseMode) {
      debugPrint('Fatora widget error: ${details.exceptionAsString()}');

      return;
    }

    FlutterError.presentError(details);
  };

  // Errors raised outside the widget tree — a failed platform channel, an
  // unawaited future — arrive here. Returning true marks them handled so they
  // do not terminate the isolate.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Fatora uncaught error:\nError: $error\n$stack');

    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _BrokenSectionPlaceholder();
  }
}

/// Stands in for whatever subtree failed to build.
///
/// Deliberately small and unstyled by the theme: it is drawn in place of a
/// widget that just threw, so it cannot assume a `Scaffold`, a `Directionality`
/// or a working theme above it.
class _BrokenSectionPlaceholder extends StatelessWidget {
  const _BrokenSectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'تعذر عرض هذا الجزء. بياناتك محفوظة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
