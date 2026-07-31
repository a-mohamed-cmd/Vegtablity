import 'package:flutter/material.dart';
import '../models/device_license.dart';
import '../services/license_api_service.dart';

class LicenseProvider extends ChangeNotifier {
  final LicenseApiService _apiService = LicenseApiService();

  List<String> _databases = [];
  String? _selectedDatabase;
  List<DeviceLicense> _licenses = [];
  Map<String, dynamic>? _companySettings;
  bool _isLoading = false;
  bool _isSettingsLoading = false;
  String? _errorMessage;

  List<String> get databases => _databases;
  String? get selectedDatabase => _selectedDatabase;
  List<DeviceLicense> get licenses => _licenses;
  Map<String, dynamic>? get companySettings => _companySettings;
  bool get isLoading => _isLoading;
  bool get isSettingsLoading => _isSettingsLoading;
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
        await fetchCompanySettings(_selectedDatabase!);
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = "فشل في تحميل قواعد البيانات من السيرفر";
      notifyListeners();
    }
  }

  void selectDatabase(String dbName) {
    if (_selectedDatabase == dbName && _companySettings != null) return;
    _selectedDatabase = dbName;
    _companySettings = null;
    _licenses = [];
    _isSettingsLoading = true;
    _isLoading = true;
    notifyListeners();
    fetchLicenses(dbName);
    fetchCompanySettings(dbName);
  }

  Future<void> fetchCompanySettings(String dbName) async {
    _isSettingsLoading = true;
    _companySettings = null;
    notifyListeners();
    try {
      final res = await _apiService.getCompanySettings(dbName);
      if (_selectedDatabase == dbName) {
        _companySettings = res;
        _isSettingsLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (_selectedDatabase == dbName) {
        _isSettingsLoading = false;
        _companySettings = null;
        notifyListeners();
      }
    }
  }

  Future<bool> saveCompanySettings(Map<String, dynamic> settings) async {
    if (_selectedDatabase == null) return false;
    _isSettingsLoading = true;
    notifyListeners();
    try {
      await _apiService.saveCompanySettings(_selectedDatabase!, settings);
      _companySettings = Map<String, dynamic>.from(settings);
      _isSettingsLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSettingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchLicenses(String dbName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.getLicenses(dbName);
      if (_selectedDatabase == dbName) {
        _licenses = res;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (_selectedDatabase == dbName) {
        _isLoading = false;
        _errorMessage = "فشل في تحميل الأجهزة المسجلة لقاعدة البيانات $dbName";
        _licenses = [];
        notifyListeners();
      }
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
