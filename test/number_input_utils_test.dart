import 'package:fatora/core/utils/number_input_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDigits', () {
    test('converts Arabic-Indic digits to ASCII', () {
      expect(NumberInputUtils.normalizeDigits('١٢٣٤٥٦٧٨٩٠'), '1234567890');
    });

    test('converts Extended Arabic-Indic digits to ASCII', () {
      expect(NumberInputUtils.normalizeDigits('۱۲۳۴۵۶۷۸۹۰'), '1234567890');
    });

    test('leaves ASCII digits and other characters untouched', () {
      expect(NumberInputUtils.normalizeDigits('12.50'), '12.50');
      expect(NumberInputUtils.normalizeDigits(''), '');
    });

    test('handles a mix of digit systems', () {
      expect(NumberInputUtils.normalizeDigits('١2۳'), '123');
    });
  });

  group('parseAmount', () {
    test('parses plain and Arabic-Indic numbers', () {
      expect(NumberInputUtils.parseAmount('25'), 25.0);
      expect(NumberInputUtils.parseAmount('٢٥'), 25.0);
      expect(NumberInputUtils.parseAmount('  12.5  '), 12.5);
    });

    test('accepts Arabic and comma decimal separators', () {
      expect(NumberInputUtils.parseAmount('12٫5'), 12.5);
      expect(NumberInputUtils.parseAmount('12,5'), 12.5);
    });

    test('returns null for empty or separator-only input', () {
      expect(NumberInputUtils.parseAmount(''), isNull);
      expect(NumberInputUtils.parseAmount('   '), isNull);
      expect(NumberInputUtils.parseAmount('.'), isNull);
      expect(NumberInputUtils.parseAmount('٫'), isNull);
    });

    test('returns null for unparseable input', () {
      expect(NumberInputUtils.parseAmount('abc'), isNull);
      expect(NumberInputUtils.parseAmount('1.2.3'), isNull);
    });

    test('distinguishes zero from no input', () {
      expect(NumberInputUtils.parseAmount('0'), 0.0);
      expect(NumberInputUtils.parseAmount(''), isNull);
    });
  });

  group('formatForInput', () {
    test('drops the decimal part for whole numbers', () {
      expect(NumberInputUtils.formatForInput(25), '25');
      expect(NumberInputUtils.formatForInput(1000), '1000');
    });

    test('keeps meaningful decimals and trims trailing zeros', () {
      expect(NumberInputUtils.formatForInput(12.5), '12.5');
      expect(NumberInputUtils.formatForInput(12.25), '12.25');
    });

    test('returns empty for non-positive or non-finite values', () {
      expect(NumberInputUtils.formatForInput(0), '');
      expect(NumberInputUtils.formatForInput(-5), '');
      expect(NumberInputUtils.formatForInput(double.nan), '');
      expect(NumberInputUtils.formatForInput(double.infinity), '');
    });

    test('round-trips through parseAmount', () {
      for (final value in <double>[25, 12.5, 0.75, 1999.99]) {
        final text = NumberInputUtils.formatForInput(value);
        expect(NumberInputUtils.parseAmount(text), closeTo(value, 0.001));
      }
    });
  });

  group('safePositive', () {
    test('clamps negatives and non-finite values to zero', () {
      expect(NumberInputUtils.safePositive(-1), 0.0);
      expect(NumberInputUtils.safePositive(double.nan), 0.0);
      expect(NumberInputUtils.safePositive(double.infinity), 0.0);
    });

    test('passes valid values through', () {
      expect(NumberInputUtils.safePositive(12.5), 12.5);
      expect(NumberInputUtils.safePositive(0), 0.0);
    });
  });

  group('PositiveDecimalTextInputFormatter', () {
    const formatter = PositiveDecimalTextInputFormatter();

    TextEditingValue apply(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(text: newText),
      );
    }

    test('accepts digits and up to two decimals', () {
      expect(apply('', '12').text, '12');
      expect(apply('12', '12.5').text, '12.5');
      expect(apply('12.5', '12.55').text, '12.55');
      expect(apply('', '٢٥').text, '٢٥');
    });

    test('rejects a third decimal digit', () {
      expect(apply('12.55', '12.555').text, '12.55');
    });

    test('rejects letters and signs', () {
      expect(apply('12', '12a').text, '12');
      expect(apply('12', '-12').text, '12');
    });

    test('always allows clearing the field', () {
      expect(apply('12.5', '').text, '');
    });
  });
}
