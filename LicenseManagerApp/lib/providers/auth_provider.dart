import 'package:flutter/material.dart';
import '../core/ctrl_token_manager.dart';
import '../services/license_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final LicenseApiService _apiService = LicenseApiService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => CtrlTokenManager.hasToken;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _apiService.login(username, password);
      CtrlTokenManager.setToken(token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "بيانات الدخول غير صحيحة أو فشل الاتصال بالسيرفر";
      notifyListeners();
      return false;
    }
  }

  void logout() {
    CtrlTokenManager.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
