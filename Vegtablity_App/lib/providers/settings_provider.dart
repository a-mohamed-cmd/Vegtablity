import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService;
  
  Map<String, dynamic>? _companySettings;
  String _currencySymbol = "د.ك";
  bool _isLoading = false;
  bool _cachedEnableDailyOrders = false;
  bool _cachedUseCustomInvoiceDesign = false;
  bool _cachedIsProductionMode = false;
  String? _cachedDeliverySystemMode;

  SettingsProvider(this._apiService) {
    _loadCachedSettings();
    fetchSettings();
  }

  Map<String, dynamic>? get companySettings => _companySettings;
  String get currencySymbol => _currencySymbol;
  bool get isLoading => _isLoading;

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedEnableDailyOrders = prefs.getBool('cached_enable_daily_orders') ?? false;
      _cachedUseCustomInvoiceDesign = prefs.getBool('cached_use_custom_invoice_design') ?? false;
      _cachedIsProductionMode = prefs.getBool('cached_is_production_mode') ?? false;
      _cachedDeliverySystemMode = prefs.getString('cached_delivery_system_mode');
      notifyListeners();
    } catch (_) {}
  }

  bool get isProductionMode {
    if (_companySettings != null) {
      for (final entry in _companySettings!.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (key == 'productionmode') {
          final val = entry.value;
          if (val != null) {
            if (val is bool) return val;
            if (val is num) return val == 1;
            final s = val.toString().toLowerCase().trim();
            return s == '1' || s == 'true';
          }
        }
      }
    }
    return _cachedIsProductionMode;
  }

  bool get useCustomInvoiceDesign {
    if (_companySettings != null) {
      for (final entry in _companySettings!.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (key == 'usecustominvoicedesign') {
          final val = entry.value;
          if (val != null) {
            if (val is bool) return val;
            if (val is num) return val == 1;
            final s = val.toString().toLowerCase().trim();
            return s == '1' || s == 'true';
          }
        }
      }
    }
    return _cachedUseCustomInvoiceDesign;
  }

  bool get enableDailyOrders {
    if (_companySettings != null) {
      for (final entry in _companySettings!.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (key == 'enabledailyorders' || key == 'enabledeliveryorders') {
          final val = entry.value;
          if (val != null) {
            if (val is bool) return val;
            if (val is num) return val == 1;
            final s = val.toString().toLowerCase().trim();
            return s == '1' || s == 'true';
          }
        }
      }
    }
    return _cachedEnableDailyOrders;
  }

  String? get deliverySystemMode {
    if (_companySettings != null) {
      for (final entry in _companySettings!.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        if (key == 'deliverysystemmode' || key == 'deliveryschedulemode') {
          final val = entry.value;
          if (val != null && val.toString().trim().isNotEmpty) {
            return val.toString().trim();
          }
        }
      }
    }
    return _cachedDeliverySystemMode;
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
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('cached_enable_daily_orders', enableDailyOrders);
          await prefs.setBool('cached_use_custom_invoice_design', useCustomInvoiceDesign);
          await prefs.setBool('cached_is_production_mode', isProductionMode);
          if (deliverySystemMode != null) {
            await prefs.setString('cached_delivery_system_mode', deliverySystemMode!);
          }

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
