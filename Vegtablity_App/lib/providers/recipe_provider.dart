import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe_model.dart';

class RecipeProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<RecipeHeader> _recipes = [];
  List<dynamic> _ingredientProducts = [];
  List<dynamic> _targetProducts = [];
  RecipeHeader? _currentRecipe;
  bool _isLoading = false;
  String? _errorMessage;

  RecipeProvider(this._apiService);

  List<RecipeHeader> get recipes => _recipes;
  List<dynamic> get ingredientProducts => _ingredientProducts;
  List<dynamic> get targetProducts => _targetProducts;
  RecipeHeader? get currentRecipe => _currentRecipe;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAllRecipes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getAllRecipes();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _recipes = data.map((json) => RecipeHeader.fromJson(json)).toList();
      }
    } catch (e) {
      _errorMessage = 'خطأ في جلب الوصفات: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecipeByProduct(int productID, {int? warehouseId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getRecipeByProduct(productID, warehouseId: warehouseId);
      if (response.statusCode == 200) {
        _currentRecipe = RecipeHeader.fromJson(response.data);
      }
    } catch (e) {
      _currentRecipe = null;
      _errorMessage = 'لا توجد وصفة لهذا الصنف';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecipeIngredients({int? warehouseId}) async {
    try {
      final response = await _apiService.getProductsForRecipeIngredients(warehouseId: warehouseId);
      if (response.statusCode == 200) {
        _ingredientProducts = response.data as List<dynamic>;
        notifyListeners();
      }
    } catch (e) {
      _ingredientProducts = [];
    }
  }

  Future<void> loadTargetProducts({int? warehouseId, bool includeAll = false}) async {
    try {
      final response = await _apiService.getProductsForRecipeTarget(
        warehouseId: warehouseId,
        includeAll: includeAll,
      );
      if (response.statusCode == 200) {
        _targetProducts = response.data as List<dynamic>;
        notifyListeners();
      }
    } catch (e) {
      _targetProducts = [];
    }
  }

  Future<bool> saveRecipe(int productID, String notes, List<Map<String, dynamic>> details, {int? warehouseId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // تلقائياً: تصفية وحذف الصفوف غير المكتملة قبل الحفظ
    final cleanDetails = details.where((item) {
      final int ingredientId = (item['IngredientProductID'] as num?)?.toInt() ?? 0;
      final double qty = (item['Qty'] as num?)?.toDouble() ?? 0.0;
      return ingredientId > 0 && qty > 0;
    }).toList();

    if (cleanDetails.isEmpty) {
      _errorMessage = 'يجب إدخال مادة خام واحدة على الأقل في تفاصيل الوصفة';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final response = await _apiService.saveRecipe({
        'ProductID': productID,
        'Notes': notes,
        'Details': cleanDetails,
        if (warehouseId != null) 'WarehouseID': warehouseId,
      });

      if (response.statusCode == 200) {
        await fetchAllRecipes();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'فشل حفظ الوصفة: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRecipe(int recipeID) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.deleteRecipe(recipeID);
      if (response.statusCode == 200) {
        await fetchAllRecipes();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'فشل حذف الوصفة: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
