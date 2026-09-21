import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/dashboard_summary_model.dart';
import '../models/report_models.dart';

class ReportsService {
  final ApiClient _client = ApiClient();

  // 1. ملخص الداشبورد
  Future<DashboardSummaryModel> getDashboardSummary({
    required String database,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/dashboard-summary',
        queryParameters: {
          'database': database,
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return DashboardSummaryModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading dashboard summary for $database: $e');
    }
    return DashboardSummaryModel.empty(database);
  }

  // 2. أرباح الأصناف
  Future<List<ProductProfitModel>> getProductProfits({
    required String database,
    required String startDate,
    required String endDate,
    String orderBy = 'ProfitDESC',
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/product-profits',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
          'order_by': orderBy,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => ProductProfitModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading product profits: $e');
    }
    return [];
  }

  // 3. أرباح الفواتير
  Future<List<InvoiceProfitModel>> getInvoiceProfits({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/invoice-profits',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => InvoiceProfitModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading invoice profits: $e');
    }
    return [];
  }

  // 4. اتجاهات المبيعات
  Future<List<SalesTrendModel>> getSalesTrends({
    required String database,
    required String startDate,
    required String endDate,
    String periodType = 'Daily',
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/sales-trends',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
          'period_type': periodType,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SalesTrendModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sales trends: $e');
    }
    return [];
  }

  // 5. كبار العملاء
  Future<List<TopCustomerModel>> getTopCustomers({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/top-customers',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => TopCustomerModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading top customers: $e');
    }
    return [];
  }

  // 6. أعمار الديون
  Future<List<AgingDebtModel>> getAgingDebt({
    required String database,
    String? asOfDate,
    int? partnerId,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/aging-debt',
        queryParameters: {
          'database': database,
          if (asOfDate != null) 'as_of_date': asOfDate,
          if (partnerId != null) 'partner_id': partnerId,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => AgingDebtModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading aging debt: $e');
    }
    return [];
  }

  // 7. تقييم المخزون
  Future<List<InventoryValuationModel>> getInventoryValuation({
    required String database,
    int warehouseId = 0,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/inventory-valuation',
        queryParameters: {
          'database': database,
          'warehouse_id': warehouseId,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => InventoryValuationModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading inventory valuation: $e');
    }
    return [];
  }

  // 8. الأصناف الراكدة
  Future<List<SlowMovingStockModel>> getSlowMovingStock({
    required String database,
    int monthsInactive = 1,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/slow-moving-stock',
        queryParameters: {
          'database': database,
          'months_inactive': monthsInactive,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => SlowMovingStockModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading slow moving stock: $e');
    }
    return [];
  }

  // 9. تحليل المصروفات
  Future<List<ExpensesAnalysisModel>> getExpensesAnalysis({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/expenses-analysis',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => ExpensesAnalysisModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading expenses analysis: $e');
    }
    return [];
  }

  // 10. أرباح التصنيفات
  Future<List<CategoryProfitModel>> getCategoryProfits({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/category-profits',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => CategoryProfitModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading category profits: $e');
    }
    return [];
  }

  // 11. أداء الكاشير والمستخدمين
  Future<List<CashierPerformanceModel>> getCashierPerformance({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/cashier-performance',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => CashierPerformanceModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cashier performance: $e');
    }
    return [];
  }

  // 12. تحليل طرق الدفع
  Future<List<PaymentMethodModel>> getPaymentMethods({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/payment-methods',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => PaymentMethodModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    }
    return [];
  }

  // 13. ربحية العملاء التفصيلية
  Future<List<CustomerProfitabilityModel>> getCustomerProfitability({
    required String database,
    required String startDate,
    required String endDate,
    int topN = 50,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/customer-profitability',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
          'top_n': topN,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => CustomerProfitabilityModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading customer profitability: $e');
    }
    return [];
  }

  // 14. ملخص الأرباح والخسائر التنفيذي (Executive PnL)
  Future<ExecutivePnLModel> getExecutivePnL({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/executive-pnl',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ExecutivePnLModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading executive PnL: $e');
    }
    return ExecutivePnLModel.empty();
  }

  // 15. تقرير الهالك والتوالف
  Future<List<WastageAnalysisModel>> getWastageAnalysis({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/wastage-analysis',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => WastageAnalysisModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading wastage analysis: $e');
    }
    return [];
  }

  // 16. حركة وأرباح الورديات
  Future<List<ShiftAnalyticsModel>> getShiftsAnalytics({
    required String database,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/shifts-analytics',
        queryParameters: {
          'database': database,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((i) => ShiftAnalyticsModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading shifts analytics: $e');
    }
    return [];
  }
}

