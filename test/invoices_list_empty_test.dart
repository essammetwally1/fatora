import 'package:fatora/app/app_theme.dart';
import 'package:fatora/providers/invoice_provider.dart';
import 'package:fatora/widgets/home/invoices_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The empty and "nothing found" placeholders are drawn inside a
/// `SliverFillRemaining`, which measures its child's intrinsic height. A
/// placeholder that brings its own scroll view cannot answer that and throws
/// during layout — so the states with nothing to list are exercised here as
/// carefully as the states with something in them.
void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    required bool hasSearchQuery,
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<InvoiceProvider>(
        create: (_) => InvoiceProvider(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicesList(
                invoices: const [],
                totalInvoiceCount: 0,
                hasSearchQuery: hasSearchQuery,
                scrollController: controller,
                onEditInvoice: (_) {},
                onDeleteInvoice: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('an empty month lays out', (tester) async {
    await pumpList(tester, hasSearchQuery: false);

    expect(tester.takeException(), isNull);
    expect(find.text('لا توجد فواتير بعد'), findsOneWidget);
  });

  testWidgets('a search with no matches lays out', (tester) async {
    await pumpList(tester, hasSearchQuery: true);

    expect(tester.takeException(), isNull);
    expect(find.text('لا توجد فواتير مطابقة'), findsOneWidget);
  });

  testWidgets('a small phone at the largest allowed font lays out', (
    tester,
  ) async {
    await pumpList(tester, hasSearchQuery: true, size: const Size(320, 480));

    expect(tester.takeException(), isNull);
  });
}
