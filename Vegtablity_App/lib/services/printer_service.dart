import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'api_service.dart';
import 'receipt_designer.dart';

import 'package:flutter/foundation.dart';

String _formatCurrency(double amount) {
  String s = amount.toStringAsFixed(2);
  final parts = s.split('.');
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String intPart = parts[0].replaceAllMapped(reg, (Match match) => '${match[1]},');
  return '$intPart.${parts[1]}';
}

String _formatQuantity(double qty, String unit) {
  String qStr;
  if (qty == qty.toInt()) {
    qStr = qty.toInt().toString();
  } else {
    qStr = qty.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
  return unit.isNotEmpty ? '$unit $qStr' : qStr;
}

class PrinterService with ChangeNotifier {
  final ApiService? _apiService;
  Map<String, dynamic>? _companySettings;

  String _connectionType = 'None'; // 'Network', 'Bluetooth', 'None'
  String _ipAddress = '192.168.1.100';
  int _port = 9100;
  String _bluetoothDevice = '';
  int _paperSize = 80; // 58 or 80
  bool _isSynced = false;

  String get connectionType => _connectionType;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get bluetoothDevice => _bluetoothDevice;
  int get paperSize => _paperSize;
  bool get isSynced => _isSynced;

  String get _separator {
    return _paperSize == 80
        ? '================================================'
        : '================================';
  }

  String get _dashedSeparator {
    return _paperSize == 80
        ? '------------------------------------------------'
        : '--------------------------------';
  }

  PrinterService([this._apiService]) {
    _loadSettings();
    _initSunmiPrinter();
    _loadCompanySettings();
  }

  Future<void> _loadCompanySettings() async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.getCompanySettings();
      if (response.statusCode == 200 && response.data != null) {
        _companySettings = Map<String, dynamic>.from(response.data);
        print('تم تحميل إعدادات الشركة بنجاح: $_companySettings');
        notifyListeners();
      }
    } catch (e) {
      print('خطأ في تحميل إعدادات الشركة: $e');
    }
  }

  String get _currencySymbol {
    final rawCurrency = _companySettings?['CurrencySymbol']?.toString() ?? '';
    if (rawCurrency.isEmpty) return ''; // if empty, just hide it
    if (rawCurrency.contains('/')) {
      return rawCurrency.split('/')[0].trim();
    }
    return rawCurrency.trim();
  }

  Future<void> _initSunmiPrinter() async {
    try {
      await SunmiPrinter.bindingPrinter();
    } catch (e) {
      print('خطأ في تهيئة طابعة Sunmi: $e');
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
      _isSynced = false;
      
      // 2. Fetch or generate MachineHWID
      String? hwid = prefs.getString('machine_hwid');
      if (hwid == null) {
        final random = Random();
        const chars = '0123456789ABCDEF';
        hwid = List.generate(16, (index) => chars[random.nextInt(16)]).join();
        await prefs.setString('machine_hwid', hwid);
      }
      
      // 3. Attempt to fetch settings from API
      if (_apiService != null) {
        try {
          final response = await _apiService!.getPrinterSettings(hwid);
          if (response.statusCode == 200 && response.data != null && response.data.isNotEmpty) {
            final data = response.data;
            _connectionType = data['ConnectionType'] ?? _connectionType;
            _ipAddress = data['IPAddress'] ?? _ipAddress;
            _port = data['Port'] ?? _port;
            _bluetoothDevice = data['BluetoothDevice'] ?? _bluetoothDevice;
            _isSynced = true;
            
            // Sync changes back to local SharedPreferences
            await prefs.setString('printer_connection_type', _connectionType);
            await prefs.setString('printer_ip', _ipAddress);
            await prefs.setInt('printer_port', _port);
            await prefs.setString('printer_bluetooth', _bluetoothDevice);
            
            print('تم تحميل ومزامنة إعدادات الطابعة من الخادم الخلفي بنجاح: $data');
          } else {
            print('لا توجد إعدادات طابعة محفوظة لهذا الجهاز على الخادم الخلفي.');
          }
        } catch (apiError) {
          print('تعذر جلب إعدادات الطابعة من الخادم الخلفي، جاري استخدام الكاش المحلي: $apiError');
        }
      }
      notifyListeners();
    } catch (e) {
      print('خطأ في تحميل إعدادات الطابعة: $e');
    }
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  Future<bool> saveSettings({
    required String connectionType,
    required String ipAddress,
    int port = 9100,
    required String bluetoothDevice,
    int paperSize = 80,
  }) async {
    try {
      _connectionType = connectionType;
      _ipAddress = ipAddress;
      _port = port;
      _bluetoothDevice = bluetoothDevice;
      _paperSize = paperSize;
      _isSynced = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_connection_type', connectionType);
      await prefs.setString('printer_ip', ipAddress);
      await prefs.setInt('printer_port', port);
      await prefs.setString('printer_bluetooth', bluetoothDevice);
      await prefs.setInt('printer_paper_size', paperSize);
      
      String? hwid = prefs.getString('machine_hwid');
      if (hwid == null) {
        final random = Random();
        const chars = '0123456789ABCDEF';
        hwid = List.generate(16, (index) => chars[random.nextInt(16)]).join();
        await prefs.setString('machine_hwid', hwid);
      }
      
      // Call API asynchronously to save to DB
      if (_apiService != null) {
        try {
          final response = await _apiService!.savePrinterSettings({
            'MachineHWID': hwid,
            'ConnectionType': connectionType,
            'IPAddress': ipAddress,
            'Port': port,
            'BluetoothDevice': bluetoothDevice,
          });
          if (response.statusCode == 200) {
            _isSynced = true;
            print('تم حفظ ومزامنة إعدادات الطابعة بنجاح في قاعدة البيانات.');
          }
        } catch (apiError) {
          print('فشل إرسال إعدادات الطابعة للخادم الخلفي، تم الحفظ محلياً فقط: $apiError');
        }
      }

      _initSunmiPrinter(); // Reinitialize
      notifyListeners();
      return true;
    } catch (e) {
      notifyListeners();
      return false;
    }
  }

  Future<bool> printReceipt(Map<String, dynamic> invoice) async {
    final prefs = await SharedPreferences.getInstance();
    final String? openWarehouseName = prefs.getString('selected_warehouse_name');

    try {
      // 1. Sunmi Internal Printer (Bluetooth or Simulator Fallback)
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        await ReceiptDesigner.printSunmiInvoice(
          invoice: invoice,
          companySettings: _companySettings,
          paperSize: _paperSize,
          openWarehouseName: openWarehouseName,
        );
      }

      // 2. Network (IP) Printer
      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          final List<int> printBytes = await ReceiptDesigner.buildNetworkInvoiceBytes(
            invoice: invoice,
            companySettings: _companySettings,
            paperSize: _paperSize,
            openWarehouseName: openWarehouseName,
          );
          socket.add(printBytes);
          await socket.flush();
          await socket.close();
        } catch (socketError) {
          print('خطأ أثناء الطباعة عبر الشبكة: $socketError');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('خطأ عام في طباعة الفاتورة: $e');
      return false;
    }
  }

  Future<bool> printTestReceipt() async {
    final mockInvoice = {
      'InvID': 1234,
      'PartnerName': 'شركة الضحي الزراعية (عرض تجريبي)',
      'type': 'Sales',
      'created_at': DateTime.now().toIso8601String(),
      'total_amount': 45.0,
      'items': [
        {'name': 'تفاح بلدي', 'price': 15.0, 'quantity': 2, 'total': 30.0},
        {'name': 'برتقال أبو صرة', 'price': 15.0, 'quantity': 1, 'total': 15.0},
      ]
    };
    return await printReceipt(mockInvoice);
  }

  /// طباعة تقرير اليومية الكاملة عند إغلاق الوردية
  Future<bool> printDailyReport({
    required Map<String, dynamic> summary,
    required List<dynamic> salesInvoices,
    required List<dynamic> purchaseInvoices,
    required double endingCash,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? openWarehouseName = prefs.getString('selected_warehouse_name');

    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address    = _companySettings?['Address'] ?? 'العارضيه';
    final String phone      = _companySettings?['Phone'] ?? '55381505';

    // وقت الطباعة الفعلي
    final now = DateTime.now();
    final List<String> arDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    String _fmtDT(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    final String printTimestamp = '${arDays[now.weekday - 1]}  ${_fmtDT(now)}';

    // بيانات الوردية
    final String userName = summary['UserName'] ?? '';
    DateTime? shiftStart;
    DateTime? shiftEnd;
    try { shiftStart = DateTime.parse(summary['StartTime'].toString()).toLocal(); } catch (_) {}
    try { shiftEnd   = DateTime.parse(summary['EndTime'].toString()).toLocal(); } catch (_) {}

    final String startStr = shiftStart != null ? _fmtDT(shiftStart) : '--';
    final String endStr   = shiftEnd   != null ? _fmtDT(shiftEnd)   : _fmtDT(now);

    double _parseD(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int _parseI(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    final double startingCash           = _parseD(summary['StartingCash']);
    final double totalSales             = _parseD(summary['TotalSales']);
    final double totalPurchases         = _parseD(summary['TotalPurchases']);
    final int    salesCount             = _parseI(summary['SalesCount']);
    final int    purchasesCount         = _parseI(summary['PurchasesCount']);
    final double totalPaid              = _parseD(summary['TotalPaidSales']);
    final double totalRemainder         = _parseD(summary['TotalRemainder']);
    final double totalPaidPurchases     = _parseD(summary['TotalPaidPurchases']);
    final double totalPurchasesRemainder= _parseD(summary['TotalPurchasesRemainder']);
    final double totalReceiptVouchers   = _parseD(summary['TotalReceiptVouchers']);
    final double totalPaymentVouchers   = _parseD(summary['TotalPaymentVouchers']);

    // الصافي = مبلغ بداية الوردية - مشتريات مدفوعة فقط + مبيعات محصلة فقط + سندات قبض - سندات صرف
    final double netCash    = startingCash - totalPaidPurchases + totalPaid + totalReceiptVouchers - totalPaymentVouchers;
    final double difference = endingCash - netCash;
    final String diffLabel  = difference >= 0 ? 'فائض (زيادة)' : 'عجز (نقص)';

    String _fmt(double v) => _formatCurrency(v);

    Future<void> _printLine(String text, {bool bold = false, bool center = false}) async {
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        await SunmiPrinter.printText(
          text,
          style: SunmiTextStyle(
            bold: bold,
            align: center ? SunmiPrintAlign.CENTER : SunmiPrintAlign.RIGHT,
          ),
        );
      }
    }

    try {
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        final String? logoBase64 = _companySettings?['Logo'];
        if (logoBase64 != null && logoBase64.isNotEmpty) {
          try {
            final Uint8List logoBytes = base64Decode(logoBase64);
            await SunmiPrinter.printImage(logoBytes, align: SunmiPrintAlign.CENTER);
            await SunmiPrinter.printText(' ');
          } catch (e) {
            print('Error printing Sunmi logo in shift summary: $e');
          }
        }

        // ── الرأس ──────────────────────────────────────────
        await _printLine('================================', center: true);
        await _printLine(companyName, bold: true, center: true);
        await _printLine('العنوان: $address', center: true);
        await _printLine('الهاتف: $phone', center: true);
        await _printLine('================================', center: true);
        await _printLine('تقرير إغلاق الوردية', bold: true, center: true);
        if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
          await _printLine('المستودع: $openWarehouseName', center: true);
        }
        await _printLine('--------------------------------');
        await _printLine('الكاشير: $userName');
        await _printLine('بداية الوردية: $startStr');
        await _printLine('نهاية الوردية: $endStr');
        await _printLine('--------------------------------');

        // ── ملخص المبيعات ──────────────────────────────────
        await _printLine('مبيعات الوردية ($salesCount فاتورة)', bold: true);
        await _printLine('إجمالي المبيعات: ${_fmt(totalSales)} ${_currencySymbol}');
        await _printLine('مُسدَّد نقداً:   ${_fmt(totalPaid)} ${_currencySymbol}');
        await _printLine('آجل متبقي:       ${_fmt(totalRemainder)} ${_currencySymbol}');
        await _printLine('--------------------------------');

        // ── ملخص المشتريات ─────────────────────────────────
        await _printLine('مشتريات الوردية ($purchasesCount فاتورة)', bold: true);
        await _printLine('إجمالي المشتريات: ${_fmt(totalPurchases)} ${_currencySymbol}');
        await _printLine('مُسدَّد نقداً:    ${_fmt(totalPaidPurchases)} ${_currencySymbol}');
        await _printLine('آجل متبقي:        ${_fmt(totalPurchasesRemainder)} ${_currencySymbol}');
        await _printLine('--------------------------------');

        // ── تفاصيل المبيعات ────────────────────────────────
        if (salesInvoices.isNotEmpty) {
          await _printLine('تفاصيل المبيعات:', bold: true);
          for (final inv in salesInvoices) {
            final id      = inv['InvID']?.toString() ?? '-';
            final partner = inv['PartnerName'] ?? 'عميل نقدي';
            final net     = _fmt(_parseD(inv['NetAmount']));
            await _printLine('#$id  $partner  $net ${_currencySymbol}');
          }
          await _printLine('--------------------------------');
        }

        // ── تفاصيل المشتريات ───────────────────────────────
        if (purchaseInvoices.isNotEmpty) {
          await _printLine('تفاصيل المشتريات:', bold: true);
          for (final inv in purchaseInvoices) {
            final id      = inv['InvID']?.toString() ?? '-';
            final partner = inv['PartnerName'] ?? 'مورد نقدي';
            final net     = _fmt(_parseD(inv['NetAmount']));
            await _printLine('#$id  $partner  $net ${_currencySymbol}');
          }
          await _printLine('--------------------------------');
        }

        // ── تفاصيل السندات ────────────────────────────────
        final vouchers = summary['Vouchers'] as List<dynamic>? ?? [];
        if (vouchers.isNotEmpty) {
          await _printLine('تفاصيل السندات:', bold: true);
          for (final v in vouchers) {
            final id      = v['VoucherID']?.toString() ?? '-';
            final vType   = v['VoucherType'] == 'Receipt' ? 'قبض' : 'صرف';
            final partner = v['PartnerName'] ?? 'بدون شريك';
            final amt     = _fmt(_parseD(v['Amount']));
            await _printLine('#$id $vType - $partner');
            await _printLine('المبلغ: $amt ${_currencySymbol}');
          }
          await _printLine('--------------------------------');
        }

        // ── بيان النقدية ────────────────────────────────────
        await _printLine('*** بيان النقدية ***', bold: true, center: true);
        await _printLine('--------------------------------');
        await _printLine('مبلغ بدايه الورديه: ${_fmt(startingCash)} ${_currencySymbol}');
        await _printLine('- مشتريات مدفوعه:   ${_fmt(totalPaidPurchases)} ${_currencySymbol}');
        await _printLine('+ مبيعات محصله:     ${_fmt(totalPaid)} ${_currencySymbol}');
        if (totalReceiptVouchers > 0) {
          await _printLine('+ سندات قبض:        ${_fmt(totalReceiptVouchers)} ${_currencySymbol}');
        }
        if (totalPaymentVouchers > 0) {
          await _printLine('- سندات صرف:        ${_fmt(totalPaymentVouchers)} ${_currencySymbol}');
        }
        await _printLine('================================', center: true);
        await _printLine('الصافي المتوقع:     ${_fmt(netCash)} ${_currencySymbol}', bold: true);
        await _printLine('المسدد الفعلي:      ${_fmt(endingCash)} ${_currencySymbol}', bold: true);
        await _printLine('--------------------------------');
        await _printLine(
          '$diffLabel: ${_fmt(difference.abs())} ${_currencySymbol}',
          bold: true,
        );
        await _printLine('================================', center: true);

        // ── التذييل ─────────────────────────────────────────
        await _printLine('طُبع بتاريخ:', center: true);
        await _printLine(printTimestamp, center: true);
        await _printLine('================================', center: true);

        await SunmiPrinter.lineWrap(5);
        await SunmiPrinter.cutPaper();
      }

      // ── طابعة شبكة (Network) ────────────────────────────
      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add([0x1B, 0x40]);

          final String? logoBase64 = _companySettings?['Logo'];
          if (logoBase64 != null && logoBase64.isNotEmpty) {
            final int targetWidth = _paperSize == 80 ? 300 : 200;
            final List<int> logoBytes = await ReceiptDesigner.convertImageToEscPos(logoBase64, targetWidth: targetWidth);
            if (logoBytes.isNotEmpty) {
              socket.add([0x1B, 0x61, 0x01]);
              socket.add(logoBytes);
              socket.write('\n');
            }
          }

          // Center
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  تقرير إغلاق الوردية\n');
          if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
            socket.write('  المستودع: $openWarehouseName\n');
          }
          socket.write('================================\n');
          // Right
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('الكاشير: $userName\n');
          socket.write('بداية الوردية: $startStr\n');
          socket.write('نهاية الوردية: $endStr\n');
          socket.write('--------------------------------\n');
          socket.write('إجمالي المبيعات ($salesCount): ${_fmt(totalSales)} ${_currencySymbol}\n');
          socket.write('مُسدَّد: ${_fmt(totalPaid)} ${_currencySymbol}\n');
          socket.write('آجل متبقي: ${_fmt(totalRemainder)} ${_currencySymbol}\n');
          socket.write('إجمالي المشتريات ($purchasesCount): ${_fmt(totalPurchases)} ${_currencySymbol}\n');
          socket.write('مُسدَّد مشتريات: ${_fmt(totalPaidPurchases)} ${_currencySymbol}\n');
          socket.write('آجل مشتريات: ${_fmt(totalPurchasesRemainder)} ${_currencySymbol}\n');
          socket.write('--------------------------------\n');
          final netVouchers = summary['Vouchers'] as List<dynamic>? ?? [];
          if (netVouchers.isNotEmpty) {
            socket.write('تفاصيل السندات:\n');
            for (final v in netVouchers) {
              final id      = v['VoucherID']?.toString() ?? '-';
              final vType   = v['VoucherType'] == 'Receipt' ? 'قبض' : 'صرف';
              final partner = v['PartnerName'] ?? 'بدون شريك';
              final amt     = _fmt(_parseD(v['Amount']));
              socket.write('#$id $vType - $partner : $amt ${_currencySymbol}\n');
            }
          }
          socket.write('================================\n');
          socket.write('*** بيان النقدية ***\n');
          socket.write('مبلغ بدايه الورديه: ${_fmt(startingCash)} ${_currencySymbol}\n');
          socket.write('- مشتريات مدفوعه:   ${_fmt(totalPaidPurchases)} ${_currencySymbol}\n');
          socket.write('+ مبيعات محصله:     ${_fmt(totalPaid)} ${_currencySymbol}\n');
          if (totalReceiptVouchers > 0) {
            socket.write('+ سندات قبض:        ${_fmt(totalReceiptVouchers)} ${_currencySymbol}\n');
          }
          if (totalPaymentVouchers > 0) {
            socket.write('- سندات صرف:        ${_fmt(totalPaymentVouchers)} ${_currencySymbol}\n');
          }
          socket.write('الصافي المتوقع:     ${_fmt(netCash)} ${_currencySymbol}\n');
          socket.write('المسدد الفعلي:      ${_fmt(endingCash)} ${_currencySymbol}\n');
          socket.write('$diffLabel: ${_fmt(difference.abs())} ${_currencySymbol}\n');
          socket.write('================================\n');
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('طُبع: $printTimestamp\n');
          socket.write('================================\n');
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          await socket.flush();
          await socket.close();
        } catch (e) {
          print('خطأ أثناء طباعة تقرير اليومية عبر الشبكة: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('خطأ في طباعة تقرير الوردية: $e');
      return false;
    }
  }

  Future<bool> printVoucher(Map<String, dynamic> voucher, List<Map<String, dynamic>> paidInvoices) async {
    final bool isVirtual = _connectionType == 'None';
    final String actualConnectionType = isVirtual ? 'Virtual Printer (Console Simulator)' : _connectionType;

    final prefs = await SharedPreferences.getInstance();
    final String? openWarehouseName = prefs.getString('selected_warehouse_name');

    // Get company settings
    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = _companySettings?['Address'] ?? 'العارضيه';
    final String phone = _companySettings?['Phone'] ?? '55381505';

    final String vType = voucher['VoucherType'] == 'Receipt' ? 'سند قبض' : 'سند صرف';
    final String vId = '${voucher['VoucherID'] ?? ''}';
    final String partnerName = voucher['PartnerName'] ?? '-';
    final String accountName = voucher['AccountName'] ?? 'نقدي';
    final double amount = (voucher['Amount'] as num?)?.toDouble() ?? 0.0;
    
    DateTime printDateTime;
    try {
      printDateTime = voucher['VoucherDate'] != null ? DateTime.parse(voucher['VoucherDate']) : DateTime.now();
    } catch (_) {
      printDateTime = DateTime.now();
    }
    final String vDate = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
    final String vTime = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}';
    
    final String cashier = voucher['UserName'] ?? '-';

    try {
      
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        final String? logoBase64 = _companySettings?['Logo'];
        if (logoBase64 != null && logoBase64.isNotEmpty) {
          try {
            final Uint8List logoBytes = base64Decode(logoBase64);
            await SunmiPrinter.printImage(logoBytes, align: SunmiPrintAlign.CENTER);
            await SunmiPrinter.printText(' ');
          } catch (e) {
            print('Error printing Sunmi logo in voucher: $e');
          }
        }
        // Sunmi Print
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText(vType, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
          await SunmiPrinter.printText('المستودع: $openWarehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        }
        await SunmiPrinter.printText('رقم السند: #$vId', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('التاريخ: $vDate $vTime', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الاسم (الشريك): $partnerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('طريقة الدفع/الاستلام: $accountName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('المبلغ: ${_formatCurrency(amount)} ${_currencySymbol}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('الفواتير المسددة:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var inv in paidInvoices) {
          final id = inv['InvID'] ?? '';
          String date = '';
          if (inv['InvDate'] != null) {
             try {
               final d = DateTime.parse(inv['InvDate'].toString());
               date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
             } catch(_) {
               date = inv['InvDate'].toString().substring(0, 10);
             }
          }
          final payAmount = _formatCurrency((inv['Amount'] as num).toDouble());
          
          await SunmiPrinter.printText('فاتورة #$id ($date)', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
          await SunmiPrinter.printText('المسدد: $payAmount ${_currencySymbol}', style: SunmiTextStyle(align: SunmiPrintAlign.LEFT));
        }

        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الكاشير: $cashier', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.lineWrap(3);
      }
      
      // ── طابعة شبكة (Network) ────────────────────────────
      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add([0x1B, 0x40]);

          final String? logoBase64 = _companySettings?['Logo'];
          if (logoBase64 != null && logoBase64.isNotEmpty) {
            final int targetWidth = _paperSize == 80 ? 300 : 200;
            final List<int> logoBytes = await ReceiptDesigner.convertImageToEscPos(logoBase64, targetWidth: targetWidth);
            if (logoBytes.isNotEmpty) {
              socket.add([0x1B, 0x61, 0x01]);
              socket.add(logoBytes);
              socket.write('\n');
            }
          }

          // Center
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  $vType\n');
          if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
            socket.write('  المستودع: $openWarehouseName\n');
          }
          socket.write('رقم السند: #$vId\n');
          socket.write('التاريخ: $vDate $vTime\n');
          socket.write('--------------------------------\n');
          // Right
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('الاسم (الشريك): $partnerName\n');
          socket.write('طريقة الدفع/الاستلام: $accountName\n');
          socket.write('المبلغ: ${_formatCurrency(amount)} ${_currencySymbol}\n');
          socket.write('--------------------------------\n');
          socket.write('الفواتير المسددة:\n');
          
          for (var inv in paidInvoices) {
            final id = inv['InvID'] ?? '';
            String date = '';
            if (inv['InvDate'] != null) {
               try {
                 final d = DateTime.parse(inv['InvDate'].toString());
                 date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
               } catch(_) {
                 date = inv['InvDate'].toString().substring(0, 10);
               }
            }
            final payAmount = _formatCurrency((inv['Amount'] as num).toDouble());
            socket.write('فاتورة #$id ($date)\n');
            socket.write('المسدد: $payAmount ${_currencySymbol}\n');
          }
          
          socket.write('================================\n');
          socket.write('الكاشير: $cashier\n');
          socket.write('================================\n');
          // Cut paper
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          
          await socket.flush();
          await socket.close();
        } catch (e) {
          print('خطأ أثناء طباعة السند عبر الشبكة: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('خطأ في طباعة السند: $e');
      return false;
    }
  }

  Future<bool> printGeneralVoucher(Map<String, dynamic> voucher, String targetAccountName, String cashAccountName) async {
    final prefs = await SharedPreferences.getInstance();
    final String? openWarehouseName = prefs.getString('selected_warehouse_name');

    // Get company settings
    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = _companySettings?['Address'] ?? 'العارضيه';
    final String phone = _companySettings?['Phone'] ?? '55381505';

    final bool isReceipt = voucher['VoucherType'] == 'Receipt';
    final String vType = isReceipt ? 'سند قبض عام' : 'سند صرف عام';
    final String targetLabel = isReceipt ? 'الإيراد' : 'المصروف';
    final String vId = '${voucher['VoucherID'] ?? voucher['VoucherNo'] ?? ''}';
    
    final double amount = (voucher['Amount'] as num?)?.toDouble() ?? 0.0;
    final String description = voucher['Description'] ?? '-';
    
    DateTime printDateTime;
    try {
      printDateTime = voucher['VoucherDate'] != null ? DateTime.parse(voucher['VoucherDate']) : DateTime.now();
    } catch (_) {
      printDateTime = DateTime.now();
    }
    final String vDate = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
    final String vTime = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}';

    try {
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        await SunmiPrinter.initPrinter(); // Ensure printer is ready
        final String? logoBase64 = _companySettings?['Logo'];
        if (logoBase64 != null && logoBase64.isNotEmpty) {
          try {
            final Uint8List logoBytes = base64Decode(logoBase64);
            await SunmiPrinter.printImage(logoBytes, align: SunmiPrintAlign.CENTER);
            await SunmiPrinter.printText(' ');
          } catch (e) {
            print('Error printing Sunmi logo in general voucher: $e');
          }
        }
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText(vType, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
          await SunmiPrinter.printText('المستودع: $openWarehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        }
        await SunmiPrinter.printText('رقم السند: #$vId', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('التاريخ: $vDate $vTime', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('$targetLabel: $targetAccountName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        await SunmiPrinter.printText('طريقة الدفع: $cashAccountName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('المبلغ: ${_formatCurrency(amount)} ${_currencySymbol}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        await SunmiPrinter.printText('البيان: $description', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('توقيع المستلم:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.lineWrap(2);
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('طُبع عبر نظام POS', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.lineWrap(4);
        await SunmiPrinter.cutPaper();
      }
      
      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add([0x1B, 0x40]);

          final String? logoBase64 = _companySettings?['Logo'];
          if (logoBase64 != null && logoBase64.isNotEmpty) {
            final int targetWidth = _paperSize == 80 ? 300 : 200;
            final List<int> logoBytes = await ReceiptDesigner.convertImageToEscPos(logoBase64, targetWidth: targetWidth);
            if (logoBytes.isNotEmpty) {
              socket.add([0x1B, 0x61, 0x01]);
              socket.add(logoBytes);
              socket.write('\n');
            }
          }

          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  $vType\n');
          if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
            socket.write('  المستودع: $openWarehouseName\n');
          }
          socket.write('رقم السند: #$vId\n');
          socket.write('التاريخ: $vDate $vTime\n');
          socket.write('--------------------------------\n');
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('$targetLabel: $targetAccountName\n');
          socket.write('طريقة الدفع: $cashAccountName\n');
          socket.write('المبلغ: ${_formatCurrency(amount)} ${_currencySymbol}\n');
          socket.write('البيان: $description\n');
          socket.write('--------------------------------\n');
          socket.write('================================\n');
          socket.write('توقيع المستلم:\n\n\n');
          socket.write('================================\n');
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('طُبع عبر نظام POS\n');
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          await socket.flush();
          await socket.close();
        } catch (e) {
          print('خطأ أثناء طباعة السند عبر الشبكة: $e');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('خطأ في طباعة السند: $e');
      return false;
    }
  }

  /// طباعة مسودة إهلاك بضاعة (الهالك)
  Future<bool> printWastageReceipt(Map<String, dynamic> data) async {
    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = _companySettings?['Address'] ?? 'العارضيه';
    final String phone = _companySettings?['Phone'] ?? '55381505';

    final int id = data['WastageID'] ?? 0;
    final String idStr = id != 0 ? '#$id' : 'مسودة جديدة';
    final String warehouseName = data['WarehouseName'] ?? 'المستودع الرئيسي';
    final double totalValue = (data['TotalValue'] as num?)?.toDouble() ?? 0.0;
    final String notes = data['Notes'] ?? '';

    DateTime printDateTime;
    try {
      printDateTime = data['WastageDate'] != null ? DateTime.parse(data['WastageDate']) : DateTime.now();
    } catch (_) {
      printDateTime = DateTime.now();
    }

    final String dateStr = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
    final String timeStr = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}';

    final items = data['items'] as List<dynamic>? ?? [];

    try {
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('مسودة إهلاك بضاعة (هالك)', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('المستند: $idStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('المستودع: $warehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('التاريخ: $dateStr $timeStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        for (final item in items) {
          final String name = item['ProductName'] ?? 'صنف غير معروف';
          final double qty = (item['Quantity'] as num).toDouble();
          final double price = (item['CostPrice'] as num).toDouble();
          final double total = qty * price;
          final String unit = item['UnitName'] ?? 'حبه';
          
          await SunmiPrinter.printText(name, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
          await SunmiPrinter.printText('  ${_formatQuantity(qty, unit)} x ${_formatCurrency(price)} = ${_formatCurrency(total)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('إجمالي التكلفة: ${_formatCurrency(totalValue)} ${_currencySymbol}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        if (notes.isNotEmpty) {
          await SunmiPrinter.printText('ملاحظات: $notes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('حالة المستند: مسودة غير مرحلة', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.lineWrap(4);
        await SunmiPrinter.cutPaper();
      }

      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add([0x1B, 0x40]);
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  مسودة إهلاك بضاعة (هالك)\n');
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('المستند: $idStr\n');
          socket.write('المستودع: $warehouseName\n');
          socket.write('التاريخ: $dateStr $timeStr\n');
          socket.write('--------------------------------\n');
          for (final item in items) {
            final String name = item['ProductName'] ?? 'صنف غير معروف';
            final double qty = (item['Quantity'] as num).toDouble();
            final double price = (item['CostPrice'] as num).toDouble();
            final double total = qty * price;
            final String unit = item['UnitName'] ?? 'حبه';
            socket.write('$name\n');
            socket.write('  ${_formatQuantity(qty, unit)} x ${_formatCurrency(price)} = ${_formatCurrency(total)}\n');
          }
          socket.write('--------------------------------\n');
          socket.write('إجمالي التكلفة: ${_formatCurrency(totalValue)} ${_currencySymbol}\n');
          if (notes.isNotEmpty) {
            socket.write('ملاحظات: $notes\n');
          }
          socket.write('================================\n');
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('حالة المستند: مسودة غير مرحلة\n');
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          await socket.flush();
          await socket.close();
        } catch (_) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// طباعة مسودة جرد مخزني
  Future<bool> printStockTakeReceipt(Map<String, dynamic> data) async {
    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = _companySettings?['Address'] ?? 'العارضيه';
    final String phone = _companySettings?['Phone'] ?? '55381505';

    final int id = data['StockTakeID'] ?? 0;
    final String idStr = id != 0 ? '#$id' : 'مسودة جديدة';
    final String warehouseName = data['WarehouseName'] ?? 'المستودع الرئيسي';
    final double totalDiff = (data['TotalDifferenceValue'] as num?)?.toDouble() ?? 0.0;
    final String notes = data['Notes'] ?? '';

    DateTime printDateTime;
    try {
      printDateTime = data['StockTakeDate'] != null ? DateTime.parse(data['StockTakeDate']) : DateTime.now();
    } catch (_) {
      printDateTime = DateTime.now();
    }

    final String dateStr = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
    final String timeStr = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}';

    final items = data['items'] as List<dynamic>? ?? [];

    try {
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText('مسودة جرد مخزني', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('مستند الجرد: $idStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('المستودع: $warehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('التاريخ: $dateStr $timeStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        for (final item in items) {
          final String name = item['ProductName'] ?? 'صنف غير معروف';
          final double sysQty = (item['SystemQuantity'] as num).toDouble();
          final double actQty = (item['ActualQuantity'] as num).toDouble();
          final double diffQty = (item['DifferenceQuantity'] as num).toDouble();
          final double diffVal = (item['DifferenceValue'] as num).toDouble();
          final String unit = item['UnitName'] ?? 'حبه';
          
          await SunmiPrinter.printText(name, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
          await SunmiPrinter.printText('  الدفترية: ${sysQty.toStringAsFixed(2)} | الفعلية: ${actQty.toStringAsFixed(2)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
          await SunmiPrinter.printText('  الفرق: ${diffQty.toStringAsFixed(2)} $unit (قيمة: ${_formatCurrency(diffVal)})', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        
        await SunmiPrinter.printText('--------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('إجمالي قيمة الفرق: ${_formatCurrency(totalDiff)} ${_currencySymbol}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        if (notes.isNotEmpty) {
          await SunmiPrinter.printText('ملاحظات: $notes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('حالة الجرد: مسودة معلقة للاعتماد', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.lineWrap(4);
        await SunmiPrinter.cutPaper();
      }

      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          socket.add([0x1B, 0x40]);
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  مسودة جرد مخزني\n');
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('مستند الجرد: $idStr\n');
          socket.write('المستودع: $warehouseName\n');
          socket.write('التاريخ: $dateStr $timeStr\n');
          socket.write('--------------------------------\n');
          for (final item in items) {
            final String name = item['ProductName'] ?? 'صنف غير معروف';
            final double sysQty = (item['SystemQuantity'] as num).toDouble();
            final double actQty = (item['ActualQuantity'] as num).toDouble();
            final double diffQty = (item['DifferenceQuantity'] as num).toDouble();
            final double diffVal = (item['DifferenceValue'] as num).toDouble();
            final String unit = item['UnitName'] ?? 'حبه';
            socket.write('$name\n');
            socket.write('  الدفترية: ${sysQty.toStringAsFixed(2)} | الفعلية: ${actQty.toStringAsFixed(2)}\n');
            socket.write('  الفرق: ${diffQty.toStringAsFixed(2)} $unit (قيمة: ${_formatCurrency(diffVal)})\n');
          }
          socket.write('--------------------------------\n');
          socket.write('إجمالي قيمة الفرق: ${_formatCurrency(totalDiff)} ${_currencySymbol}\n');
          if (notes.isNotEmpty) {
            socket.write('ملاحظات: $notes\n');
          }
          socket.write('================================\n');
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('حالة الجرد: مسودة معلقة للاعتماد\n');
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          await socket.flush();
          await socket.close();
        } catch (_) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

