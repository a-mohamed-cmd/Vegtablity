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
        
        final rawPrice = product['SalePrice'] ?? product['price'];
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
            'ProductID': product['ProductID'] ?? product['product_id'] ?? 1,
            'barcode': product['Barcode'] ?? product['barcode'] ?? barcode,
            'name': product['ProductName'] ?? product['name'] ?? 'منتج غير معروف',
            'price': priceValue,
            'quantity': 1,
            'total': priceValue,
            'UnitName': product['UnitName'] ?? product['unit_name'] ?? product['unit'] ?? '',
          });
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'المنتج غير موجود أو حدثت مشكلة في الاسترجاع';
      }
    } catch (e) {
      _errorMessage = 'فشل الاتصال بالخادم أو الصنف غير متوفر';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void addProductToCart(Map<String, dynamic> product) {
    final int productId = product['ProductID'] ?? product['product_id'] ?? 1;
    final String barcode = product['Barcode'] ?? product['barcode'] ?? '';
    final String name = product['ProductName'] ?? product['name'] ?? 'منتج غير معروف';
    
    final rawPrice = product['SalePrice'] ?? product['price'] ?? 0.0;
    double priceValue = 0.0;
    if (rawPrice is num) {
      priceValue = rawPrice.toDouble();
    } else if (rawPrice is String) {
      priceValue = double.tryParse(rawPrice) ?? 0.0;
    }

    final String unitName = product['UnitName'] ?? product['unit_name'] ?? product['unit'] ?? '';

    final existingIndex = _invoiceItems.indexWhere((item) => item['ProductID'] == productId);
    if (existingIndex != -1) {
      _invoiceItems[existingIndex]['quantity'] += 1.0;
      _invoiceItems[existingIndex]['total'] = _invoiceItems[existingIndex]['price'] * _invoiceItems[existingIndex]['quantity'];
    } else {
      _invoiceItems.add({
        'ProductID': productId,
        'barcode': barcode,
        'name': name,
        'price': priceValue,
        'quantity': 1.0,
        'total': priceValue,
        'UnitName': unitName,
      });
    }
    notifyListeners();
  }

  void updateQuantity(int index, num newQuantity) {
    if (index >= 0 && index < _invoiceItems.length && newQuantity > 0) {
      _invoiceItems[index]['quantity'] = newQuantity;
      _invoiceItems[index]['total'] = _invoiceItems[index]['price'] * newQuantity;
      notifyListeners();
    } else if (newQuantity <= 0) {
      removeItem(index);
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _invoiceItems.length) {
      _invoiceItems.removeAt(index);
      notifyListeners();
    }
  }


  Future<int?> saveInvoice(
    String invoiceType, {
    int? paymentAccountId,
    int? partnerId,
    bool isCash = true,
    String? tempCustomerName,
    String? tempPhone,
    String? tempAddress,
    String? tempDeliveryDate,
    String? tempDeliveryTime,
    String? tempNotes,
  }) async {
    if (_invoiceItems.isEmpty) {
      _errorMessage = 'السلة فارغة، يرجى إضافة منتجات أولاً';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final warehouseId = prefs.getInt('selected_warehouse_id') ?? 1;
    final finalPartnerId = partnerId ?? prefs.getInt('general_partner_id') ?? 1;

    int? resolvedPaymentAccountId = paymentAccountId;
    if (resolvedPaymentAccountId == null && isCash) {
      try {
        final String? cachedAccJson = prefs.getString('cached_accounts');
        if (cachedAccJson != null) {
          final List<dynamic> decoded = json.decode(cachedAccJson);
          final cashAcc = decoded.firstWhere(
            (acc) => (acc['AccountName']?.toString() ?? '').contains('صندوق') || (acc['AccountName']?.toString() ?? '').contains('كاش'),
            orElse: () => null,
          );
          if (cashAcc != null) {
            resolvedPaymentAccountId = cashAcc['AccountID'];
          }
        }
      } catch (_) {}
    }

    final details = _invoiceItems.map((item) {
      final double qty = (item['quantity'] as num).toDouble();
      final double price = (item['price'] as num).toDouble();
      return {
        'ProductID': item['ProductID'] ?? 1,
        'UnitPrice': price,
        'Quantity': qty,
        'TotalPrice': price * qty,
        'CostPrice': price,
      };
    }).toList();

    final double paid = isCash ? totalAmount : 0.0;
    final double remainder = isCash ? 0.0 : totalAmount;

    final invoiceData = {
      'InvType': invoiceType == 'Sales' ? 'Sales' : 'Purchase',
      'InvDate': DateTime.now().toIso8601String(),
      'PartnerID': finalPartnerId,
      'WarehouseID': warehouseId,
      'TotalAmount': totalAmount,
      'Discount': 0.0,
      'NetAmount': totalAmount,
      'PaidAmount': paid,
      'Remainder': remainder,
      'Notes': tempNotes ?? (invoiceType == 'Sales' ? 'مبيعات نقطة البيع المحمولة' : 'مشتريات نقطة البيع المحمولة'),
      'IsPosted': false,
      'TempCustomerName': tempCustomerName,
      'TempPhone': tempPhone,
      'TempAddress': tempAddress,
      'TempDeliveryDate': tempDeliveryDate,
      'TempDeliveryTime': tempDeliveryTime,
      'Details': details,
      if (isCash && resolvedPaymentAccountId != null) 'PaymentAccountID': resolvedPaymentAccountId,
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
        _offlineInvoices.add(invoiceData);
        await _saveOfflineInvoices();
        _successMessage = 'تم الحفظ محلياً (حدث خطأ في استجابة الخادم: ${response.statusCode})';
        _invoiceItems.clear();
        _isLoading = false;
        notifyListeners();
        return 0;
      }
    } catch (e) {
      _offlineInvoices.add(invoiceData);
      await _saveOfflineInvoices();
      _successMessage = 'تم الحفظ محلياً بنجاح (وضع العمل دون اتصال)';
      _invoiceItems.clear();
      _isLoading = false;
      notifyListeners();
      return 0;
    }
  }

  Future<Map<String, dynamic>?> quickAddUnrecognizedProduct(String barcode, double salePrice) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'Barcode': barcode,
        'ProductName': 'صنف عام - $barcode',
        'SalePrice': salePrice,
        'PurchasePrice': 0.0,
      };
      
      final response = await _apiService.quickAddProduct(payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final int newProductId = response.data['ProductID'] ?? 0;
        final productMap = {
          'ProductID': newProductId,
          'ProductName': 'صنف عام - $barcode',
          'Barcode': barcode,
          'SalePrice': salePrice,
          'UnitName': 'حبه',
        };
        addProductToCart(productMap);
        _isLoading = false;
        notifyListeners();
        return productMap;
      } else {
        _errorMessage = 'فشل تسجيل الصنف في خادم البيانات';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ بالاتصال بالسيرفر أثناء تسجيل الصنف';
    }

    _isLoading = false;
    notifyListeners();
    return null;
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
