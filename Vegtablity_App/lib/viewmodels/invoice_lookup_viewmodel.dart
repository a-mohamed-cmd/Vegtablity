import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class InvoiceLookupViewModel extends ChangeNotifier {
  final ApiService _apiService;

  final TextEditingController searchController = TextEditingController();
  Map<String, dynamic>? _invoiceData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _allowEditUnposted = false;

  InvoiceLookupViewModel(this._apiService) {
    _loadSettings();
  }

  Map<String, dynamic>? get invoiceData => _invoiceData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get allowEditUnposted => _allowEditUnposted;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowEditUnposted = prefs.getBool('pref_allow_edit_unposted_invoices') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> searchInvoice({int? invId}) async {
    final int? idToSearch = invId ?? int.tryParse(searchController.text.trim());
    if (idToSearch == null || idToSearch <= 0) {
      _errorMessage = 'يرجى إدخال رقم فاتورة صحيح';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _invoiceData = null;
    notifyListeners();

    try {
      final response = await _apiService.getInvoiceById(idToSearch);
      if (response.statusCode == 200 && response.data != null) {
        try {
          final Map<String, dynamic> rawData = Map<String, dynamic>.from(response.data as Map);
          _invoiceData = _normalizeInvoiceForPrinting(rawData);
          _isLoading = false;
          notifyListeners();
        } catch (parseError, stack) {
          if (kDebugMode) {
            print('Error parsing invoice #$idToSearch data: $parseError\n$stack');
          }
          _errorMessage = 'تم العثور على الفاتورة رقم ($idToSearch) بالخادم، ولكن حدث خطأ عند تحليل البيانات (${parseError.toString()})';
          _isLoading = false;
          notifyListeners();
        }
      } else {
        _errorMessage = 'الفاتورة رقم ($idToSearch) غير موجودة بالنظام (كود الاستجابة: ${response.statusCode})';
        _isLoading = false;
        notifyListeners();
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 404) {
        _errorMessage = 'الفاتورة رقم ($idToSearch) غير موجودة بنظام السيرفر (404 Not Found)';
      } else if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError) {
        _errorMessage = 'تعذر الاتصال بالسيرفر، يرجى التأكد من تشغيل الخادم وجودة الاتصال بالشبكة';
      } else {
        _errorMessage = 'حدث خطأ بالشبكة أثناء جلب الفاتورة: ${dioErr.message ?? dioErr.toString()}';
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    searchController.clear();
    _invoiceData = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> printInvoice(PrinterService printerService) async {
    if (_invoiceData == null) return false;
    return await printerService.printReceipt(_invoiceData!, isReprint: true);
  }

  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  Map<String, dynamic> _normalizeInvoiceForPrinting(Map<String, dynamic> raw) {
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(raw);

    final double totalAmount = _parseDouble(raw['TotalAmount'] ?? raw['original_total']);
    final double discount = _parseDouble(raw['Discount'] ?? raw['discount_amount']);
    final double netAmount = _parseDouble(raw['NetAmount'] ?? raw['total_amount'] ?? (totalAmount - discount));
    final double paidAmount = _parseDouble(raw['PaidAmount'] ?? raw['paid_amount']);
    final double remainder = _parseDouble(raw['Remainder'] ?? raw['remainder']);

    normalized['InvID'] = raw['InvID'] ?? raw['inv_id'] ?? raw['InvoiceID'];
    normalized['type'] = raw['InvType'] ?? raw['type'] ?? 'Sales';
    normalized['InvType'] = normalized['type'];
    normalized['created_at'] = raw['InvDate'] ?? raw['created_at'] ?? DateTime.now().toIso8601String();
    normalized['InvDate'] = normalized['created_at'];
    normalized['PartnerID'] = raw['PartnerID'] ?? raw['partner_id'];
    normalized['WarehouseID'] = raw['WarehouseID'] ?? raw['warehouse_id'];
    normalized['ShiftID'] = raw['ShiftID'] ?? raw['shift_id'];
    normalized['IsPosted'] = raw['IsPosted'] ?? raw['is_posted'];
    normalized['PaymentAccountID'] = raw['PaymentAccountID'] ?? raw['payment_account_id'];

    normalized['original_total'] = totalAmount;
    normalized['TotalAmount'] = totalAmount;

    normalized['discount_amount'] = discount;
    normalized['Discount'] = discount;

    normalized['total_amount'] = netAmount;
    normalized['NetAmount'] = netAmount;

    normalized['paid_amount'] = paidAmount;
    normalized['PaidAmount'] = paidAmount;

    normalized['remainder'] = remainder;
    normalized['Remainder'] = remainder;

    normalized['PartnerName'] = raw['PartnerName'] ?? raw['partner_name'];
    normalized['partner_name'] = normalized['PartnerName'];
    normalized['WarehouseName'] = raw['WarehouseName'];
    normalized['UserName'] = raw['UserName'];
    normalized['PaymentAccountName'] = raw['PaymentAccountName'];

    // Shipping / Delivery fields
    normalized['temp_customer_name'] = raw['TempCustomerName'] ?? raw['temp_customer_name'];
    normalized['temp_phone'] = raw['TempPhone'] ?? raw['temp_phone'];
    normalized['temp_address'] = raw['TempAddress'] ?? raw['temp_address'];
    normalized['temp_delivery_date'] = raw['TempDeliveryDate'] ?? raw['temp_delivery_date'];
    normalized['temp_delivery_time'] = raw['TempDeliveryTime'] ?? raw['temp_delivery_time'];
    normalized['temp_notes'] = raw['Notes'] ?? raw['temp_notes'];

    // Normalize PaymentSplits
    final List rawSplits = (raw['PaymentSplits'] ?? raw['payment_splits'] ?? []) as List;
    normalized['PaymentSplits'] = rawSplits.map((s) => Map<String, dynamic>.from(s as Map)).toList();

    // Normalize items details list to support ALL keys expected by POS printer
    final List rawDetails = (raw['Details'] ?? raw['items'] ?? raw['InvoiceDetails'] ?? []) as List;
    final List<Map<String, dynamic>> normalizedItems = rawDetails.map((d) {
      final Map<String, dynamic> itemMap = Map<String, dynamic>.from(d as Map);
      final String name = itemMap['ProductName']?.toString() ?? itemMap['name']?.toString() ?? 'منتج غير معروف';
      final double qty = _parseDouble(itemMap['Quantity'] ?? itemMap['quantity'], 1.0);
      final double unitPrice = _parseDouble(itemMap['UnitPrice'] ?? itemMap['price'] ?? itemMap['CostPrice'], 0.0);
      final double totalPrice = _parseDouble(itemMap['TotalPrice'] ?? itemMap['total'], unitPrice * qty);
      final double discAmount = _parseDouble(itemMap['DiscountAmount'] ?? itemMap['discountAmount']);
      final String unitName = itemMap['UnitName']?.toString() ?? itemMap['unit_name']?.toString() ?? itemMap['unit']?.toString() ?? '';

      return <String, dynamic>{
        'ProductName': name,
        'name': name,
        'Quantity': qty,
        'quantity': qty,
        'UnitPrice': unitPrice,
        'price': unitPrice,
        'TotalPrice': totalPrice,
        'total': totalPrice,
        'DiscountAmount': discAmount,
        'discountAmount': discAmount,
        'UnitName': unitName,
        'unit': unitName,
        'unit_name': unitName,
      };
    }).toList();

    normalized['items'] = normalizedItems;
    normalized['Details'] = normalizedItems;
    normalized['InvoiceDetails'] = normalizedItems;

    return normalized;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
