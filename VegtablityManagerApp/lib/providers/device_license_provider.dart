import 'package:flutter/material.dart';
import '../services/device_license_service.dart';

class DeviceLicenseProvider extends ChangeNotifier {
  final DeviceLicenseService _service = DeviceLicenseService();

  bool _isChecking = true;
  bool _isLicensed = false;
  bool _isActive = false;
  bool _isExpired = false;
  String? _hwid;
  String? _expiryDate;
  String? _errorMessage;

  DeviceLicenseProvider() {
    verifyLicense();
  }

  bool get isChecking => _isChecking;
  bool get isLicensed => _isLicensed;
  bool get isActive => _isActive;
  bool get isExpired => _isExpired;
  String? get hwid => _hwid;
  String? get expiryDate => _expiryDate;
  String? get errorMessage => _errorMessage;

  Future<void> verifyLicense() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _hwid = await DeviceLicenseService.getOrCreateHWID();
      final result = await _service.checkLicense(_hwid!);

      _isLicensed = result.isLicensed;
      _isActive = result.isActive;
      _isExpired = result.isExpired;
      _expiryDate = result.expiryDate;
      _errorMessage = result.errorMessage;
    } catch (e) {
      _isLicensed = false;
      _isActive = false;
      _isExpired = false;
      _errorMessage = 'خطأ أثناء فحص البصمة: $e';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}
