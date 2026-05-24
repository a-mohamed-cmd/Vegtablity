import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'api_service.dart';

import 'package:flutter/foundation.dart';

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
      final buffer = StringBuffer();
      buffer.writeln('================================');
      buffer.writeln('   $companyName   ');
      buffer.writeln('   العنوان: $address   ');
      buffer.writeln('   الهاتف: $phone   ');
      buffer.writeln('================================');
      buffer.writeln('فاتورة $typeName جديدة');
      buffer.writeln('رقم الفاتورة: $invIdStr');
      buffer.writeln('الشريك: $partnerName');
      buffer.writeln('التاريخ: $shortDate');
      buffer.writeln('الوقت: $timeStr');
      buffer.writeln('اليوم: $dayName');
      buffer.writeln('نوع العملية: ${invoice['type']}');
      buffer.writeln('--------------------------------');
      
      final items = invoice['items'] as List<dynamic>;
      for (final item in items) {
        final String name = item['name'];
        final double price = (item['price'] as num).toDouble();
        final int qty = (item['quantity'] as num).toInt();
        final double total = (item['total'] as num).toDouble();
        buffer.writeln(name);
        buffer.writeln('  $qty x $price KWD = $total KWD');
      }
      
      buffer.writeln('--------------------------------');
      buffer.writeln('المجموع الإجمالي: ${invoice['total_amount']} KWD');
      buffer.writeln('================================');
      buffer.writeln('شكراً لزيارتكم! طبعت عبر نظام POS');
      buffer.writeln('================================');

      // Print simulated/actual output to console
      print('=== طابعة حرارية: $actualConnectionType ===');
      if (isVirtual) {
        print('محاكاة الطباعة النشطة: لم يتم تكوين طابعة بعد.');
      } else if (_connectionType == 'Network') {
        print('الاتصال عبر الشبكة: $_ipAddress:$_port');
      } else {
        print('الاتصال عبر البلوتوث: $_bluetoothDevice');
      }
      print(buffer.toString());

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
            final int qty = (item['quantity'] as num).toInt();
            final double total = (item['total'] as num).toDouble();
            await SunmiPrinter.printText(
              name,
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
            );
            await SunmiPrinter.printText(
              '  $qty x $price KWD = $total KWD',
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
            );
          }
          
          await SunmiPrinter.printText(
            '--------------------------------',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          );
          await SunmiPrinter.printText(
            'المجموع الإجمالي: ${invoice['total_amount']} KWD',
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
          );
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
            final int qty = (item['quantity'] as num).toInt();
            final double total = (item['total'] as num).toDouble();
            socket.write('$name\n');
            socket.write('  $qty x $price KWD = $total KWD\n');
          }
          
          socket.write('--------------------------------\n');
          socket.write('المجموع الإجمالي: ${invoice['total_amount']} KWD\n');
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

    // الصافي = مبلغ بداية الوردية - مشتريات مدفوعة فقط + مبيعات محصلة فقط
    final double netCash    = startingCash - totalPaidPurchases + totalPaid;
    final double difference = endingCash - netCash;
    final String diffLabel  = difference >= 0 ? 'فائض (زيادة)' : 'عجز (نقص)';

    String _fmt(double v) => v.toStringAsFixed(3);

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
        await _printLine('إجمالي المبيعات: ${_fmt(totalSales)} KWD');
        await _printLine('مُسدَّد نقداً:   ${_fmt(totalPaid)} KWD');
        await _printLine('آجل متبقي:       ${_fmt(totalRemainder)} KWD');
        await _printLine('--------------------------------');

        // ── ملخص المشتريات ─────────────────────────────────
        await _printLine('مشتريات الوردية ($purchasesCount فاتورة)', bold: true);
        await _printLine('إجمالي المشتريات: ${_fmt(totalPurchases)} KWD');
        await _printLine('مُسدَّد نقداً:    ${_fmt(totalPaidPurchases)} KWD');
        await _printLine('آجل متبقي:        ${_fmt(totalPurchasesRemainder)} KWD');
        await _printLine('--------------------------------');

        // ── تفاصيل المبيعات ────────────────────────────────
        if (salesInvoices.isNotEmpty) {
          await _printLine('تفاصيل المبيعات:', bold: true);
          for (final inv in salesInvoices) {
            final id      = inv['InvID']?.toString() ?? '-';
            final partner = inv['PartnerName'] ?? 'عميل نقدي';
            final net     = _fmt(_parseD(inv['NetAmount']));
            await _printLine('#$id  $partner  $net KWD');
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
            await _printLine('#$id  $partner  $net KWD');
          }
          await _printLine('--------------------------------');
        }

        // ── بيان النقدية ────────────────────────────────────
        await _printLine('*** بيان النقدية ***', bold: true, center: true);
        await _printLine('--------------------------------');
        await _printLine('مبلغ بدايه الورديه: ${_fmt(startingCash)} KWD');
        await _printLine('- مشتريات مدفوعه:   ${_fmt(totalPaidPurchases)} KWD');
        await _printLine('+ مبيعات محصله:     ${_fmt(totalPaid)} KWD');
        await _printLine('================================', center: true);
        await _printLine('الصافي المتوقع:     ${_fmt(netCash)} KWD', bold: true);
        await _printLine('المسدد الفعلي:      ${_fmt(endingCash)} KWD', bold: true);
        await _printLine('--------------------------------');
        await _printLine(
          '$diffLabel: ${_fmt(difference.abs())} KWD',
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
          socket.write('إجمالي المبيعات ($salesCount): ${_fmt(totalSales)} KWD\n');
          socket.write('مُسدَّد: ${_fmt(totalPaid)} KWD\n');
          socket.write('آجل متبقي: ${_fmt(totalRemainder)} KWD\n');
          socket.write('إجمالي المشتريات ($purchasesCount): ${_fmt(totalPurchases)} KWD\n');
          socket.write('مُسدَّد مشتريات: ${_fmt(totalPaidPurchases)} KWD\n');
          socket.write('آجل مشتريات: ${_fmt(totalPurchasesRemainder)} KWD\n');
          socket.write('================================\n');
          socket.write('*** بيان النقدية ***\n');
          socket.write('مبلغ بدايه الورديه: ${_fmt(startingCash)} KWD\n');
          socket.write('- مشتريات مدفوعه:   ${_fmt(totalPaidPurchases)} KWD\n');
          socket.write('+ مبيعات محصله:     ${_fmt(totalPaid)} KWD\n');
          socket.write('الصافي المتوقع:     ${_fmt(netCash)} KWD\n');
          socket.write('المسدد الفعلي:      ${_fmt(endingCash)} KWD\n');
          socket.write('$diffLabel: ${_fmt(difference.abs())} KWD\n');
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
}

