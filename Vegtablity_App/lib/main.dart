import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/printer_service.dart';
import 'providers/auth_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/voucher_provider.dart';
import 'providers/account_provider.dart';
import 'providers/license_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/wastage_provider.dart';
import 'providers/stocktake_provider.dart';
import 'screens/license_check_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'viewmodels/language_viewmodel.dart';
import 'core/localization/app_localizations.dart';

void main() {
  final apiService = ApiService();
  final printerService = PrinterService(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<PrinterService>.value(value: printerService),
        ChangeNotifierProvider<LicenseProvider>(
          create: (context) => LicenseProvider(apiService),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(apiService),
        ),
        ChangeNotifierProvider<ShiftProvider>(
          create: (context) => ShiftProvider(apiService),
        ),
        ChangeNotifierProvider<PosProvider>(
          create: (context) => PosProvider(apiService),
        ),
        ChangeNotifierProvider<VoucherProvider>(
          create: (context) => VoucherProvider(apiService),
        ),
        ChangeNotifierProvider<AccountProvider>(
          create: (context) => AccountProvider(apiService),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (context) => SettingsProvider(apiService)..fetchSettings(),
        ),
        ChangeNotifierProvider<WastageProvider>(
          create: (context) => WastageProvider(apiService),
        ),
        ChangeNotifierProvider<StockTakeProvider>(
          create: (context) => StockTakeProvider(apiService),
        ),
        ChangeNotifierProvider<LanguageViewModel>(
          create: (context) => LanguageViewModel(),
        ),
      ],
      child: const MyApp(),
    ),
  );

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageViewModel>(
      builder: (context, languageViewModel, child) {
        return MaterialApp(
          title: 'Vegtablity POS',
          locale: languageViewModel.appLocale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: const LicenseCheckScreen(),
        );
      },
    );
  }
}
