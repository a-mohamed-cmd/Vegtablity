import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AccountProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Map<String, dynamic>> _revenueAccounts = [];
  List<Map<String, dynamic>> _expenseAccounts = [];
  
  bool _isLoadingRevenues = false;
  bool _isLoadingExpenses = false;
  String? _errorMessage;

  /// معرّف العميل الثابت 'سند مباشر' - يُجلب مرة واحدة فقط ويُخزّن هنا
  int? _generalPartnerId;

  AccountProvider(this._apiService);

  List<Map<String, dynamic>> get revenueAccounts => _revenueAccounts;
  List<Map<String, dynamic>> get expenseAccounts => _expenseAccounts;
  bool get isLoadingRevenues => _isLoadingRevenues;
  bool get isLoadingExpenses => _isLoadingExpenses;
  String? get errorMessage => _errorMessage;
  int? get generalPartnerId => _generalPartnerId;

  Future<void> fetchRevenueAccounts() async {
    _isLoadingRevenues = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getRevenueAccounts();
      if (response.statusCode == 200) {
        _revenueAccounts = List<Map<String, dynamic>>.from(response.data);
      } else {
        _errorMessage = "خطأ في جلب حسابات الإيرادات";
      }
    } catch (e) {
      _errorMessage = "تعذر الاتصال بالخادم: $e";
    }

    _isLoadingRevenues = false;
    notifyListeners();
  }

  Future<void> fetchExpenseAccounts() async {
    _isLoadingExpenses = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getExpenseAccounts();
      if (response.statusCode == 200) {
        _expenseAccounts = List<Map<String, dynamic>>.from(response.data);
      } else {
        _errorMessage = "خطأ في جلب حسابات المصروفات";
      }
    } catch (e) {
      _errorMessage = "تعذر الاتصال بالخادم: $e";
    }

    _isLoadingExpenses = false;
    notifyListeners();
  }

  /// جلب معرّف العميل الثابت 'سند مباشر' مع التحقق من الكاش أولاً
  /// يعيد المعرّف إذا كان مخزّناً، أو يستدعي الـ API ويخزّنه إذا لم يكن
  Future<int?> fetchGeneralPartnerId() async {
    // تحقق من الكاش: إذا كان موجوداً أعده مباشرة بدون استدعاء جديد
    if (_generalPartnerId != null) return _generalPartnerId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('general_partner_id');
      if (savedId != null) {
        _generalPartnerId = savedId;
        return _generalPartnerId;
      }

      // ليس مخزّناً → استدعاء الـ API
      final response = await _apiService.getGeneralPartner();
      if (response.statusCode == 200) {
        _generalPartnerId = response.data['PartnerID'] as int?;
        if (_generalPartnerId != null) {
          await prefs.setInt('general_partner_id', _generalPartnerId!);
        }
        return _generalPartnerId;
      }
    } catch (e) {
      // فشل الاتصال
    }
    return null;
  }
}
