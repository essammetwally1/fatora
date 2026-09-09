import 'package:fatora/app/app_theme.dart';
import 'package:fatora/widgets/common/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStatusColors', () {
    test('is registered on both themes', () {
      expect(
        AppTheme.lightTheme.extension<AppStatusColors>(),
        AppTheme.lightStatusColors,
      );
      expect(
        AppTheme.darkTheme.extension<AppStatusColors>(),
        AppTheme.darkStatusColors,
      );
    });

    test('light and dark use different success tones', () {
      // Dark mode previously reused the light-mode green, which was too dark
      // to read against the dark surfaces.
      expect(
        AppTheme.lightStatusColors.success,
        isNot(AppTheme.darkStatusColors.success),
      );
    });

    test('lerp interpolates every channel', () {
      final mid = AppTheme.lightStatusColors.lerp(
        AppTheme.darkStatusColors,
        1.0,
      );

      expect(mid, AppTheme.darkStatusColors);
    });

    test('copyWith replaces only the named field', () {
      final updated = AppTheme.lightStatusColors.copyWith(
        success: const Color(0xFF000000),
      );

      expect(updated.success, const Color(0xFF000000));
      expect(updated.danger, AppTheme.lightStatusColors.danger);
    });
  });

  group('context.statusColors', () {
    testWidgets('resolves from the ambient theme', (tester) async {
      late AppStatusColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              resolved = context.statusColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, AppTheme.darkStatusColors);
    });

    testWidgets('falls back when the extension is absent', (tester) async {
      late AppStatusColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              resolved = context.statusColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, AppTheme.lightStatusColors);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders title, message and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'لا توجد فواتير',
              message: 'ابدأ بإضافة أول فاتورة',
            ),
          ),
        ),
      );

      expect(find.text('لا توجد فواتير'), findsOneWidget);
      expect(find.text('ابدأ بإضافة أول فاتورة'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('shows a spinner instead of the icon while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'جاري التحميل',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    });

    testWidgets('does not overflow in a short viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'عنوان طويل جدا لاختبار التجاوز في الشاشات الصغيرة',
              message: 'رسالة طويلة جدا لاختبار التجاوز في الشاشات الصغيرة جدا',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
