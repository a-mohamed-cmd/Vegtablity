import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  bool _isLoading = false;
  bool _isInitialized = false; // Tracks if auto-login check completed
  String? _token;
  int? _userId;
  String? _username;
  String? _roleName;
  bool _canRefundPaymentGateway = false;
  bool _canDeleteSalesInvoice = false;
  bool _canDeletePurchaseInvoice = false;
  String? _errorMessage;

  AuthProvider(this._apiService) {
    _apiService.onUnauthorized = () {
      logout();
    };
    _tryAutoLogin();
  }

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  int? get userId => _userId;
  String? get username => _username;
  String? get roleName => _roleName;
  bool get canRefundPaymentGateway => _canRefundPaymentGateway;
  bool get canDeleteSalesInvoice => _canDeleteSalesInvoice;
  bool get canDeletePurchaseInvoice => _canDeletePurchaseInvoice;
  bool canDeleteInvoice(String? invType) {
    final t = (invType ?? '').trim().toLowerCase();
    return t == 'purchase'
        ? _canDeletePurchaseInvoice
        : _canDeleteSalesInvoice;
  }
  String? get errorMessage => _errorMessage;

  bool get isAdmin {
    if (_username != null && _username!.toLowerCase().trim() == 'admin') {
      return true;
    }
    if (_roleName != null && _roleName!.toLowerCase().contains('admin')) {
      return true;
    }
    return false;
  }

  Future<void> _tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('token') && prefs.containsKey('username')) {
        final savedToken = prefs.getString('token');
        final savedUserId = prefs.getInt('user_id');
        final savedUsername = prefs.getString('username');
        final savedRoleName = prefs.getString('role_name') ?? 'admin';
        final savedCanRefund =
            prefs.getBool('can_refund_payment_gateway') ?? false;
        final savedCanDeleteSales =
            prefs.getBool('can_delete_sales_invoice') ?? false;
        final savedCanDeletePurchase =
            prefs.getBool('can_delete_purchase_invoice') ?? false;
        if (savedToken != null && savedToken.isNotEmpty) {
          _apiService.updateToken(savedToken);
          try {
            await _apiService.getActiveShift();
            // Token is valid
            _token = savedToken;
            _userId = savedUserId;
            _username = savedUsername;
            _roleName = savedRoleName;
            _canRefundPaymentGateway = savedCanRefund;
            _canDeleteSalesInvoice = savedCanDeleteSales;
            _canDeletePurchaseInvoice = savedCanDeletePurchase;
            await refreshCurrentUserPermissions();
          } catch (e) {
            if (_apiService.getToken() == savedToken) {
              _token = savedToken;
              _userId = savedUserId;
              _username = savedUsername;
              _roleName = savedRoleName;
              _canRefundPaymentGateway = savedCanRefund;
              _canDeleteSalesInvoice = savedCanDeleteSales;
              _canDeletePurchaseInvoice = savedCanDeletePurchase;
            }
          }
        }
      }
    } catch (e) {
      // Handle error quietly
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUserPermissions() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      final res = await _apiService.getCurrentUser();
      if (res.statusCode == 200 && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final parsedId = int.tryParse(data['user_id']?.toString() ?? '');
        if (parsedId != null) _userId = parsedId;
        if (data['role_name'] != null) {
          _roleName = data['role_name'].toString();
        }
        _canRefundPaymentGateway =
            data['can_refund_payment_gateway'] == true;
        _canDeleteSalesInvoice =
            data['can_delete_sales_invoice'] == true;
        _canDeletePurchaseInvoice =
            data['can_delete_purchase_invoice'] == true;

        final prefs = await SharedPreferences.getInstance();
        if (_userId != null) await prefs.setInt('user_id', _userId!);
        if (_roleName != null) await prefs.setString('role_name', _roleName!);
        await prefs.setBool(
            'can_refund_payment_gateway', _canRefundPaymentGateway);
        await prefs.setBool(
            'can_delete_sales_invoice', _canDeleteSalesInvoice);
        await prefs.setBool(
            'can_delete_purchase_invoice', _canDeletePurchaseInvoice);
        notifyListeners();
      }
    } catch (_) {
      // Silent fallback if backend doesn't support /auth/me or temporarily offline
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
        _userId = int.tryParse(data['user_id']?.toString() ?? '');
        _username = username;
        _roleName = data['role_name']?.toString() ?? (username.toLowerCase() == 'admin' ? 'admin' : 'user');
        _canRefundPaymentGateway = data['can_refund_payment_gateway'] == true;
        _canDeleteSalesInvoice = data['can_delete_sales_invoice'] == true;
        _canDeletePurchaseInvoice = data['can_delete_purchase_invoice'] == true;
        
        // Update token in apiService
        _apiService.updateToken(_token);

        // Persist token and user details
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        if (_userId != null) {
          await prefs.setInt('user_id', _userId!);
        }
        await prefs.setString('username', _username!);
        await prefs.setString('role_name', _roleName!);
        await prefs.setBool(
            'can_refund_payment_gateway', _canRefundPaymentGateway);
        await prefs.setBool(
            'can_delete_sales_invoice', _canDeleteSalesInvoice);
        await prefs.setBool(
            'can_delete_purchase_invoice', _canDeletePurchaseInvoice);

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
    _userId = null;
    _username = null;
    _roleName = null;
    _canRefundPaymentGateway = false;
    _canDeleteSalesInvoice = false;
    _canDeletePurchaseInvoice = false;
    _apiService.updateToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role_name');
    await prefs.remove('can_refund_payment_gateway');
    await prefs.remove('can_delete_sales_invoice');
    await prefs.remove('can_delete_purchase_invoice');
    await prefs.remove('active_shift_id');

    notifyListeners();
  }
}
