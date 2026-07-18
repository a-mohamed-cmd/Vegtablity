import 'package:flutter/material.dart';
import '../models/device_license.dart';
import '../services/license_api_service.dart';

class LicenseProvider extends ChangeNotifier {
  final LicenseApiService _apiService = LicenseApiService();

  List<String> _databases = [];
  String? _selectedDatabase;
  List<DeviceLicense> _licenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get databases => _databases;
  String? get selectedDatabase => _selectedDatabase;
  List<DeviceLicense> get licenses => _licenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDatabases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _databases = await _apiService.getDatabases();
      if (_databases.isNotEmpty && _selectedDatabase == null) {
        _selectedDatabase = _databases.first;
      }
      _isLoading = false;
      notifyListeners();
      if (_selectedDatabase != null) {
        await fetchLicenses(_selectedDatabase!);
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = "فشل في تحميل قواعد البيانات من السيرفر";
      notifyListeners();
    }
  }

  void selectDatabase(String dbName) {
    _selectedDatabase = dbName;
    notifyListeners();
    fetchLicenses(dbName);
  }

  Future<void> fetchLicenses(String dbName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _licenses = await _apiService.getLicenses(dbName);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = "فشل في تحميل الأجهزة المسجلة لقاعدة البيانات $dbName";
      _licenses = [];
      notifyListeners();
    }
  }

  Future<bool> saveDevice(DeviceLicense license) async {
    if (_selectedDatabase == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.saveLicense(_selectedDatabase!, license);
      _isLoading = false;
      notifyListeners();
      await fetchLicenses(_selectedDatabase!);
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "فشل في حفظ بيانات الجهاز";
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDevice(int licenseId) async {
    if (_selectedDatabase == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteLicense(_selectedDatabase!, licenseId);
      _isLoading = false;
      notifyListeners();
      await fetchLicenses(_selectedDatabase!);
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "فشل في حذف الجهاز من السيرفر";
      notifyListeners();
      return false;
    }
  }
}
