import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/product_discount.dart';

class PosProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Map<String, dynamic>> _invoiceItems = [];
  Map<int, List<ProductDiscount>> _activeDiscountsByProduct = {};
  List<Map<String, dynamic>> _offlineInvoices = [];
  double _extraDiscountAmount = 0.0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PosProvider(this._apiService) {
    _loadOfflineInvoices();
    fetchActiveDiscounts();
  }

  List<Map<String, dynamic>> get invoiceItems => _invoiceItems;
  Map<int, List<ProductDiscount>> get activeDiscountsByProduct => _activeDiscountsByProduct;
  List<Map<String, dynamic>> get offlineInvoices => _offlineInvoices;
  int get offlineInvoicesCount => _offlineInvoices.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  double get extraDiscountAmount => _extraDiscountAmount;

  void setExtraDiscount(double amount) {
    _extraDiscountAmount = amount < 0 ? 0.0 : amount;
    notifyListeners();
  }

  double get totalOriginalAmount {
    return _invoiceItems.fold(0.0, (sum, item) {
      final origP = (item['originalPrice'] ?? item['price'] ?? 0.0) as double;
      final qty = (item['quantity'] ?? 1.0) as double;
      return sum + (origP * qty);
    });
  }

  double get totalItemDiscountAmount {
    return _invoiceItems.fold(0.0, (sum, item) {
      return sum + ((item['discountAmount'] ?? 0.0) as double);
    });
  }

  double get totalDiscountAmount {
    return totalItemDiscountAmount + _extraDiscountAmount;
  }

  double get totalAmount {
    final double net = totalOriginalAmount - totalDiscountAmount;
    return net < 0 ? 0.0 : net;
  }

  Future<void> fetchActiveDiscounts() async {
    try {
      final res = await _apiService.getActiveDiscountsForPos();
      if (res.statusCode == 200 && res.data is List) {
        final List<dynamic> list = res.data;
        final Map<int, List<ProductDiscount>> grouped = {};
        for (var item in list) {
          final disc = ProductDiscount.fromJson(item);
          grouped.putIfAbsent(disc.productId, () => []).add(disc);
        }
        _activeDiscountsByProduct = grouped;
        notifyListeners();
      }
    } catch (e) {
      // Quietly ignore network failures for discounts sync
    }
  }

  void clearInvoice() {
    _invoiceItems.clear();
    _extraDiscountAmount = 0.0;
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

  Future<bool> searchAndAddProductByBarcode(String barcode, {String invoiceType = 'Sales'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getProductByBarcode(barcode);
      if (response.statusCode == 200) {
        final product = response.data;
        
        final bool isPurchase = (invoiceType == 'Purchase');
        final rawPrice = isPurchase
            ? (product['PurchasePrice'] ?? product['purchase_price'] ?? product['CostPrice'] ?? product['price'] ?? product['SalePrice'])
            : (product['SalePrice'] ?? product['price']);
        double priceValue = 0.0;
        if (rawPrice is num) {
          priceValue = rawPrice.toDouble();
        } else if (rawPrice is String) {
          priceValue = double.tryParse(rawPrice) ?? 0.0;
        }

        final existingIndex = _invoiceItems.indexWhere((item) => item['barcode'] == barcode);
        if (existingIndex != -1) {
          _invoiceItems[existingIndex]['quantity'] += 1.0;
          _recalculateItemDiscount(_invoiceItems[existingIndex]);
        } else {
          final item = {
            'ProductID': product['ProductID'] ?? product['product_id'] ?? 1,
            'barcode': product['Barcode'] ?? product['barcode'] ?? barcode,
            'name': product['ProductName'] ?? product['name'] ?? 'منتج غير معروف',
            'originalPrice': priceValue,
            'price': priceValue,
            'quantity': 1.0,
            'total': priceValue,
            'discountAmount': 0.0,
            'appliedDiscount': null,
            'UnitName': product['UnitName'] ?? product['unit_name'] ?? product['unit'] ?? '',
          };
          _recalculateItemDiscount(item);
          _invoiceItems.add(item);
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

  void _recalculateItemDiscount(Map<String, dynamic> item) {
    final double origP = ((item['originalPrice'] ?? item['price']) as num).toDouble();
    final double qty = ((item['quantity'] ?? 1.0) as num).toDouble();
    final ProductDiscount? disc = item['appliedDiscount'] as ProductDiscount?;

    if (disc != null) {
      if (qty >= disc.minQuantity) {
        final double discAmt = disc.calculateDiscountAmount(origP, qty);
        item['discountAmount'] = discAmt;
        if (disc.discountType == 1) {
          // Percentage %
          item['price'] = origP * (1.0 - (disc.discountValue / 100.0));
        } else if (disc.discountType == 2) {
          // Fixed Amount per unit
          item['price'] = (origP - disc.discountValue).clamp(0.0, double.infinity);
        } else if (disc.discountType == 3) {
          // Bundle Total Discount
          item['price'] = (origP - (disc.discountValue / qty)).clamp(0.0, double.infinity);
        }
      } else {
        // Threshold not met yet
        item['price'] = origP;
        item['discountAmount'] = 0.0;
      }
    } else {
      item['price'] = origP;
      item['discountAmount'] = 0.0;
    }
    item['total'] = (item['price'] as double) * qty;
  }

  void addProductToCart(Map<String, dynamic> product, {String invoiceType = 'Sales'}) {
    final int productId = product['ProductID'] ?? product['product_id'] ?? 1;
    final String barcode = product['Barcode'] ?? product['barcode'] ?? '';
    final String name = product['ProductName'] ?? product['name'] ?? 'منتج غير معروف';
    
    final bool isPurchase = (invoiceType == 'Purchase');
    final rawPrice = isPurchase
        ? (product['PurchasePrice'] ?? product['purchase_price'] ?? product['CostPrice'] ?? product['price'] ?? product['SalePrice'] ?? 0.0)
        : (product['SalePrice'] ?? product['price'] ?? 0.0);
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
      _recalculateItemDiscount(_invoiceItems[existingIndex]);
    } else {
      final item = {
        'ProductID': productId,
        'barcode': barcode,
        'name': name,
        'originalPrice': priceValue,
        'price': priceValue,
        'quantity': 1.0,
        'total': priceValue,
        'discountAmount': 0.0,
        'appliedDiscount': null,
        'UnitName': unitName,
      };
      _recalculateItemDiscount(item);
      _invoiceItems.add(item);
    }
    notifyListeners();
  }

  /// Toggles a single discount on a cart item (Exclusive Toggle)
  void toggleDiscountForItem(int index, ProductDiscount discount) {
    if (index < 0 || index >= _invoiceItems.length) return;

    final item = _invoiceItems[index];
    final ProductDiscount? currentDiscount = item['appliedDiscount'] as ProductDiscount?;

    if (currentDiscount != null && currentDiscount.discountId == discount.discountId) {
      // De-select active discount
      item['appliedDiscount'] = null;
    } else {
      // Apply new discount exclusively (overrides any existing discount!)
      item['appliedDiscount'] = discount;
    }

    _recalculateItemDiscount(item);
    notifyListeners();
  }

  void updateQuantity(int index, num newQuantity) {
    if (index >= 0 && index < _invoiceItems.length && newQuantity > 0) {
      _invoiceItems[index]['quantity'] = newQuantity.toDouble();
      _recalculateItemDiscount(_invoiceItems[index]);
      notifyListeners();
    } else if (newQuantity <= 0) {
      removeItem(index);
    }
  }

  void updatePrice(int index, double newPrice) {
    if (index >= 0 && index < _invoiceItems.length && newPrice >= 0) {
      _invoiceItems[index]['price'] = newPrice;
      _invoiceItems[index]['originalPrice'] = newPrice;
      _recalculateItemDiscount(_invoiceItems[index]);
      notifyListeners();
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
    List<Map<String, dynamic>>? paymentSplits,
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
    final activeShiftId = prefs.getInt('active_shift_id');

    int? resolvedPaymentAccountId = paymentAccountId;
    if (resolvedPaymentAccountId == null && isCash) {
      try {
        final String? cachedAccJson = prefs.getString('cached_accounts');
        if (cachedAccJson != null) {
          final List<dynamic> decoded = json.decode(cachedAccJson);
          if (decoded.isNotEmpty) {
            final cashAcc = decoded.firstWhere(
              (acc) {
                final name = (acc['AccountName']?.toString() ?? '').toLowerCase();
                final code = (acc['AccountCode']?.toString() ?? '');
                return name.contains('صندوق') ||
                    name.contains('كاش') ||
                    name.contains('cash') ||
                    name.contains('نقدا') ||
                    name.contains('نقداً') ||
                    code == '110101' ||
                    code.startsWith('1101');
              },
              orElse: () => decoded.first,
            );
            if (cashAcc != null) {
              resolvedPaymentAccountId = cashAcc['AccountID'];
            }
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

    double paid = isCash ? totalAmount : 0.0;
    double remainder = isCash ? 0.0 : totalAmount;

    if (paymentSplits != null && paymentSplits.isNotEmpty) {
      paid = paymentSplits.fold<double>(0.0, (sum, s) => sum + ((s['Amount'] as num?)?.toDouble() ?? 0.0));
      remainder = totalAmount > paid ? (totalAmount - paid) : 0.0;
    }

    final double grossTotal = totalOriginalAmount;
    final double discountVal = totalDiscountAmount;
    final double netTotal = totalAmount;

    final invoiceData = {
      'InvType': invoiceType == 'Sales' ? 'Sales' : 'Purchase',
      'InvDate': DateTime.now().toIso8601String(),
      'PartnerID': finalPartnerId,
      'WarehouseID': warehouseId,
      'TotalAmount': grossTotal,
      'Discount': discountVal,
      'NetAmount': netTotal,
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
      if (activeShiftId != null) 'ShiftID': activeShiftId,
      if (resolvedPaymentAccountId != null) 'PaymentAccountID': resolvedPaymentAccountId,
      if (paymentSplits != null && paymentSplits.isNotEmpty) 'PaymentSplits': paymentSplits,
    };

    try {
      final response = await _apiService.saveInvoice(invoiceData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successMessage = 'تم حفظ الفاتورة بنجاح!';
        final int newInvId = response.data['InvID'] ?? 0;
        _invoiceItems.clear();
        _extraDiscountAmount = 0.0;
        _isLoading = false;
        notifyListeners();
        return newInvId;
      } else {
        _offlineInvoices.add(invoiceData);
        await _saveOfflineInvoices();
        _successMessage = 'تم الحفظ محلياً (حدث خطأ في استجابة الخادم: ${response.statusCode})';
        _invoiceItems.clear();
        _extraDiscountAmount = 0.0;
        _isLoading = false;
        notifyListeners();
        return 0;
      }
    } catch (e) {
      _offlineInvoices.add(invoiceData);
      await _saveOfflineInvoices();
      _successMessage = 'تم الحفظ محلياً بنجاح (وضع العمل دون اتصال)';
      _invoiceItems.clear();
      _extraDiscountAmount = 0.0;
      _isLoading = false;
      notifyListeners();
      return 0;
    }
  }

  Future<Map<String, dynamic>?> quickAddUnrecognizedProduct(String barcode, double price, {bool isPurchase = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'Barcode': barcode,
        'ProductName': 'صنف عام - $barcode',
        'SalePrice': price,
        'PurchasePrice': isPurchase ? price : 0.0,
      };
      
      final response = await _apiService.quickAddProduct(payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final int newProductId = response.data['ProductID'] ?? 0;
        final productMap = {
          'ProductID': newProductId,
          'ProductName': 'صنف عام - $barcode',
          'Barcode': barcode,
          'SalePrice': price,
          'PurchasePrice': price,
          'price': price,
          'UnitName': 'حبه',
        };
        addProductToCart(productMap, invoiceType: isPurchase ? 'Purchase' : 'Sales');
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
