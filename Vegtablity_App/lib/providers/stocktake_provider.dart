import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/inventory_model.dart';

class StockTakeProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<StockTakeItem> _items = [];
  List<Map<String, dynamic>> _warehouses = [];
  int _selectedWarehouseId = 1;
  String _selectedWarehouseName = 'المستودع الرئيسي';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  StockTakeProvider(this._apiService) {
    loadWarehouses();
  }

  List<StockTakeItem> get items => _items;
  ApiService get apiService => _apiService;
  List<Map<String, dynamic>> get warehouses => _warehouses;
  int get selectedWarehouseId => _selectedWarehouseId;
  String get selectedWarehouseName => _selectedWarehouseName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  double get totalDifferenceValue => _items.fold(0.0, (sum, item) => sum + item.diffValue);

  void selectWarehouse(int id, String name) {
    _selectedWarehouseId = id;
    _selectedWarehouseName = name;
    // Clear items when warehouse changes to prevent inconsistent stock/cost mappings
    _items.clear();
    notifyListeners();
  }

  Future<void> loadWarehouses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? cachedWhId = prefs.getInt('selected_warehouse_id');
      final String? cachedWhName = prefs.getString('selected_warehouse_name');

      final response = await _apiService.getWarehouses();
      if (response.statusCode == 200) {
        _warehouses = List<Map<String, dynamic>>.from(response.data);
        if (_warehouses.isNotEmpty) {
          if (cachedWhId != null && _warehouses.any((w) => w['WarehouseID'] == cachedWhId)) {
            _selectedWarehouseId = cachedWhId;
            _selectedWarehouseName = cachedWhName ?? 'المستودع الرئيسي';
          } else {
            final defaultWh = _warehouses.first;
            _selectedWarehouseId = defaultWh['WarehouseID'] ?? 1;
            _selectedWarehouseName = defaultWh['WarehouseName'] ?? 'المستودع الرئيسي';
          }
        }
        notifyListeners();
      }
    } catch (e) {
      // Fallback local defaults
      _warehouses = [
        {'WarehouseID': 1, 'WarehouseName': 'المستودع الرئيسي'},
        {'WarehouseID': 2, 'WarehouseName': 'مستودع الخضار'},
      ];
      notifyListeners();
    }
  }

  Future<bool> searchAndAddProductByBarcode(String barcode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prodRes = await _apiService.getProductByBarcode(barcode);
      if (prodRes.statusCode == 200) {
        final product = prodRes.data;
        final productId = product['ProductID'] as int;
        
        // Fetch current system stock and cost for the selected warehouse
        double systemQty = 0.0;
        double costPrice = (product['PurchasePrice'] as num?)?.toDouble() ?? 0.0;
        
        try {
          final stockRes = await _apiService.getProductStockCost(productId, _selectedWarehouseId);
          if (stockRes.statusCode == 200) {
            systemQty = (stockRes.data['StockQuantity'] as num?)?.toDouble() ?? 0.0;
            costPrice = (stockRes.data['CostPrice'] as num?)?.toDouble() ?? costPrice;
          }
        } catch (_) {}

        addProductDirectly(product, systemQty, costPrice);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Offline fallback
      _addMockupProduct(barcode);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void addProductDirectly(Map<String, dynamic> product, double systemQty, double costPrice) {
    final int productId = product['ProductID'] as int;
    final existingIndex = _items.indexWhere((item) => item.productID == productId);
    
    if (existingIndex != -1) {
      // Scanning the barcode again increments the actual count by 1
      _items[existingIndex].actualQty += 1;
    } else {
      _items.add(StockTakeItem(
        productID: productId,
        productName: product['ProductName'] ?? 'صنف غير معروف',
        barcode: product['Barcode'] ?? '',
        unitName: product['UnitName'] ?? 'حبه',
        systemQty: systemQty,
        actualQty: 1.0, // Default first scan
        costPrice: costPrice,
      ));
    }
  }

  void _addMockupProduct(String barcode) {
    final existingIndex = _items.indexWhere((item) => item.barcode == barcode);
    if (existingIndex != -1) {
      _items[existingIndex].actualQty += 1;
    } else {
      _items.add(StockTakeItem(
        productID: DateTime.now().millisecondsSinceEpoch % 100000,
        productName: 'صنف تجريبي ($barcode)',
        barcode: barcode,
        unitName: 'حبه',
        systemQty: 10.0, // Mock system qty
        actualQty: 1.0,
        costPrice: 5.0,
      ));
    }
  }

  void updateActualQuantity(int productID, double qty) {
    final index = _items.indexWhere((item) => item.productID == productID);
    if (index != -1) {
      if (qty < 0) {
        _items.removeAt(index);
      } else {
        _items[index].actualQty = qty;
      }
      notifyListeners();
    }
  }

  void removeItem(int productID) {
    _items.removeWhere((item) => item.productID == productID);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<int?> submitStockTake(String notes) async {
    if (_items.isEmpty) {
      _errorMessage = 'سلة الجرد فارغة';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final payload = {
      'StockTakeID': 0,
      'StockTakeDate': DateTime.now().toIso8601String(),
      'WarehouseID': _selectedWarehouseId,
      'TotalDifferenceValue': totalDifferenceValue,
      'Notes': notes,
      'Details': _items.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await _apiService.saveStockTake(payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successMessage = 'تم حفظ الجرد كمسودة بنجاح!';
        final int id = response.data['StockTakeID'] ?? 0;
        _items.clear();
        _isLoading = false;
        notifyListeners();
        return id;
      } else {
        await _saveOffline(payload);
        _successMessage = 'تم الحفظ محلياً مؤقتاً';
        _items.clear();
        _isLoading = false;
        notifyListeners();
        return 0;
      }
    } catch (e) {
      await _saveOffline(payload);
      _successMessage = 'تم الحفظ محلياً بنجاح (وضع عدم الاتصال)';
      _items.clear();
      _isLoading = false;
      notifyListeners();
      return 0;
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('unsynced_stocktakes') ?? [];
      list.add(json.encode(data));
      await prefs.setStringList('unsynced_stocktakes', list);
    } catch (_) {}
  }
}
