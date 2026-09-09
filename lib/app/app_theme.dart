import 'package:flutter/material.dart';

/// Spacing scale. Use these instead of loose magic numbers so vertical rhythm
/// stays consistent between screens.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Bottom padding for scrollables that sit under a floating action button.
  static const double fabScrollInset = 104;
}

/// Corner-radius scale.
class AppRadii {
  const AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double sheet = 28;

  /// Fully rounded pill.
  static const double pill = 999;
}

/// Status colours that carry meaning (paid / partially paid / unpaid).
///
/// These were previously written as bare `Colors.green` / `Colors.blue`
/// literals across six files, which meant they never adapted to dark mode and
/// could not be changed in one place.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  /// Fully paid.
  final Color success;

  /// Partially paid / informational.
  final Color info;

  /// Unpaid / destructive.
  final Color danger;

  /// Readable foreground for [success] on a filled surface.
  final Color onSuccess;

  const AppStatusColors({
    required this.success,
    required this.info,
    required this.danger,
    required this.onSuccess,
  });

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? info,
    Color? danger,
    Color? onSuccess,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;

    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    );
  }

  // Value equality, not identity. `lerp` and `copyWith` hand back new
  // instances, so without this two palettes holding the same four colours
  // compare unequal and Flutter redoes theme-dependent work on every rebuild
  // that produces a fresh extension.
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppStatusColors &&
            success == other.success &&
            info == other.info &&
            danger == other.danger &&
            onSuccess == other.onSuccess;
  }

  @override
  int get hashCode => Object.hash(success, info, danger, onSuccess);
}

/// Convenient, null-safe access to the status palette.
extension AppThemeContext on BuildContext {
  AppStatusColors get statusColors {
    return Theme.of(this).extension<AppStatusColors>() ??
        AppTheme.lightStatusColors;
  }
}

class AppTheme {
  static const Color primary = Color(0xFF5669FF);
  static const Color gray = Color(0xFF7B7B7B);
  static const Color backgroundWhite = Color(0xFFF2FEFF);
  static const Color backgroundDark = Color(0xFF101127);
  static const Color black = Color(0xFF1C1C1C);
  static const Color red = Color(0xFFFF5659);
  static const Color green = Color(0xFF22C55E);
  static const Color blue = Color(0xFF3B82F6);

  static const Color _lightSurface = Colors.white;
  static const Color _darkSurface = Color(0xFF1A1B35);
  static const Color _darkSurfaceHigh = Color(0xFF242544);
  static const Color _lightOnSurface = black;
  static const Color _darkOnSurface = Color(0xFFF4F7FB);
  static const Color primaryDark = Color(0xFF3E4EE8);
  static const Color primaryLight = Color(0xFF7D8BFF);
  static const Color primaryGlow = Color(0xFFB8C0FF);

  /// Dark-mode variants are lightened so they keep sufficient contrast against
  /// the dark surfaces. `Colors.green` used raw was too dark to read there.
  static const AppStatusColors lightStatusColors = AppStatusColors(
    success: Color(0xFF15803D),
    info: blue,
    danger: red,
    onSuccess: Colors.white,
  );

  static const AppStatusColors darkStatusColors = AppStatusColors(
    success: Color(0xFF4ADE80),
    info: Color(0xFF60A5FA),
    danger: Color(0xFFFF7A7C),
    onSuccess: Color(0xFF06280F),
  );

  static final ThemeData lightTheme = _theme(
    brightness: Brightness.light,
    scaffoldBackground: backgroundWhite,
    surface: _lightSurface,
    surfaceContainerHighest: const Color(0xFFE8F2F7),
    onSurface: _lightOnSurface,
    onSurfaceVariant: const Color(0xFF5F6673),
    statusColors: lightStatusColors,
  );

  static final ThemeData darkTheme = _theme(
    brightness: Brightness.dark,
    scaffoldBackground: backgroundDark,
    surface: _darkSurface,
    surfaceContainerHighest: _darkSurfaceHigh,
    onSurface: _darkOnSurface,
    onSurfaceVariant: const Color(0xFFC4C8D4),
    statusColors: darkStatusColors,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
    required Color surfaceContainerHighest,
    required Color onSurface,
    required Color onSurfaceVariant,
    required AppStatusColors statusColors,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      error: red,
      surface: surface,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: surface,
      dividerColor: onSurfaceVariant.withValues(alpha: .24),
      hintColor: onSurfaceVariant,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      extensions: <ThemeExtension<dynamic>>[statusColors],

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: primary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: primary,
        ),
        iconTheme: const IconThemeData(size: 28, color: primary),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: onSurfaceVariant, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: black,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontSize: 15,
          color: onSurfaceVariant.withValues(alpha: .78),
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: primary,
        suffixIconColor: onSurfaceVariant,
        filled: true,
        fillColor: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: .06)
            : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary.withValues(alpha: .35)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: onSurfaceVariant.withValues(alpha: .18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: red, width: 1.4),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: .22),
        selectionHandleColor: primary,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: onSurface),
        bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariant),
        labelMedium: TextStyle(fontSize: 12, color: onSurfaceVariant),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          side: BorderSide(color: primary.withValues(alpha: .40)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          minimumSize: const Size.fromHeight(46),
        ),
      ),

      // Sheets previously passed their own colour/shape at every call site.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? surfaceContainerHighest
            : black,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark ? onSurface : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        actionTextColor: primaryLight,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: onSurfaceVariant.withValues(alpha: .20),
        thickness: 1,
        space: 1,
      ),

      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: black.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        iconColor: onSurfaceVariant,
      ),

      iconTheme: IconThemeData(color: onSurfaceVariant),
    );
  }
}
