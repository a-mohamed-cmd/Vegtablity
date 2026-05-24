import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LicenseProvider extends ChangeNotifier {
  final ApiService _apiService;
  bool _isChecking = true;
  bool _isLicensed = false;
  String? _hwid;
  String? _errorMessage;
  String? _expiryDate;
  bool _isActive = false;
  bool _isExpired = false;

  LicenseProvider(this._apiService) {
    checkDeviceLicense();
  }

  bool get isChecking => _isChecking;
  bool get isLicensed => _isLicensed;
  String? get hwid => _hwid;
  String? get errorMessage => _errorMessage;
  String? get expiryDate => _expiryDate;
  bool get isActive => _isActive;
  bool get isExpired => _isExpired;

  String _generateRandomHWID() {
    final random = Random();
    const chars = '0123456789ABCDEF';
    return List.generate(16, (index) => chars[random.nextInt(16)]).join();
  }

  Future<void> checkDeviceLicense() async {
    _isChecking = true;
    _errorMessage = null;
    _expiryDate = null;
    _isActive = false;
    _isExpired = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get or generate stable persistent HWID
      String? cachedHwid = prefs.getString('machine_hwid');
      if (cachedHwid == null) {
        cachedHwid = _generateRandomHWID();
        await prefs.setString('machine_hwid', cachedHwid);
      }
      _hwid = cachedHwid;

      // Check with API
      final response = await _apiService.checkLicense(_hwid!);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is bool) {
          _isLicensed = data;
          _isActive = data;
          _isExpired = false;
          _expiryDate = null;
        } else if (data is Map) {
          _isLicensed = (data['IsLicensed'] == true) ||
              (data['isLicensed'] == true) ||
              (data['IsLicensed'] == 1) ||
              (data['IsLicensed'] == 'True');
          _isActive = (data['IsActive'] == true) ||
              (data['isActive'] == true) ||
              (data['IsActive'] == 1) ||
              (data['IsActive'] == 'True');
          _isExpired = (data['IsExpired'] == true) ||
              (data['isExpired'] == true) ||
              (data['IsExpired'] == 1) ||
              (data['IsExpired'] == 'True');
          _expiryDate = data['ExpiryDate']?.toString();
        } else {
          _isLicensed = false;
          _isActive = false;
          _isExpired = false;
          _expiryDate = null;
        }
      } else {
        _isLicensed = false;
        _isActive = false;
        _isExpired = false;
        _expiryDate = null;
        _errorMessage = 'فشل التحقق من الترخيص بالخادم الخلفي';
      }
    } catch (e) {
      // API Offline/Fallback handling for developer testing:
      _isLicensed = false;
      _isActive = false;
      _isExpired = false;
      _expiryDate = null;
      _errorMessage =
          'تعذر الاتصال بخادم التراخيص. يرجى التأكد من جودة الإنترنت';
    }

    _isChecking = false;
    notifyListeners();
  }
}
