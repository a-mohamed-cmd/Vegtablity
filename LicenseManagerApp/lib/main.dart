import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/license_provider.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LicenseManagerApp());
}

class LicenseManagerApp extends StatefulWidget {
  const LicenseManagerApp({super.key});

  @override
  State<LicenseManagerApp> createState() => _LicenseManagerAppState();
}

class _LicenseManagerAppState extends State<LicenseManagerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize API Client with a callback to redirect to login on token expiration (401)
    ApiClient.initialize(() {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      
      // Show snackbar message if navigator context is available
      final context = _navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى.")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
      ],
      child: MaterialApp(
        title: 'إدارة التراخيص والمشرفين',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
          ),
          fontFamily: 'Inter',
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
