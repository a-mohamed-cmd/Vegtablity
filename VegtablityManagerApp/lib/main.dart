import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'providers/auth_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/device_license_provider.dart';
import 'screens/login_screen.dart';
import 'screens/manager_main_screen.dart';
import 'screens/device_license_screen.dart';

void dismissWebLoader() {
  if (kIsWeb) {
    try {
      final loader = html.document.getElementById('loading');
      if (loader != null) {
        loader.style.opacity = '0';
        loader.style.pointerEvents = 'none';
        Future.delayed(const Duration(milliseconds: 250), () {
          try {
            loader.remove();
          } catch (_) {}
        });
      }
    } catch (_) {}
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VegtablityManagerApp());
}

class VegtablityManagerApp extends StatelessWidget {
  const VegtablityManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceLicenseProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: MaterialApp(
        title: 'لوحة الإدارة والتقارير التنفيذية | Vegtablity Manager',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Colors.amber,
            onPrimary: Color(0xFF0F172A),
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
          textTheme: GoogleFonts.cairoTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    dismissWebLoader();
    final license = Provider.of<DeviceLicenseProvider>(context);

    // 1. Device License Verification Phase
    if (license.isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 20),
              Text(
                "جاري التحقق من ترخيص الجهاز...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!license.isLicensed) {
      return const DeviceLicenseScreen();
    }

    // 2. User Authentication Phase (Once Device is Licensed)
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 20),
              Text(
                "جاري تهيئة لوحة الإدارة...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isLoggedIn) {
      return const ManagerMainScreen();
    }

    return const LoginScreen();
  }
}
