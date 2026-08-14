import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'api_service.dart';
import 'printing/printer_base.dart';
import 'printing/invoice_print_designer.dart';
import 'printing/shift_report_print_designer.dart';
import 'printing/voucher_print_designer.dart';
import 'printing/recipe_print_designer.dart';
import 'printing/inventory_print_designer.dart';
import 'printing/barcode_print_designer.dart';

/// ViewModel & Central Printer Service Dispatcher
class PrinterService extends ChangeNotifier {
  final ApiService? _apiService;

  Map<String, dynamic>? _companySettings;
  String _connectionType = 'None'; // 'Network', 'Bluetooth', 'None'
  String _ipAddress = '192.168.1.100';
  int _port = 9100;
  String _bluetoothDevice = '';
  int _paperSize = 80; // 58 or 80
  String _networkPrintMode = 'direct'; // 'direct', 'raster' (canva)
  int _printCopies = 1; // Effective for Network connection mode only
  bool _isSynced = false;

  // Global store for the last added document across the system
  Map<String, dynamic>? _lastAddedDocument;

  String get connectionType => _connectionType;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get bluetoothDevice => _bluetoothDevice;
  int get paperSize => _paperSize;
  String get networkPrintMode => _networkPrintMode;
  int get printCopies => _printCopies;
  bool get isSynced => _isSynced;
  Map<String, dynamic>? get companySettings => _companySettings;
  Map<String, dynamic>? get lastAddedDocument => _lastAddedDocument;

  bool get isPaper80mm => _paperSize == 80;

  PrinterService([this._apiService]) {
    _initSunmiPrinter();
    _loadSettings();
    _loadCompanySettings();
  }

  Future<void> _loadCompanySettings() async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.getCompanySettings();
      if (response.statusCode == 200 && response.data != null) {
        _companySettings = Map<String, dynamic>.from(response.data);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading company settings in PrinterService: $e');
    }
  }

  Future<void> _initSunmiPrinter() async {
    try {
      await SunmiPrinter.bindingPrinter();
    } catch (e) {
      if (kDebugMode) print('Error binding Sunmi printer: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Read printer settings exclusively from local device storage (SharedPreferences)
      _connectionType = prefs.getString('printer_connection_type') ?? 'None';
      _ipAddress = prefs.getString('printer_ip') ?? '192.168.1.100';
      _port = prefs.getInt('printer_port') ?? 9100;
      _bluetoothDevice = prefs.getString('printer_bluetooth') ?? '';
      _paperSize = prefs.getInt('printer_paper_size') ?? 80;
      _networkPrintMode = prefs.getString('printer_network_mode') ?? 'direct';
      _printCopies = prefs.getInt('printer_print_copies') ?? 1;
      _isSynced = false;

      String? hwid = prefs.getString('machine_hwid');
      if (hwid == null || hwid.isEmpty) {
        hwid = 'HWID_' + DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('machine_hwid', hwid);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading printer settings locally: $e');
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  Future<bool> saveSettings({
    required String connectionType,
    required String ipAddress,
    required int port,
    required String bluetoothDevice,
    int paperSize = 80,
    String networkPrintMode = 'direct',
    int printCopies = 1,
  }) async {
    try {
      _connectionType = connectionType;
      _ipAddress = ipAddress;
      _port = port;
      _bluetoothDevice = bluetoothDevice;
      _paperSize = paperSize;
      _networkPrintMode = networkPrintMode;
      _printCopies = printCopies;
      _isSynced = false;
      notifyListeners();

      // Save exclusively to local device storage (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_connection_type', connectionType);
      await prefs.setString('printer_ip', ipAddress);
      await prefs.setInt('printer_port', port);
      await prefs.setString('printer_bluetooth', bluetoothDevice);
      await prefs.setInt('printer_paper_size', paperSize);
      await prefs.setString('printer_network_mode', networkPrintMode);
      await prefs.setInt('printer_print_copies', printCopies);

      return true;
    } catch (e) {
      if (kDebugMode) print('Error saving printer settings locally: $e');
      return false;
    }
  }

  // =========================================================================
  // GLOBAL REGISTER & REPRINT LAST ADDED DOCUMENT
  // =========================================================================

  void registerLastAddedDocument(String docType, Map<String, dynamic> data) {
    _lastAddedDocument = {
      'doc_type': docType,
      'data': Map<String, dynamic>.from(data),
      'registered_at': DateTime.now().toIso8601String(),
    };
    notifyListeners();
  }

  Future<bool> printLastAddedDocument() async {
    if (_lastAddedDocument == null) return false;
    final docType = _lastAddedDocument!['doc_type']?.toString();
    final data = Map<String, dynamic>.from(_lastAddedDocument!['data'] as Map);

    if (docType == 'invoice') {
      return await printReceipt(data, isReprint: true);
    } else if (docType == 'voucher') {
      final List<Map<String, dynamic>> paidInvoices = (data['paidInvoices'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      return await printVoucher(data, paidInvoices, isReprint: true);
    } else if (docType == 'general_voucher') {
      return await printGeneralVoucher(
        data,
        data['targetAccountName']?.toString() ?? '',
        data['cashAccountName']?.toString() ?? '',
        isReprint: true,
      );
    } else if (docType == 'wastage') {
      return await printWastageReceipt(data, isReprint: true);
    } else if (docType == 'stocktake') {
      return await printStockTakeReceipt(data, isReprint: true);
    } else if (docType == 'recipe') {
      return await printRecipe(data, isReprint: true);
    }
    return false;
  }

  // =========================================================================
  // 1. PRINT SALES/PURCHASE INVOICE (طباعة فواتير المبيعات والمشتريات)
  // =========================================================================

  Future<bool> printReceipt(Map<String, dynamic> invoice, {bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        registerLastAddedDocument('invoice', invoice);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await InvoicePrintDesigner.printSunmiInvoice(
            invoice: invoice,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await InvoicePrintDesigner.buildInvoicePrintBytes(
            invoice: invoice,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printReceipt: $e');
      return false;
    }
  }

  // =========================================================================
  // 2. PRINT TEST RECEIPT (طباعة تجربة الطابعة)
  // =========================================================================

  Future<bool> printTestReceipt({bool? isArabic}) async {
    final Map<String, dynamic> testInvoice = {
      'id': 9999,
      'type': 'مبيعات',
      'PartnerName': 'عميل تجريبي',
      'total_amount': 15.500,
      'items': [
        {'product_name': 'منتج تجريبي 1', 'quantity': 2, 'price': 5.000, 'unit_name': 'كيلو'},
        {'product_name': 'منتج تجريبي 2', 'quantity': 1, 'price': 5.500, 'unit_name': 'كرتون'},
      ],
    };
    return await printReceipt(testInvoice, isArabic: isArabic, isReprint: true);
  }

  // =========================================================================
  // 3. PRINT SHIFT CLOSING REPORT (طباعة تقرير إغلاق الوردية)
  // =========================================================================

  Future<bool> printDailyReport({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
    String? openWarehouseName,
    bool? isArabic,
  }) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? warehouse = openWarehouseName ?? prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await ShiftReportPrintDesigner.printSunmiShiftReport(
            summary: summary,
            salesInvoices: salesInvoices,
            purchaseInvoices: purchaseInvoices,
            endingCash: endingCash,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: warehouse,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await ShiftReportPrintDesigner.buildShiftReportBytes(
            summary: summary,
            salesInvoices: salesInvoices,
            purchaseInvoices: purchaseInvoices,
            endingCash: endingCash,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: warehouse,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printDailyReport: $e');
      return false;
    }
  }

  // =========================================================================
  // 4. PRINT RECIPE RECEIPT (طباعة وصفات التصنيع والمنتجات)
  // =========================================================================

  Future<bool> printRecipe(Map<String, dynamic> recipe, {Map<String, dynamic>? companySettings, bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        registerLastAddedDocument('recipe', recipe);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final settings = companySettings ?? _companySettings;
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await RecipePrintDesigner.printSunmiRecipe(
            recipe: recipe,
            companySettings: settings,
            paperSize: _paperSize,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> bytes = await RecipePrintDesigner.buildRecipeBytes(
            recipe: recipe,
            companySettings: settings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(bytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printRecipe: $e');
      return false;
    }
  }

  // =========================================================================
  // 5. PRINT RECEIPT & PAYMENT VOUCHER (طباعة سندات القبض والصرف)
  // =========================================================================

  Future<bool> printVoucher(Map<String, dynamic> voucher, List<Map<String, dynamic>> paidInvoices, {bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        final regData = Map<String, dynamic>.from(voucher);
        regData['paidInvoices'] = paidInvoices;
        registerLastAddedDocument('voucher', regData);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await VoucherPrintDesigner.printSunmiVoucher(
            voucher: voucher,
            paidInvoices: paidInvoices,
            companySettings: _companySettings,
            paperSize: _paperSize,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await VoucherPrintDesigner.buildVoucherBytes(
            voucher: voucher,
            paidInvoices: paidInvoices,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printVoucher: $e');
      return false;
    }
  }

  // =========================================================================
  // 6. PRINT GENERAL VOUCHER (طباعة السندات العامة)
  // =========================================================================

  Future<bool> printGeneralVoucher(Map<String, dynamic> voucher, String targetAccountName, String cashAccountName, {bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        final regData = Map<String, dynamic>.from(voucher);
        regData['targetAccountName'] = targetAccountName;
        regData['cashAccountName'] = cashAccountName;
        registerLastAddedDocument('general_voucher', regData);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await VoucherPrintDesigner.printSunmiGeneralVoucher(
            voucher: voucher,
            targetAccountName: targetAccountName,
            cashAccountName: cashAccountName,
            companySettings: _companySettings,
            paperSize: _paperSize,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await VoucherPrintDesigner.buildGeneralVoucherBytes(
            voucher: voucher,
            targetAccountName: targetAccountName,
            cashAccountName: cashAccountName,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printGeneralVoucher: $e');
      return false;
    }
  }

  // =========================================================================
  // 7. PRINT WASTAGE RECEIPT (طباعة إيصالات التالف)
  // =========================================================================

  Future<bool> printWastageReceipt(Map<String, dynamic> data, {bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        registerLastAddedDocument('wastage', data);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await InventoryPrintDesigner.printSunmiWastage(
            data: data,
            companySettings: _companySettings,
            paperSize: _paperSize,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await InventoryPrintDesigner.buildWastageBytes(
            data: data,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printWastageReceipt: $e');
      return false;
    }
  }

  // =========================================================================
  // 8. PRINT STOCK TAKE RECEIPT (طباعة إيصالات جرد المخزون)
  // =========================================================================

  Future<bool> printStockTakeReceipt(Map<String, dynamic> data, {bool? isArabic, bool isReprint = false}) async {
    try {
      if (!isReprint) {
        registerLastAddedDocument('stocktake', data);
      }
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

      final int loops = (_connectionType == 'Network') ? _printCopies.clamp(1, 10) : 1;

      for (int i = 0; i < loops; i++) {
        if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
          await InventoryPrintDesigner.printSunmiStockTake(
            data: data,
            companySettings: _companySettings,
            paperSize: _paperSize,
            isArabic: arabic,
          );
        } else if (_connectionType == 'Network') {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await InventoryPrintDesigner.buildStockTakeBytes(
            data: data,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
            isArabic: arabic,
            networkPrintMode: _networkPrintMode,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printStockTakeReceipt: $e');
      return false;
    }
  }


  // =========================================================================
  Future<bool> printBarcodeLabel(Map<String, dynamic> product, {int copies = 1, bool? isArabic}) async {
    final effectiveIsArabic = isArabic ?? true;
    final int effectiveCopies = copies > 0 ? copies : 1;

    try {
      if (_companySettings == null) await _loadCompanySettings();
      await _loadSettings();

      if (_connectionType == 'Network') {
        final List<int> bytes = await BarcodePrintDesigner.generateCanvasRasterBytes(
          product,
          _companySettings,
          paperSize: _paperSize,
          isArabic: effectiveIsArabic,
        );
        if (bytes.isEmpty) return false;

        for (int i = 0; i < effectiveCopies; i++) {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
          if (effectiveCopies > 1 && i < effectiveCopies - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
        return true;
      } else {
        // Bluetooth / Sunmi hardware printer
        for (int i = 0; i < effectiveCopies; i++) {
          await BarcodePrintDesigner.printSunmiBarcodeLabel(
            product: product,
            companySettings: _companySettings,
            paperSize: _paperSize,
            isArabic: effectiveIsArabic,
          );
          if (effectiveCopies > 1 && i < effectiveCopies - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Error printing barcode label: $e');
      return false;
    }
  }

  // MANUAL CASH DRAWER OPEN (فتح درج النقدية يددياً)
  // =========================================================================

  Future<bool> openCashDrawer() async {
    try {
      if (_connectionType == 'Bluetooth') {
        // Bluetooth handheld printers do not have connected physical cash drawers
        if (kDebugMode) print('Bluetooth mode: No physical cash drawer connected.');
        return false;
      } else if (_connectionType == 'Network') {
        final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
        socket.add(PrinterBase.getDrawerKickBytes());
        await socket.flush();
        await socket.close();
        return true;
      } else {
        // Sunmi internal / None printer
        await PrinterBase.openSunmiDrawer();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Error opening cash drawer: $e');
      return false;
    }
  }
}
