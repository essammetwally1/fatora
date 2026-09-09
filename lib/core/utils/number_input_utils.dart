import 'package:flutter/services.dart';

/// Shared parsing/formatting helpers for money input fields.
///
/// Before this existed, the Arabic-digit table, the price parser, the
/// "number back to editable text" helper and the input formatter were each
/// copy-pasted into `invoice_item_sheet`, `invoice_payment_summary_card` and
/// `fixed_menu_item_dialog` — with small behavioural differences between the
/// copies. Everything money-input related now lives here.
class NumberInputUtils {
  const NumberInputUtils._();

  /// Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits, in the order
  /// their code points appear, so lookup can be done arithmetically instead of
  /// by 20 successive `replaceAll` passes.
  static const int _arabicIndicZero = 0x0660;
  static const int _extendedArabicIndicZero = 0x06F0;
  static const int _asciiZero = 0x30;

  /// Converts Arabic-Indic digits to ASCII and unifies the decimal separator.
  ///
  /// Accepts `٫` (Arabic decimal separator) and `,` as decimal points, because
  /// both keyboards are common for Arabic users.
  static String normalizeDigits(String value) {
    if (value.isEmpty) return value;

    final buffer = StringBuffer();

    for (final codeUnit in value.runes) {
      if (codeUnit >= _arabicIndicZero && codeUnit <= _arabicIndicZero + 9) {
        buffer.writeCharCode(_asciiZero + (codeUnit - _arabicIndicZero));
        continue;
      }

      if (codeUnit >= _extendedArabicIndicZero &&
          codeUnit <= _extendedArabicIndicZero + 9) {
        buffer.writeCharCode(
          _asciiZero + (codeUnit - _extendedArabicIndicZero),
        );
        continue;
      }

      buffer.writeCharCode(codeUnit);
    }

    return buffer.toString();
  }

  /// Parses user-typed money text into a finite double.
  ///
  /// Returns null for empty input, a lone separator, or anything unparseable,
  /// so callers can distinguish "nothing typed yet" from "typed zero".
  static double? parseAmount(String value) {
    final clean = normalizeDigits(
      value.trim().replaceAll('٫', '.').replaceAll(',', '.'),
    );

    if (clean.isEmpty || clean == '.') {
      return null;
    }

    final parsed = double.tryParse(clean);

    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  /// Renders a stored amount back into editable text.
  ///
  /// Whole numbers lose the decimal part (`25` not `25.00`) and trailing zeros
  /// are trimmed, so re-opening an edit form does not show noise.
  static String formatForInput(double value) {
    if (!value.isFinite || value <= 0) {
      return '';
    }

    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Clamps a value to a non-negative, finite double.
  static double safePositive(double value) {
    if (!value.isFinite || value < 0) return 0.0;
    return value;
  }
}

/// Allows only non-negative decimals with at most two fraction digits,
/// in either ASCII or Arabic-Indic digits.
class PositiveDecimalTextInputFormatter extends TextInputFormatter {
  const PositiveDecimalTextInputFormatter();

  static final RegExp _validInput = RegExp(
    r'^[0-9٠-٩۰-۹]*([.,٫][0-9٠-٩۰-۹]{0,2})?$',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();

    if (text.isEmpty || _validInput.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
