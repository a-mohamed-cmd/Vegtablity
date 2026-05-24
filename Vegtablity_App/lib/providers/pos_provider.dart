import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PosProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Map<String, dynamic>> _invoiceItems = [];
  List<Map<String, dynamic>> _offlineInvoices = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PosProvider(this._apiService) {
    _loadOfflineInvoices();
  }

  List<Map<String, dynamic>> get invoiceItems => _invoiceItems;
  List<Map<String, dynamic>> get offlineInvoices => _offlineInvoices;
  int get offlineInvoicesCount => _offlineInvoices.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  double get totalAmount {
    return _invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0));
  }

  void clearInvoice() {
    _invoiceItems.clear();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _loadOfflineInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('unsynced_invoices');
      if (encoded != null) {
        final List<dynamic> decoded = json.decode(encoded);
        _offlineInvoices = List<Map<String, dynamic>>.from(decoded);
        notifyListeners();
      }
    } catch (e) {
      // Quietly ignore
    }
  }

  Future<void> _saveOfflineInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_offlineInvoices);
      await prefs.setString('unsynced_invoices', encoded);
    } catch (e) {
      // Quietly ignore
    }
  }

  Future<bool> searchAndAddProductByBarcode(String barcode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getProductByBarcode(barcode);
      if (response.statusCode == 200) {
        final product = response.data;
        
        final rawPrice = product['price'];
        double priceValue = 0.0;
        if (rawPrice is num) {
          priceValue = rawPrice.toDouble();
        } else if (rawPrice is String) {
          priceValue = double.tryParse(rawPrice) ?? 0.0;
        }

        final existingIndex = _invoiceItems.indexWhere((item) => item['barcode'] == barcode);
        if (existingIndex != -1) {
          _invoiceItems[existingIndex]['quantity'] += 1;
          _invoiceItems[existingIndex]['total'] = _invoiceItems[existingIndex]['price'] * _invoiceItems[existingIndex]['quantity'];
        } else {
          _invoiceItems.add({
            'barcode': barcode,
            'name': product['name'] ?? 'منتج غير معروف',
            'price': priceValue,
            'quantity': 1,
            'total': priceValue,
          });
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'المنتج غير موجود أو حدثت مشكلة في الاسترجاع';
      }
    } catch (e) {
      // Offline/Fallback: Add mockup product automatically
      _addMockupProduct(barcode);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void _addMockupProduct(String barcode) {
    final existingIndex = _invoiceItems.indexWhere((item) => item['barcode'] == barcode);
    if (existingIndex != -1) {
      _invoiceItems[existingIndex]['quantity'] += 1;
      _invoiceItems[existingIndex]['total'] = _invoiceItems[existingIndex]['price'] * _invoiceItems[existingIndex]['quantity'];
    } else {
      _invoiceItems.add({
        'barcode': barcode,
        'name': 'صنف تجريبي ($barcode)',
        'price': 15.0,
        'quantity': 1,
        'total': 15.0,
      });
    }
  }

  Future<int?> saveInvoice(String invoiceType) async {
    if (_invoiceItems.isEmpty) {
      _errorMessage = 'السلة فارغة، يرجى إضافة منتجات أولاً';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final invoiceData = {
      'type': invoiceType,
      'items': List<Map<String, dynamic>>.from(_invoiceItems),
      'total_amount': totalAmount,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _apiService.saveInvoice(invoiceData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successMessage = 'تم حفظ الفاتورة بنجاح!';
        final int newInvId = response.data['InvID'] ?? 0;
        _invoiceItems.clear();
        _isLoading = false;
        notifyListeners();
        return newInvId;
      } else {
        // Even if the server returns non-200/201 status, we fall back to offline storage
        // so the cashier can print the receipt and transaction is saved locally.
        _offlineInvoices.add(invoiceData);
        await _saveOfflineInvoices();
        _successMessage = 'تم الحفظ محلياً (حدث خطأ في استجابة الخادم: ${response.statusCode})';
        _invoiceItems.clear();
        _isLoading = false;
        notifyListeners();
        return 0;
      }
    } catch (e) {
      // Network or API offline error: fallback to local SharedPreferences storage
      _offlineInvoices.add(invoiceData);
      await _saveOfflineInvoices();
      _successMessage = 'تم الحفظ محلياً بنجاح (وضع العمل دون اتصال)';
      _invoiceItems.clear();
      _isLoading = false;
      notifyListeners();
      return 0; // Return 0 as it was safely cached locally for the user
    }
  }

  Future<bool> syncOfflineInvoices() async {
    if (_offlineInvoices.isEmpty) return true;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final List<Map<String, dynamic>> successfullySynced = [];

    for (final invoice in _offlineInvoices) {
      try {
        final response = await _apiService.saveInvoice(invoice);
        if (response.statusCode == 200 || response.statusCode == 201) {
          successfullySynced.add(invoice);
        }
      } catch (e) {
        // If one fails (still offline), stop syncing and keep remaining
        break;
      }
    }

    if (successfullySynced.isNotEmpty) {
      _offlineInvoices.removeWhere((inv) => successfullySynced.contains(inv));
      await _saveOfflineInvoices();
      _successMessage = 'تمت مزامنة ${successfullySynced.length} فاتورة بنجاح مع الخادم!';
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'فشلت المزامنة. يرجى التحقق من جودة الاتصال بالإنترنت';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
