import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService;
  
  String _currencySymbol = "د.ك";
  bool _isLoading = false;

  SettingsProvider(this._apiService);

  String get currencySymbol => _currencySymbol;
  bool get isLoading => _isLoading;

  Future<void> fetchSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getCompanySettings();
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['CurrencySymbol'] != null) {
          String rawCurrency = data['CurrencySymbol'].toString();
          // Extract main currency (before '/')
          if (rawCurrency.contains('/')) {
            _currencySymbol = rawCurrency.split('/')[0].trim();
          } else {
            _currencySymbol = rawCurrency.trim();
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
