import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'app/startup_failure_app.dart';
import 'data/services/storage/hive_service.dart';
import 'providers/invoice_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeDateFormatting('ar');

  // The device is the only copy of the client's invoices, so a storage that
  // refuses to open must say so rather than crash to a black screen.
  try {
    await HiveService.init();
  } catch (error, stackTrace) {
    debugPrint('Fatora storage failed to open:\nError: $error\n$stackTrace');

    runApp(StartupFailureApp(error: error));

    return;
  }

  runApp(const FatoraApp());
}

class FatoraApp extends StatelessWidget {
  const FatoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<InvoiceProvider>(
          create: (_) => InvoiceProvider(),
        ),
        ChangeNotifierProvider<FixedMenuProvider>(
          create: (_) => FixedMenuProvider()..loadMenu(notify: false),
        ),
      ],
      // Only the theme slice of SettingsProvider is watched, so unrelated
      // settings changes cannot rebuild the whole app.
      child: Selector<SettingsProvider, ThemeMode>(
        selector: (_, settings) => settings.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            builder: (context, child) {
              final toastHost = FToastBuilder()(context, child);

              return Directionality(
                // Applied once here instead of being re-wrapped inside every
                // screen, sheet and dialog.
                textDirection: TextDirection.rtl,
                child: MediaQuery.withClampedTextScaling(
                  // Guards the dense money/status rows against extreme system
                  // font sizes without ignoring the user's preference.
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.4,
                  child: toastHost,
                ),
              );
            },

            debugShowCheckedModeBanner: false,
            title: 'Fatora',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

// flutter clean
// flutter pub get
// flutter build apk --release
// flutter build web --release
// firebase deploy --only hosting

// flutter build apk --split-per-abi
