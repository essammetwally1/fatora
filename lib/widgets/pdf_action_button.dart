import 'package:fatora/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'common/export_action_button.dart';

class PdfActionButton extends StatelessWidget {
  /// Null disables the button, for when an export cannot be started yet.
  final VoidCallback? onPressed;
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
    return ExportActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      color: AppTheme.red,
      size: size,
      borderRadius: borderRadius,
      icon: SvgPicture.asset(_pdfIcon, width: iconSize, height: iconSize),
    );
  }
}

/// Exports the invoice as image(s) — the same layout as the PDF, rendered to
/// PNG so it can be sent straight into a chat.
class ImageActionButton extends StatelessWidget {
  /// Null disables the button, for when an export cannot be started yet.
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final double borderRadius;

  const ImageActionButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'تصدير كصورة',
    this.size = 32,
    this.iconSize = 19,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ExportActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      color: AppTheme.blue,
      size: size,
      borderRadius: borderRadius,
      icon: Icon(Icons.image_outlined, size: iconSize),
    );
  }
}
