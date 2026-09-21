import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../models/dashboard_summary_model.dart';
import '../models/report_models.dart';
import '../services/reports_service.dart';

enum DatePreset { today, thisWeek, thisMonth, thisYear, custom }

class ReportsProvider with ChangeNotifier {
  final ReportsService _service = ReportsService();

  late CompanyInfoModel _selectedCompany;
  CompanyInfoModel get selectedCompany => _selectedCompany;

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  DatePreset _datePreset = DatePreset.thisMonth;
  DatePreset get datePreset => _datePreset;

  late DateTime _startDate;
  DateTime get startDate => _startDate;

  late DateTime _endDate;
  DateTime get endDate => _endDate;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Cached Reports Data
  DashboardSummaryModel? _dashboardSummary;
  DashboardSummaryModel? get dashboardSummary => _dashboardSummary;

  List<ProductProfitModel> _productProfits = [];
  List<ProductProfitModel> get productProfits => _productProfits;

  List<InvoiceProfitModel> _invoiceProfits = [];
  List<InvoiceProfitModel> get invoiceProfits => _invoiceProfits;

  List<SalesTrendModel> _salesTrends = [];
  List<SalesTrendModel> get salesTrends => _salesTrends;

  List<TopCustomerModel> _topCustomers = [];
  List<TopCustomerModel> get topCustomers => _topCustomers;

  List<AgingDebtModel> _agingDebts = [];
  List<AgingDebtModel> get agingDebts => _agingDebts;

  List<InventoryValuationModel> _inventoryValuation = [];
  List<InventoryValuationModel> get inventoryValuation => _inventoryValuation;

  List<SlowMovingStockModel> _slowMovingStock = [];
  List<SlowMovingStockModel> get slowMovingStock => _slowMovingStock;

  List<ExpensesAnalysisModel> _expensesAnalysis = [];
  List<ExpensesAnalysisModel> get expensesAnalysis => _expensesAnalysis;

  List<CategoryProfitModel> _categoryProfits = [];
  List<CategoryProfitModel> get categoryProfits => _categoryProfits;

  List<CashierPerformanceModel> _cashierPerformance = [];
  List<CashierPerformanceModel> get cashierPerformance => _cashierPerformance;

  List<PaymentMethodModel> _paymentMethods = [];
  List<PaymentMethodModel> get paymentMethods => _paymentMethods;

  List<CustomerProfitabilityModel> _customerProfitability = [];
  List<CustomerProfitabilityModel> get customerProfitability =>
      _customerProfitability;

  ExecutivePnLModel _executivePnL = ExecutivePnLModel.empty();
  ExecutivePnLModel get executivePnL => _executivePnL;

  List<WastageAnalysisModel> _wastageAnalysis = [];
  List<WastageAnalysisModel> get wastageAnalysis => _wastageAnalysis;

  List<ShiftAnalyticsModel> _shiftsAnalytics = [];
  List<ShiftAnalyticsModel> get shiftsAnalytics => _shiftsAnalytics;

  // Search queries
  String _productSearch = '';
  String get productSearch => _productSearch;

  ReportsProvider() {
    _selectedCompany = AppConfig.detectDefaultCompany();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _initSavedCompany();
  }

  Future<void> _initSavedCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompId = prefs.getString('selected_company_id');
      if (savedCompId != null && savedCompId.isNotEmpty) {
        final match = AppConfig.companies.firstWhere(
          (c) => c.id == savedCompId || c.code == savedCompId,
          orElse: () => _selectedCompany,
        );
        _selectedCompany = match;
      }
    } catch (_) {}
    loadAllCurrentTab();
  }

  String get startDateFormatted => DateFormat('yyyy-MM-dd').format(_startDate);
  String get endDateFormatted => DateFormat('yyyy-MM-dd').format(_endDate);

  void setSelectedCompany(CompanyInfoModel company) {
    if (_selectedCompany.id != company.id) {
      _selectedCompany = company;
      _persistCompany(company.id);
      notifyListeners();
      loadAllCurrentTab();
    }
  }

  Future<void> _persistCompany(String companyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_company_id', companyId);
    } catch (_) {}
  }

  void setSelectedTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
    loadAllCurrentTab();
  }

  void setProductSearch(String query) {
    _productSearch = query;
    notifyListeners();
  }

  void setDatePreset(DatePreset preset) {
    _datePreset = preset;
    final now = DateTime.now();

    switch (preset) {
      case DatePreset.today:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
        break;
      case DatePreset.thisWeek:
        _startDate = now.subtract(Duration(days: now.weekday % 7));
        _endDate = now;
        break;
      case DatePreset.thisMonth:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case DatePreset.thisYear:
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
        break;
      case DatePreset.custom:
        break;
    }

    notifyListeners();
    loadAllCurrentTab();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _datePreset = DatePreset.custom;
    _startDate = start;
    _endDate = end;
    notifyListeners();
    loadAllCurrentTab();
  }

  Future<void> loadAllCurrentTab() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = _selectedCompany.id;
      final s = startDateFormatted;
      final e = endDateFormatted;

      switch (_selectedTabIndex) {
        case 0: // الداشبورد العامة
          _dashboardSummary = await _service.getDashboardSummary(
              database: db, startDate: s, endDate: e);
          _salesTrends = await _service.getSalesTrends(
            database: db,
            startDate: s,
            endDate: e,
            periodType:
                _datePreset == DatePreset.thisYear ? 'Monthly' : 'Daily',
          );
          _topCustomers = await _service.getTopCustomers(
              database: db, startDate: s, endDate: e);
          _executivePnL = await _service.getExecutivePnL(
              database: db, startDate: s, endDate: e);
          break;
        case 1: // أرباح الأصناف
          _productProfits = await _service.getProductProfits(
              database: db, startDate: s, endDate: e);
          break;
        case 2: // أرباح الفواتير
          _invoiceProfits = await _service.getInvoiceProfits(
              database: db, startDate: s, endDate: e);
          break;
        case 3: // أرباح التصنيفات
          _categoryProfits = await _service.getCategoryProfits(
              database: db, startDate: s, endDate: e);
          break;
        case 4: // قائمة الأرباح والخسائر P&L
          _executivePnL = await _service.getExecutivePnL(
              database: db, startDate: s, endDate: e);
          break;
        case 5: // ربحية العملاء
          _customerProfitability = await _service.getCustomerProfitability(
              database: db, startDate: s, endDate: e);
          break;
        case 6: // حركة المبيعات
          _salesTrends = await _service.getSalesTrends(
            database: db,
            startDate: s,
            endDate: e,
            periodType:
                _datePreset == DatePreset.thisYear ? 'Monthly' : 'Daily',
          );
          break;
        case 7: // كبار العملاء
          _topCustomers = await _service.getTopCustomers(
              database: db, startDate: s, endDate: e);
          break;
        case 8: // أعمار الديون
          _agingDebts = await _service.getAgingDebt(database: db);
          break;
        case 9: // تقييم المخزون
          _inventoryValuation =
              await _service.getInventoryValuation(database: db);
          break;
        case 10: // الأصناف الراكدة
          _slowMovingStock = await _service.getSlowMovingStock(database: db);
          break;
        case 11: // تحليل المصروفات
          _expensesAnalysis = await _service.getExpensesAnalysis(
              database: db, startDate: s, endDate: e);
          break;
        case 12: // أداء الكاشير والمستخدمين
          _cashierPerformance = await _service.getCashierPerformance(
              database: db, startDate: s, endDate: e);
          break;
        case 13: // طرق الدفع والمقبوضات
          _paymentMethods = await _service.getPaymentMethods(
              database: db, startDate: s, endDate: e);
          break;
        case 14: // الهالك والتوالف
          _wastageAnalysis = await _service.getWastageAnalysis(
              database: db, startDate: s, endDate: e);
          break;
        case 15: // حركة الورديات
          _shiftsAnalytics = await _service.getShiftsAnalytics(
              database: db, startDate: s, endDate: e);
          break;
      }
    } catch (err) {
      _errorMessage = err.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
