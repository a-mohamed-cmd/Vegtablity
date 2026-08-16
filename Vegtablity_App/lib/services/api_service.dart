import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class ApiService {
  /// عنوان السيرفر الافتراضي بناءً على نوع النسخة (Flavor: washa / jawhara)
  static String get defaultIpAddress {
    const String envFlavor = String.fromEnvironment('FLAVOR');
    final String currentFlavor = envFlavor.isNotEmpty ? envFlavor : (appFlavor ?? 'washa');
    switch (currentFlavor.toLowerCase()) {
      case 'jawhara':
        return '185.216.203.50:8001'; // سيرفر الجوهرة
      case 'washa':
      default:
        return '185.216.203.50:8000'; // سيرفر واشا
    }
  }

  static String ipAddress = defaultIpAddress;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://$defaultIpAddress', // Update with actual API URL
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  void Function()? onUnauthorized;

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          if (onUnauthorized != null) {
            onUnauthorized!();
          }
        }
        return handler.next(e);
      },
    ));
  }

  // Method to set or clear the auth token for all subsequent requests
  void updateToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String? getToken() {
    final authHeader = _dio.options.headers['Authorization'] as String?;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    return null;
  }

  Future<Response> getCompanySettings() async {
    try {
      return await _dio.get('/settings/company');
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getProducts({String? search}) async {
    try {
      final queryParameters = search != null ? {'search': search} : null;
      return await _dio.get('/products', queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Sales Discounts (خصومات وباقات المبيعات) ──────────────────────────────
  Future<Response> getActiveDiscountsForPos() async {
    return await _dio.get('/discounts/pos/active');
  }

  Future<Response> getAllDiscounts() async {
    return await _dio.get('/discounts/');
  }

  Future<Response> getProductsForDiscounts() async {
    return await _dio.get('/discounts/products');
  }

  Future<Response> getAttachedProductIdsForDiscount(int discountId) async {
    return await _dio.get('/discounts/$discountId/products');
  }

  Future<Response> saveDiscount(Map<String, dynamic> payload) async {
    return await _dio.post('/discounts/', data: payload);
  }

  Future<Response> deleteDiscount(int discountId) async {
    return await _dio.delete('/discounts/$discountId');
  }

  Future<Response> getProductsForPurchase() async {
    return await _dio.get('/products/for-purchase');
  }

  Future<Response> getProductsForSales() async {
    return await _dio.get('/products/for-sales');
  }

  Future<Response> getProductsForRecipeIngredients({int? warehouseId}) async {
    final queryParams =
        warehouseId != null ? {'warehouse_id': warehouseId} : null;
    return await _dio.get('/products/for-recipe-ingredients',
        queryParameters: queryParams);
  }

  Future<Response> getProductsForRecipeTarget(
      {int? warehouseId, bool includeAll = false}) async {
    final queryParams = <String, dynamic>{};
    if (warehouseId != null) queryParams['warehouse_id'] = warehouseId;
    if (includeAll) queryParams['include_all'] = true;
    return await _dio.get('/products/for-recipe-target',
        queryParameters: queryParams.isNotEmpty ? queryParams : null);
  }

  // ─── Recipes (الوصفات والتصنيع) ──────────────────────────────────────────

  Future<Response> getAllRecipes() async {
    return await _dio.get('/recipes/');
  }

  Future<Response> getRecipeByProduct(int productId, {int? warehouseId}) async {
    final queryParams =
        warehouseId != null ? {'warehouse_id': warehouseId} : null;
    return await _dio.get('/recipes/$productId', queryParameters: queryParams);
  }

  Future<Response> saveRecipe(Map<String, dynamic> data) async {
    return await _dio.post('/recipes/', data: data);
  }

  Future<Response> deleteRecipe(int recipeId) async {
    return await _dio.delete('/recipes/$recipeId');
  }

  // الحسابات
  Future<Response> getRevenueAccounts() async {
    try {
      return await _dio.get('/accounts/revenues');
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getExpenseAccounts() async {
    try {
      return await _dio.get('/accounts/expenses');
    } catch (e) {
      rethrow;
    }
  }

  /// جلب بيانات العميل الثابت 'سند مباشر' - يُستدعى مرة واحدة ويُخزّن في الذاكرة
  Future<Response> getGeneralPartner() async {
    try {
      return await _dio.get('/accounts/general-partner');
    } catch (e) {
      rethrow;
    }
  }

  // السندات العامة
  Future<Response> saveGeneralVoucher({
    required String voucherType,
    required double totalAmount,
    required int accountId,
    required String description,
    required String paymentMethod,
    int? shiftId,
  }) async {
    try {
      return await _dio.post(
        '/vouchers/general',
        data: {
          'VoucherType': voucherType,
          'TotalAmount': totalAmount,
          'AccountID': accountId,
          'Description': description,
          'PaymentMethod': paymentMethod,
          if (shiftId != null) 'ShiftID': shiftId,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getPartners(
      {required String type, String search = ''}) async {
    return await _dio.get('/partners/', queryParameters: {
      'type': type,
      'search': search,
    });
  }

  Future<Response> login(String username, String password) async {
    return await _dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<Response> openShift(double startingCash) async {
    return await _dio.post(
      '/shifts/open',
      data: {'StartingCash': startingCash},
    );
  }

  Future<Response> closeShift(int shiftId, double endingCash) async {
    return await _dio.post(
      '/shifts/close',
      data: {
        'ShiftID': shiftId,
        'EndingCash': endingCash,
      },
    );
  }

  Future<Response> getShiftSummary(int shiftId) async {
    return await _dio.get('/shifts/summary/$shiftId');
  }

  Future<Response> getSalesQuotes() async {
    return await _dio.get('/sales-quotes');
  }

  Future<Response> getProductByBarcode(String barcode) async {
    return await _dio.get('/products/barcode/$barcode');
  }

  Future<Response> quickAddProduct(Map<String, dynamic> productData) async {
    return await _dio.post('/products/quick-add', data: productData);
  }

  Future<Response> getInvoices(
      {required String type, String? search, int? shiftId}) async {
    return await _dio.get('/invoices/', queryParameters: {
      'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
      if (shiftId != null) 'shift_id': shiftId,
    });
  }

  Future<Response> getInvoiceById(int invId) async {
    return await _dio.get('/invoices/$invId');
  }

  Future<Response> payInvoice(int invId, double amount,
      {int? accountId}) async {
    return await _dio.post('/invoices/$invId/pay', data: {
      'PaymentAmount': amount,
      if (accountId != null) 'PaymentAccountID': accountId,
    });
  }

  Future<Response> getPaymentAccounts() async {
    return await _dio.get('/settings/payment-accounts');
  }

  Future<Response> getInvoicePaymentSplits(int invId) async {
    return await _dio.get('/invoices/$invId/payment-splits');
  }

  Future<Response> getInvoiceDetails(int invId) async {
    return await _dio.get('/invoices/$invId');
  }

  Future<Response> saveInvoice(Map<String, dynamic> invoiceData) async {
    return await _dio.post('/sales/invoice', data: invoiceData);
  }

  Future<Response> savePartnerInvoice(Map<String, dynamic> invoiceData) async {
    return await _dio.post('/invoices/', data: invoiceData);
  }

  Future<Response> checkLicense(String hwid) async {
    return await _dio.post('/security/check-license', data: {
      'MachineHWID': hwid,
    });
  }

  Future<Response> getActiveShift() async {
    return await _dio.get('/shifts/active');
  }

  Future<Response> getPrinterSettings(String hwid) async {
    return await _dio.get('/settings/printer/$hwid');
  }

  Future<Response> savePrinterSettings(Map<String, dynamic> data) async {
    return await _dio.post('/settings/printer', data: data);
  }

  // Active Partner Offers & Quote Details
  Future<Response> getPurchaseQuotes() async {
    return await _dio.get('/purchase-quotes');
  }

  Future<Response> getActivePurchasePartners() async {
    return await _dio.get('/partners/active-purchase-offers');
  }

  Future<Response> getActiveSalesPartners() async {
    return await _dio.get('/partners/active-sales-offers');
  }

  Future<Response> getSalesQuoteDetails(int quoteId) async {
    return await _dio.get('/sales-quotes/$quoteId/details');
  }

  Future<Response> getPurchaseQuoteDetails(int quoteId) async {
    return await _dio.get('/purchase-quotes/$quoteId/details');
  }

  // ─── Vouchers (سندات القبض والصرف) ──────────────────────────────────────

  /// جلب الفواتير المُرحّلة وغير المسدّدة للشريك
  /// type: 'Sales' للعملاء | 'Purchase' للموردين
  Future<Response> getUnpaidInvoices(int partnerId, String type) async {
    return await _dio.get('/vouchers/unpaid_invoices', queryParameters: {
      'partner_id': partnerId,
      'type': type,
    });
  }

  /// جلب الحسابات المتاحة (صندوق/بنك) لاستخدامها في السند
  Future<Response> getVoucherAccounts() async {
    return await _dio.get('/vouchers/accounts');
  }

  /// سداد جماعي وإنشاء سند قبض/صرف
  Future<Response> bulkPay({
    required int partnerId,
    required String voucherType, // 'Receipt' | 'Payment'
    required double totalAmount,
    required int accountId,
    required int shiftId,
    required List<Map<String, dynamic>> allocations,
    String description = '',
  }) async {
    return await _dio.post('/vouchers/bulk_pay', data: {
      'PartnerID': partnerId,
      'VoucherType': voucherType,
      'TotalAmount': totalAmount,
      'AccountID': accountId,
      'ShiftID': shiftId,
      'Description': description,
      'Allocations': allocations,
    });
  }

  /// جلب الفواتير المسددة داخل السند (لإعادة الطباعة)
  Future<Response> getVoucherAllocations(int voucherId) async {
    return await _dio.get('/vouchers/$voucherId/allocations');
  }

  // ─── Inventory (الهالك والجرد) ──────────────────────────────────────────

  /// حفظ مسودة إهلاك بضاعة
  Future<Response> saveWastage(Map<String, dynamic> wastageData) async {
    return await _dio.post('/inventory/wastage', data: wastageData);
  }

  /// حفظ مسودة جرد مخزني
  Future<Response> saveStockTake(Map<String, dynamic> stockTakeData) async {
    return await _dio.post('/inventory/stocktake', data: stockTakeData);
  }

  /// جلب مخزون وتكلفة صنف معين في مستودع محدد
  Future<Response> getProductStockCost(int productId, int warehouseId) async {
    return await _dio.get('/inventory/stock-cost', queryParameters: {
      'product_id': productId,
      'warehouse_id': warehouseId,
    });
  }

  /// جلب قائمة المستودعات
  Future<Response> getWarehouses() async {
    return await _dio.get('/settings/warehouses');
  }

  /// جلب الطلبات اليومية للتوصيل بالتاريخ
  Future<Response> getDailyOrders(String date) async {
    return await _dio
        .get('/invoices/daily-orders', queryParameters: {'date': date});
  }
}
