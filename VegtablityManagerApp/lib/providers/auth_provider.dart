import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../models/company_settings_model.dart';
import '../models/user_session_model.dart';
import '../services/auth_service.dart';
import '../services/company_settings_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final CompanySettingsService _settingsService = CompanySettingsService();

  UserSessionModel? _currentUser;
  UserSessionModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null && _currentUser!.accessToken.isNotEmpty;

  CompanySettingsModel? _companySettings;
  CompanySettingsModel? get companySettings => _companySettings;

  bool _isLoadingCompanySettings = false;
  bool get isLoadingCompanySettings => _isLoadingCompanySettings;
  String? _loadedCompanyDb;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final defaultCompany = AppConfig.detectDefaultCompany();
      await fetchCompanySettings(database: defaultCompany.id);

      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('user_session');
      if (sessionJson != null && sessionJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(sessionJson);
        _currentUser = UserSessionModel.fromJson(data);
        ApiClient().setAuthToken(_currentUser!.accessToken);
      }
    } catch (e) {
      debugPrint('Error initializing auth session: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    String? database,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetDb = database ?? AppConfig.detectDefaultCompany().id;
      final session = await _authService.login(
        username: username,
        password: password,
        database: targetDb,
      );

      _currentUser = session;
      ApiClient().setAuthToken(session.accessToken);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_session', jsonEncode(session.toJson()));

      // Refresh company settings
      await fetchCompanySettings(database: targetDb, force: true);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCompanySettings({String? database, bool force = false}) async {
    final targetDb = database ?? AppConfig.detectDefaultCompany().id;
    if (!force && _loadedCompanyDb == targetDb && _companySettings != null) {
      return;
    }

    _isLoadingCompanySettings = true;
    notifyListeners();

    try {
      final settings = await _settingsService.getCompanySettings(database: targetDb);
      if (settings != null) {
        _companySettings = settings;
        _loadedCompanyDb = targetDb;
      }
    } catch (e) {
      debugPrint('Error loading company settings for $targetDb: $e');
    } finally {
      _isLoadingCompanySettings = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    ApiClient().setAuthToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');

    notifyListeners();
  }
}
