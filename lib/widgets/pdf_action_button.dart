import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PdfActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final double borderRadius;

  const PdfActionButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'خيارات PDF',
    this.size = 32,
    this.iconSize = 18,
    this.borderRadius = 12,
  });

  static const String _pdfIcon = 'assets/icons/pdf.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          backgroundColor: AppTheme.red.withValues(alpha: isDark ? .18 : .10),
          foregroundColor: AppTheme.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: AppTheme.red.withValues(alpha: isDark ? .28 : .18),
            ),
          ),
        ),
        icon: SvgPicture.asset(_pdfIcon, width: iconSize, height: iconSize),
      ),
    );
  }
}
