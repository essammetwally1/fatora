import 'package:flutter/material.dart';

/// Compact square button used for the export actions on an invoice.
///
/// PDF and image exports sit next to each other on the invoice card and in the
/// details app bar, so they share one shape, one size and one tap target and
/// differ only by icon and colour.
class ExportActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  final Widget icon;
  final double size;
  final double borderRadius;

  const ExportActionButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    required this.icon,
    this.size = 32,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isEnabled = onPressed != null;

    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.square(size),
          backgroundColor: color.withValues(alpha: isDark ? .18 : .10),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: color.withValues(alpha: isDark ? .28 : .18),
            ),
          ),
        ),
        // The PDF icon is an SVG that carries its own colour, so it ignores
        // the button's disabled foreground. Fading it here keeps a disabled
        // button looking disabled whichever icon it is given.
        icon: Opacity(opacity: isEnabled ? 1 : .38, child: icon),
      ),
    );
  }
}
