import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.43.129:8000', // Update with actual API URL
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  ApiService() {
    // Add default headers or logging if necessary
  }

  // Method to set or clear the auth token for all subsequent requests
  void updateToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
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

  Future<Response> getInvoices({required String type, String? search, String? shiftDate}) async {
    return await _dio.get('/invoices/', queryParameters: {
      'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
      if (shiftDate != null && shiftDate.isNotEmpty) 'shift_date': shiftDate,
    });
  }

  Future<Response> payInvoice(int invId, double amount, {int? accountId}) async {
    return await _dio.post('/invoices/$invId/pay', data: {
      'PaymentAmount': amount,
      if (accountId != null) 'PaymentAccountID': accountId,
    });
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

  Future<Response> getCompanySettings() async {
    return await _dio.get('/settings/company');
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
}


