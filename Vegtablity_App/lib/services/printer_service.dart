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
  bool _isSynced = false;

  String get connectionType => _connectionType;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get bluetoothDevice => _bluetoothDevice;
  int get paperSize => _paperSize;
  String get networkPrintMode => _networkPrintMode;
  bool get isSynced => _isSynced;
  Map<String, dynamic>? get companySettings => _companySettings;

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

      _connectionType = prefs.getString('printer_connection_type') ?? 'None';
      _ipAddress = prefs.getString('printer_ip') ?? '192.168.1.100';
      _port = prefs.getInt('printer_port') ?? 9100;
      _bluetoothDevice = prefs.getString('printer_bluetooth') ?? '';
      _paperSize = prefs.getInt('printer_paper_size') ?? 80;
      _networkPrintMode = prefs.getString('printer_network_mode') ?? 'direct';
      _isSynced = false;

      String? hwid = prefs.getString('machine_hwid');
      if (hwid == null || hwid.isEmpty) {
        hwid = 'HWID_' + DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('machine_hwid', hwid);
      }

      if (_apiService != null) {
        try {
          final response = await _apiService!.getPrinterSettings(hwid);
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            _connectionType = data['ConnectionType'] ?? _connectionType;
            _ipAddress = data['IpAddress'] ?? _ipAddress;
            _port = data['Port'] != null ? int.parse(data['Port'].toString()) : _port;
            _bluetoothDevice = data['BluetoothDevice'] ?? _bluetoothDevice;
            _paperSize = data['PaperSize'] != null ? int.parse(data['PaperSize'].toString()) : _paperSize;
            _networkPrintMode = data['NetworkPrintMode'] ?? _networkPrintMode;
            _isSynced = true;

            await prefs.setString('printer_connection_type', _connectionType);
            await prefs.setString('printer_ip', _ipAddress);
            await prefs.setInt('printer_port', _port);
            await prefs.setString('printer_bluetooth', _bluetoothDevice);
            await prefs.setInt('printer_paper_size', _paperSize);
            await prefs.setString('printer_network_mode', _networkPrintMode);
          }
        } catch (apiError) {
          if (kDebugMode) print('Could not sync printer settings from server: $apiError');
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading printer settings: $e');
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
  }) async {
    try {
      _connectionType = connectionType;
      _ipAddress = ipAddress;
      _port = port;
      _bluetoothDevice = bluetoothDevice;
      _paperSize = paperSize;
      _networkPrintMode = networkPrintMode;
      _isSynced = false;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_connection_type', connectionType);
      await prefs.setString('printer_ip', ipAddress);
      await prefs.setInt('printer_port', port);
      await prefs.setString('printer_bluetooth', bluetoothDevice);
      await prefs.setInt('printer_paper_size', paperSize);
      await prefs.setString('printer_network_mode', networkPrintMode);

      String? hwid = prefs.getString('machine_hwid');

      if (_apiService != null && hwid != null) {
        try {
          final response = await _apiService!.savePrinterSettings({
            'MachineHWID': hwid,
            'ConnectionType': connectionType,
            'IpAddress': ipAddress,
            'Port': port,
            'BluetoothDevice': bluetoothDevice,
            'PaperSize': paperSize,
            'NetworkPrintMode': networkPrintMode,
          });

          if (response.statusCode == 200) {
            _isSynced = true;
            notifyListeners();
          }
        } catch (apiError) {
          if (kDebugMode) print('Error saving printer settings to server: $apiError');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error saving printer settings locally: $e');
      return false;
    }
  }

  // =========================================================================
  // 1. PRINT SALES/PURCHASE INVOICE (طباعة فواتير المبيعات والمشتريات)
  // =========================================================================

  Future<bool> printReceipt(Map<String, dynamic> invoice, {bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
    return await printReceipt(testInvoice, isArabic: isArabic);
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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printDailyReport: $e');
      return false;
    }
  }

  // =========================================================================
  // 4. PRINT RECIPE RECEIPT (طباعة وصفات التصنيع والمنتجات)
  // =========================================================================

  Future<bool> printRecipe(Map<String, dynamic> recipe, {Map<String, dynamic>? companySettings, bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final settings = companySettings ?? _companySettings;
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printRecipe: $e');
      return false;
    }
  }

  // =========================================================================
  // 5. PRINT RECEIPT & PAYMENT VOUCHER (طباعة سندات القبض والصرف)
  // =========================================================================

  Future<bool> printVoucher(Map<String, dynamic> voucher, List<Map<String, dynamic>> paidInvoices, {bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printVoucher: $e');
      return false;
    }
  }

  // =========================================================================
  // 6. PRINT GENERAL VOUCHER (طباعة السندات العامة)
  // =========================================================================

  Future<bool> printGeneralVoucher(Map<String, dynamic> voucher, String targetAccountName, String cashAccountName, {bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printGeneralVoucher: $e');
      return false;
    }
  }

  // =========================================================================
  // 7. PRINT WASTAGE RECEIPT (طباعة إيصالات التالف)
  // =========================================================================

  Future<bool> printWastageReceipt(Map<String, dynamic> data, {bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printWastageReceipt: $e');
      return false;
    }
  }

  // =========================================================================
  // 8. PRINT STOCK TAKE RECEIPT (طباعة إيصالات جرد المخزون)
  // =========================================================================

  Future<bool> printStockTakeReceipt(Map<String, dynamic> data, {bool? isArabic}) async {
    try {
      if (_companySettings == null) await _loadCompanySettings();
      final prefs = await SharedPreferences.getInstance();
      final String? openWarehouseName = prefs.getString('selected_warehouse_name');
      final String langCode = prefs.getString('app_language_code') ?? 'ar';
      final bool arabic = isArabic ?? (langCode == 'ar');

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
      return true;
    } catch (e) {
      if (kDebugMode) print('Error in printStockTakeReceipt: $e');
      return false;
    }
  }


  // =========================================================================
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
