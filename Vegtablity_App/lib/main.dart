import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/printer_service.dart';
import 'providers/auth_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/license_provider.dart';
import 'screens/license_check_screen.dart';

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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vegtablity POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LicenseCheckScreen(),
    );
  }
}
