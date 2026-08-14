import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BarcodePrintViewModel extends ChangeNotifier {
  final ApiService _apiService;

  final TextEditingController searchController = TextEditingController();

  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  List<String> _categories = [];
  String _selectedCategory = 'ALL';

  bool _isLoading = false;
  String? _errorMessage;

  BarcodePrintViewModel(this._apiService) {
    searchController.addListener(_filterProducts);
  }

  List<dynamic> get filteredProducts => _filteredProducts;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _filterProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Execute API endpoint which calls [Inventory].[sp_Product_GetForSales]
      final response = await _apiService.getProductsForSales();
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> productsList = List<dynamic>.from(response.data as List);

        final Set<String> catSet = {};
        for (var p in productsList) {
          final catName = p['CatName']?.toString().trim() ?? p['cat_name']?.toString().trim();
          if (catName != null && catName.isNotEmpty) {
            catSet.add(catName);
          }
        }

        _allProducts = productsList;
        _categories = catSet.toList()..sort();
        _isLoading = false;
        _filterProducts();
      } else {
        _isLoading = false;
        _errorMessage = 'حدث خطأ عند جلب المنتجات من السيرفر (${response.statusCode})';
        notifyListeners();
      }
    } on DioException catch (dioErr) {
      _isLoading = false;
      if (dioErr.response?.statusCode == 401) {
        _errorMessage = 'انتهت جلسة الدخول أو أن المعرف غير مصرح (401 Unauthorized). يرجى إعادة تسجيل الدخول.';
      } else if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError) {
        _errorMessage = 'تعذر الاتصال بخادم السيرفر. يرجى التأكد من تشغيل API وجودة الاتصال.';
      } else {
        _errorMessage = 'خطأ في الاتصال بالخادم (${dioErr.message})';
      }
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'خطأ غير متوقع: $e';
      notifyListeners();
    }
  }

  void _filterProducts() {
    final query = searchController.text.trim().toLowerCase();
    _filteredProducts = _allProducts.where((product) {
      final name = (product['ProductName'] ?? product['product_name'] ?? product['name'] ?? '').toString().toLowerCase();
      final nameEn = (product['ProductNameEn'] ?? product['product_name_en'] ?? '').toString().toLowerCase();
      final barcode = (product['Barcode'] ?? product['barcode'] ?? '').toString().toLowerCase();
      final catName = (product['CatName'] ?? product['cat_name'] ?? '').toString();

      final matchesSearch = query.isEmpty || name.contains(query) || nameEn.contains(query) || barcode.contains(query);
      final matchesCategory = _selectedCategory == 'ALL' || catName == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterProducts);
    searchController.dispose();
    super.dispose();
  }
}
