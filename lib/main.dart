import 'package:fatora/providers/fixed_menu_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'data/services/storage/hive_service.dart';
import 'providers/invoice_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeDateFormatting('ar');
  await HiveService.init();

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
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            builder: FToastBuilder(),

            debugShowCheckedModeBanner: false,
            title: 'Fatora',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
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
