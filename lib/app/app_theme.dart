import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF5669FF);
  static const Color gray = Color(0xFF7B7B7B);
  static const Color backgroundWhite = Color(0xFFF2FEFF);
  static const Color backgroundDark = Color(0xFF101127);
  static const Color black = Color(0xFF1C1C1C);
  static const Color red = Color(0xFFFF5659);
  static const Color green = Colors.green;

  static ThemeData lightTheme = _theme(
    brightness: Brightness.light,
    scaffoldBackground: backgroundWhite,
    surface: Colors.white,
    onSurface: black,
  );

  static ThemeData darkTheme = _theme(
    brightness: Brightness.dark,
    scaffoldBackground: backgroundDark,
    surface: const Color(0xFF181A35),
    onSurface: backgroundWhite,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
    required Color onSurface,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      error: red,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: surface,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontSize: 15,
          color: brightness == Brightness.dark ? backgroundWhite : gray,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: .05)
            : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary.withValues(alpha: .45)),
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
        bodyMedium: TextStyle(fontSize: 14, color: onSurface),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
