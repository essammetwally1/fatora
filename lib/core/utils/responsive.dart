import 'package:flutter/material.dart';

/// Screen-size buckets used across the app.
enum ScreenSize {
  /// Narrow phones (< 360dp). Layouts drop to a single column and shrink gaps.
  compact,

  /// Regular phones.
  medium,

  /// Large phones / small tablets in portrait.
  expanded,

  /// Tablets and desktop windows.
  large,
}

/// Centralised breakpoints and layout metrics.
///
/// Individual widgets previously hard-coded their own thresholds (`< 340`,
/// `< 350`, `< 360`, `< 380`, `< 390`, `< 600`). They now agree on one scale.
class Responsive {
  const Responsive._();

  static const double compactBreakpoint = 360;
  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 900;

  /// Reading-comfortable maximum for the main content column.
  ///
  /// Without this, an invoice card on a tablet stretches edge to edge while its
  /// action column stays 110dp wide, leaving a huge empty gap in the middle.
  static const double maxContentWidth = 720;

  /// Modal sheets and dialogs stay a little narrower than the page content.
  static const double maxSheetWidth = 620;

  static ScreenSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static ScreenSize fromWidth(double width) {
    if (width < compactBreakpoint) return ScreenSize.compact;
    if (width < mediumBreakpoint) return ScreenSize.medium;
    if (width < expandedBreakpoint) return ScreenSize.expanded;
    return ScreenSize.large;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= mediumBreakpoint;
  }

  /// Horizontal page padding that grows with the viewport.
  static double horizontalPadding(double width) {
    if (width < compactBreakpoint) return 12;
    if (width < mediumBreakpoint) return 16;
    return 24;
  }
}

/// Centres its child and caps its width on wide screens.
///
/// On phones this is a no-op, so phone layouts are unchanged.
class ContentWidthLimiter extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ContentWidthLimiter({
    super.key,
    this.maxWidth = Responsive.maxContentWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Extra horizontal inset needed to centre a [maxWidth]-wide column inside
/// [availableWidth].
///
/// Slivers cannot be wrapped in [ContentWidthLimiter] without breaking
/// scrolling, so sliver-based screens add this to their `SliverPadding`
/// instead. Returns 0 on phones.
double centeringInset({
  required double availableWidth,
  double maxWidth = Responsive.maxContentWidth,
}) {
  final overflow = availableWidth - maxWidth;
  return overflow <= 0 ? 0 : overflow / 2;
}
