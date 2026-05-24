import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'shift_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // If still initializing (reading credentials from local storage), show simple loader
    if (!authProvider.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    // If authenticated, navigate to ShiftScreen (or HomeScreen), else LoginScreen
    if (authProvider.isAuthenticated) {
      return const ShiftScreen();
    } else {
      return const LoginScreen();
    }
  }
}
