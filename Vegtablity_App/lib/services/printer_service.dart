import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'api_service.dart';

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
  bool _isSynced = false;

  String get connectionType => _connectionType;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get bluetoothDevice => _bluetoothDevice;
  bool get isSynced => _isSynced;

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
      
      // 1. Load local settings as immediate fallback
      _connectionType = prefs.getString('printer_connection_type') ?? 'None';
      _ipAddress = prefs.getString('printer_ip') ?? '192.168.1.100';
      _port = prefs.getInt('printer_port') ?? 9100;
      _bluetoothDevice = prefs.getString('printer_bluetooth') ?? '';
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
  }) async {
    try {
      _connectionType = connectionType;
      _ipAddress = ipAddress;
      _port = port;
      _bluetoothDevice = bluetoothDevice;
      _isSynced = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_connection_type', connectionType);
      await prefs.setString('printer_ip', ipAddress);
      await prefs.setInt('printer_port', port);
      await prefs.setString('printer_bluetooth', bluetoothDevice);
      
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
    final bool isVirtual = _connectionType == 'None';
    final String actualConnectionType = isVirtual ? 'Virtual Printer (Console Simulator)' : _connectionType;

    // Get company settings with default fallbacks
    final String companyName = _companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = _companySettings?['Address'] ?? 'العارضيه';
    final String phone = _companySettings?['Phone'] ?? '55381505';

    final String invType = invoice['type'] ?? 'Sales';
    final String typeName = (invType == 'Sales' || invType == 'Sale') ? 'مبيعات' : 'مشتريات';

    final int? invId = invoice['InvID'] ?? invoice['invoice_id'] ?? invoice['id'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : 'جديدة (غير محفوظة)';
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName == 'مبيعات' ? 'عميل نقدي' : 'مورد نقدي');

    final double totalAmount       = (invoice['total_amount']        as num?)?.toDouble() ?? 0.0;
    final double paidAtCreate       = (invoice['paid_amount']         as num?)?.toDouble() ?? 0.0;
    final double voucherPaidAmount  = (invoice['voucher_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double remainder          = (invoice['remainder']           as num?)?.toDouble() ?? 0.0;

    // إجمالي المسدّد = ما دُفع عند الإنشاء + ما سُدّد عبر سند لاحق
    final double totalPaid = paidAtCreate + voucherPaidAmount;

    // Custom formatting to 0,000.00
    final String formattedTotal     = _formatCurrency(totalAmount);
    final String formattedPaid      = _formatCurrency(totalPaid);
    final String formattedRemainder = _formatCurrency(remainder);
    // يظهر قسم السداد إذا كان المدفوع أقل من الإجمالي أو هناك متبقٍ
    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;
    // يظهر بند السند منفصلاً إذا كان هناك سداد عبر سند
    final bool hasVoucherPayment = voucherPaidAmount > 0.001;

    DateTime printDateTime;
    try {
      if (invoice['created_at'] != null) {
        printDateTime = DateTime.parse(invoice['created_at']);
      } else if (invoice['InvDate'] != null) {
        printDateTime = DateTime.parse(invoice['InvDate']);
      } else {
        printDateTime = DateTime.now();
      }
    } catch (_) {
      printDateTime = DateTime.now();
    }

    final String shortDate = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
    final String timeStr = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}:${printDateTime.second.toString().padLeft(2, '0')}';
    final List<String> arDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final String dayName = arDays[printDateTime.weekday - 1];

    try {
      // Formatted receipt content

      // 1. Physical Printing for Sunmi Built-in Printer (Bluetooth or Simulator Fallback)
      // Since it's a Sunmi terminal, we can attempt to print directly
      if (_connectionType == 'Bluetooth' || _connectionType == 'None') {
        try {
          // Print Header (Centered)
          await SunmiPrinter.printText(
            '================================',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          await SunmiPrinter.printText(
            companyName,
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
          );
          await SunmiPrinter.printText(
            'العنوان: $address',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          await SunmiPrinter.printText(
            'الهاتف: $phone',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          await SunmiPrinter.printText(
            '================================',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          
          // Print Body (Right Aligned for Arabic)
          await SunmiPrinter.printText(
            'فاتورة $typeName جديدة',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
          );
          await SunmiPrinter.printText(
            'رقم الفاتورة: $invIdStr',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'الشريك: $partnerName',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'التاريخ: $shortDate',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'الوقت: $timeStr',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'اليوم: $dayName',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'نوع العملية: ${invoice['type']}',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            '--------------------------------',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          
          for (final item in items) {
            final String name = item['name'];
            final double price = (item['price'] as num).toDouble();
            final double qty = (item['quantity'] as num).toDouble();
            final double total = (item['total'] as num).toDouble();
            final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
            final String qtyFormatted = _formatQuantity(qty, unitName);
            
            await SunmiPrinter.printText(
              name,
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
            );
            await SunmiPrinter.printText(
              '  $qtyFormatted x ${_formatCurrency(price)} ${_currencySymbol} = ${_formatCurrency(total)} ${_currencySymbol}',
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
            );
          }
          
          await SunmiPrinter.printText(
            '--------------------------------',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'الإجمالي الكلي: $formattedTotal ${_currencySymbol}',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
          );
          if (hasSplitPayment) {
            if (hasVoucherPayment) {
              await SunmiPrinter.printText(
                'نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} ${_currencySymbol}',
                style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
              );
              await SunmiPrinter.printText(
                'عبر سند:          ${_formatCurrency(voucherPaidAmount)} ${_currencySymbol}',
                style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
              );
              await SunmiPrinter.printText(
                'إجمالي المدفوع:   $formattedPaid ${_currencySymbol}',
                style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
              );
            } else {
              await SunmiPrinter.printText(
                'المدفوع:          $formattedPaid ${_currencySymbol}',
                style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
              );
            }
            await SunmiPrinter.printText(
              'المتبقي آجل:     $formattedRemainder ${_currencySymbol}',
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
            );
          }
          await SunmiPrinter.printText(
            '================================',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          
          // Footer (Centered)
          await SunmiPrinter.printText(
            'شكراً لزيارتكم! طبعت عبر نظام POS',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          await SunmiPrinter.printText(
            '================================',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
          );
          
          // Feed paper and cut
          await SunmiPrinter.lineWrap(4);
          await SunmiPrinter.cutPaper();
        } catch (sunmiError) {
          print('خطأ أثناء الطباعة عبر طابعة Sunmi: $sunmiError');
          if (_connectionType == 'Bluetooth') {
            return false;
          }
        }
      }

      // 2. Physical Printing for Network (IP) Printer
      if (_connectionType == 'Network') {
        try {
          final socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
          
          // Initialize printer: ESC @ (0x1B, 0x40)
          socket.add([0x1B, 0x40]);
          
          // Header (Center aligned)
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('   $companyName\n');
          socket.write('   العنوان: $address\n');
          socket.write('   الهاتف: $phone\n');
          socket.write('================================\n');
          
          // Body (Right aligned)
          socket.add([0x1B, 0x61, 0x02]);
          socket.write('فاتورة $typeName جديدة\n');
          socket.write('رقم الفاتورة: $invIdStr\n');
          socket.write('الشريك: $partnerName\n');
          socket.write('التاريخ: $shortDate\n');
          socket.write('الوقت: $timeStr\n');
          socket.write('اليوم: $dayName\n');
          socket.write('نوع العملية: ${invoice['type']}\n');
          socket.write('--------------------------------\n');
          
          for (final item in items) {
            final String name = item['name'];
            final double price = (item['price'] as num).toDouble();
            final double qty = (item['quantity'] as num).toDouble();
            final double total = (item['total'] as num).toDouble();
            final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
            final String qtyFormatted = _formatQuantity(qty, unitName);
            
            socket.write('$name\n');
            socket.write('  $qtyFormatted x ${_formatCurrency(price)} ${_currencySymbol} = ${_formatCurrency(total)} ${_currencySymbol}\n');
          }
          
          socket.write('--------------------------------\n');
          socket.write('الإجمالي الكلي: $formattedTotal ${_currencySymbol}\n');
          if (hasSplitPayment) {
            if (hasVoucherPayment) {
              socket.write('نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} ${_currencySymbol}\n');
              socket.write('عبر سند:         ${_formatCurrency(voucherPaidAmount)} ${_currencySymbol}\n');
              socket.write('إجمالي المدفوع:  $formattedPaid ${_currencySymbol}\n');
            } else {
              socket.write('المدفوع:         $formattedPaid ${_currencySymbol}\n');
            }
            socket.write('المتبقي آجل:     $formattedRemainder ${_currencySymbol}\n');
          }
          socket.write('================================\n');
          
          // Footer (Center aligned)
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('شكراً لزيارتكم! طبعت عبر نظام POS\n');
          socket.write('================================\n');
          
          // Feed paper and cut (GS V 66 0)
          socket.add([0x1D, 0x56, 0x42, 0x00]);
          
          await socket.flush();
          await socket.close();
        } catch (socketError) {
          print('خطأ أثناء الطباعة عبر الشبكة: $socketError');
          return false;
        }
      }

      return true;
    } catch (e) {
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

        // ── الرأس ──────────────────────────────────────────
        await _printLine('================================', center: true);
        await _printLine(companyName, bold: true, center: true);
        await _printLine('العنوان: $address', center: true);
        await _printLine('الهاتف: $phone', center: true);
        await _printLine('================================', center: true);
        await _printLine('تقرير إغلاق الوردية', bold: true, center: true);
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
          // Center
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  تقرير إغلاق الوردية\n');
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
        // Sunmi Print
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText(vType, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
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
          // Center
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  $vType\n');
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
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText('================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        
        await SunmiPrinter.printText(vType, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
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
          socket.add([0x1B, 0x61, 0x01]);
          socket.write('================================\n');
          socket.write('  $companyName\n');
          socket.write('  العنوان: $address\n');
          socket.write('  الهاتف: $phone\n');
          socket.write('================================\n');
          socket.write('  $vType\n');
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
}
