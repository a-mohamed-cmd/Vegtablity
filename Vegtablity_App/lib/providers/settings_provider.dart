import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService;
  
  Map<String, dynamic>? _companySettings;
  String _currencySymbol = "د.ك";
  bool _isLoading = false;

  SettingsProvider(this._apiService) {
    fetchSettings();
  }

  Map<String, dynamic>? get companySettings => _companySettings;
  String get currencySymbol => _currencySymbol;
  bool get isLoading => _isLoading;

  bool get isProductionMode {
    if (_companySettings == null) return false;
    final val = _companySettings!['ProductionMode'];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val == 1;
    final s = val.toString().toLowerCase().trim();
    return s == '1' || s == 'true';
  }

  Future<void> fetchSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getCompanySettings();
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          _companySettings = Map<String, dynamic>.from(data);
          if (data['CurrencySymbol'] != null) {
            String rawCurrency = data['CurrencySymbol'].toString();
            // Extract main currency (before '/')
            if (rawCurrency.contains('/')) {
              _currencySymbol = rawCurrency.split('/')[0].trim();
            } else {
              _currencySymbol = rawCurrency.trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching company settings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
