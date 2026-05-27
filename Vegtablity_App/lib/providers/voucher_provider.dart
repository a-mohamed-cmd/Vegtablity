import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class VoucherProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Map<String, dynamic>> _offlineVouchers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Cached data
  List<Map<String, dynamic>> _cachedCustomers = [];
  List<Map<String, dynamic>> _cachedVendors = [];
  List<Map<String, dynamic>> _cachedAccounts = [];

  VoucherProvider(this._apiService) {
    _loadOfflineVouchers();
    _loadCachedData();
  }

  List<Map<String, dynamic>> get offlineVouchers => _offlineVouchers;
  int get offlineVouchersCount => _offlineVouchers.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  List<Map<String, dynamic>> get cachedCustomers => _cachedCustomers;
  List<Map<String, dynamic>> get cachedVendors => _cachedVendors;
  List<Map<String, dynamic>> get cachedAccounts => _cachedAccounts;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _loadOfflineVouchers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('unsynced_vouchers');
      if (encoded != null) {
        final List<dynamic> decoded = json.decode(encoded);
        _offlineVouchers = List<Map<String, dynamic>>.from(decoded);
        notifyListeners();
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _saveOfflineVouchers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_offlineVouchers);
      await prefs.setString('unsynced_vouchers', encoded);
    } catch (e) {
      // Ignore
    }
  }

  // أداة تنظيف السندات المعلقة محلياً في حالة وجود أخطاء لا يمكن إصلاحها
  Future<void> clearOfflineVouchers() async {
    _offlineVouchers.clear();
    await _saveOfflineVouchers();
    notifyListeners();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? cust = prefs.getString('cached_customers');
      if (cust != null) _cachedCustomers = List<Map<String, dynamic>>.from(json.decode(cust));

      final String? vend = prefs.getString('cached_vendors');
      if (vend != null) _cachedVendors = List<Map<String, dynamic>>.from(json.decode(vend));

      final String? acc = prefs.getString('cached_accounts');
      if (acc != null) _cachedAccounts = List<Map<String, dynamic>>.from(json.decode(acc));
      
      notifyListeners();
    } catch (e) {
      // Ignore
    }
  }

  // Should be called periodically or when opening screens
  Future<void> refreshCache() async {
    try {
      final resCust = await _apiService.getPartners(type: 'Customer');
      if (resCust.statusCode == 200) _cachedCustomers = List<Map<String, dynamic>>.from(resCust.data);

      final resVend = await _apiService.getPartners(type: 'Vendor');
      if (resVend.statusCode == 200) _cachedVendors = List<Map<String, dynamic>>.from(resVend.data);

      final resAcc = await _apiService.getVoucherAccounts();
      if (resAcc.statusCode == 200) _cachedAccounts = List<Map<String, dynamic>>.from(resAcc.data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customers', json.encode(_cachedCustomers));
      await prefs.setString('cached_vendors', json.encode(_cachedVendors));
      await prefs.setString('cached_accounts', json.encode(_cachedAccounts));
      
      notifyListeners();
    } catch (e) {
      // Failed to refresh cache, will continue using old cache
    }
  }

  /// يحفظ السند. إما يتم إرساله للـ API أو يحفظ محلياً للأوفلاين
  Future<Map<String, dynamic>?> saveVoucher({
    required int partnerId,
    required String voucherType, // 'Receipt' | 'Payment'
    required double totalAmount,
    required int accountId,
    required int shiftId,
    required List<Map<String, dynamic>> allocations,
    String description = '',
    String partnerName = '',
    String accountName = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final voucherData = {
      'PartnerID': partnerId,
      'VoucherType': voucherType,
      'TotalAmount': totalAmount,
      'AccountID': accountId,
      'ShiftID': shiftId,
      'Description': description,
      'Allocations': allocations,
      // For local receipt printing:
      'PartnerName': partnerName,
      'AccountName': accountName,
      'VoucherDate': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _apiService.bulkPay(
        partnerId: partnerId,
        voucherType: voucherType,
        totalAmount: totalAmount,
        accountId: accountId,
        shiftId: shiftId,
        allocations: allocations,
        description: description,
      );

      if (response.statusCode == 200) {
        _successMessage = 'تم حفظ السند بنجاح!';
        _isLoading = false;
        notifyListeners();
        return response.data as Map<String, dynamic>;
      } else {
        _offlineVouchers.add(voucherData);
        await _saveOfflineVouchers();
        _successMessage = 'تم الحفظ محلياً (رد غير متوقع من الخادم)';
        _isLoading = false;
        notifyListeners();
        return voucherData;
      }
    } catch (e) {
      // Offline mode
      _offlineVouchers.add(voucherData);
      await _saveOfflineVouchers();
      _successMessage = 'تم الحفظ محلياً (تعذر الاتصال بالخادم)';
      _isLoading = false;
      notifyListeners();
      return voucherData;
    }
  }

  Future<bool> syncOfflineVouchers() async {
    if (_offlineVouchers.isEmpty) return true;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final List<Map<String, dynamic>> successfullySynced = [];

    for (final voucher in _offlineVouchers) {
      try {
        final response = await _apiService.bulkPay(
          partnerId: voucher['PartnerID'],
          voucherType: voucher['VoucherType'],
          totalAmount: voucher['TotalAmount'],
          accountId: voucher['AccountID'],
          shiftId: voucher['ShiftID'],
          allocations: List<Map<String, dynamic>>.from(voucher['Allocations']),
          description: voucher['Description'] ?? '',
        );

        if (response.statusCode == 200) {
          successfullySynced.add(voucher);
        }
      } on DioException catch (e) {
        print('DioException in syncOfflineVouchers: ${e.response?.data}');
        break;
      } catch (e) {
        print('Error in syncOfflineVouchers: $e');
        // Stop syncing on first error
        break;
      }
    }

    if (successfullySynced.isNotEmpty) {
      _offlineVouchers.removeWhere((v) => successfullySynced.contains(v));
      await _saveOfflineVouchers();
      _successMessage = 'تمت مزامنة ${successfullySynced.length} سند بنجاح!';
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'فشلت مزامنة السندات. تأكد من الاتصال بالإنترنت.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
