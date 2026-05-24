import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  bool _isLoading = false;
  bool _isInitialized = false; // Tracks if auto-login check completed
  String? _token;
  String? _username;
  String? _errorMessage;

  AuthProvider(this._apiService) {
    _tryAutoLogin();
  }

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get username => _username;
  String? get errorMessage => _errorMessage;

  Future<void> _tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('token') && prefs.containsKey('username')) {
        _token = prefs.getString('token');
        _username = prefs.getString('username');
        _apiService.updateToken(_token);
      }
    } catch (e) {
      // Handle error quietly
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        _token = data['token'] ?? data['access_token'];
        _username = username;
        
        // Update token in apiService
        _apiService.updateToken(_token);

        // Persist token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('username', _username!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء الاتصال بالخادم. يرجى المحاولة لاحقاً';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    _apiService.updateToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');

    notifyListeners();
  }
}
