import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ReceiptDesigner {
  static String _formatCurrency(double amount) {
    String s = amount.toStringAsFixed(2);
    final parts = s.split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String intPart = parts[0].replaceAllMapped(reg, (Match match) => '${match[1]},');
    return '$intPart.${parts[1]}';
  }

  static String _formatQuantity(double qty, String unit) {
    String qStr;
    if (qty == qty.toInt()) {
      qStr = qty.toInt().toString();
    } else {
      qStr = qty.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
    return unit.isNotEmpty ? '$unit $qStr' : qStr;
  }

  static String _getSeparator(int paperSize) {
    return paperSize == 80
        ? '================================================'
        : '================================';
  }

  static String _getDashedSeparator(int paperSize) {
    return paperSize == 80
        ? '------------------------------------------------'
        : '--------------------------------';
  }

  static String _getCurrencySymbol(Map<String, dynamic>? companySettings) {
    final rawCurrency = companySettings?['CurrencySymbol']?.toString() ?? '';
    if (rawCurrency.isEmpty) return '';
    if (rawCurrency.contains('/')) {
      return rawCurrency.split('/')[0].trim();
    }
    return rawCurrency.trim();
  }

  /// Converts a base64 encoded image to ESC/POS raster format (GS v 0) for network printers.
  static Future<List<int>> convertImageToEscPos(String base64Image, {int targetWidth = 200}) async {
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final int origWidth = image.width;
      final int origHeight = image.height;
      final double scale = targetWidth / origWidth;
      final int targetHeight = (origHeight * scale).toInt();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Paint paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, origWidth.toDouble(), origHeight.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image scaledImage = await picture.toImage(targetWidth, targetHeight);

      final ByteData? byteData = await scaledImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return [];

      final Uint8List rgbaBytes = byteData.buffer.asUint8List();
      final int widthInBytes = (targetWidth + 7) ~/ 8;
      final List<int> escPosBytes = [];

      // ESC/POS GS v 0 command: GS v 0 m xL xH yL yH
      escPosBytes.addAll([
        0x1D, 0x56, 0x30, 0x00,
        widthInBytes & 0xFF,
        (widthInBytes >> 8) & 0xFF,
        targetHeight & 0xFF,
        (targetHeight >> 8) & 0xFF,
      ]);

      for (int y = 0; y < targetHeight; y++) {
        for (int byteX = 0; byteX < widthInBytes; byteX++) {
          int tempByte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final int pixelX = byteX * 8 + bit;
            if (pixelX < targetWidth) {
              final int rgbaIndex = (y * targetWidth + pixelX) * 4;
              final int r = rgbaBytes[rgbaIndex];
              final int g = rgbaBytes[rgbaIndex + 1];
              final int b = rgbaBytes[rgbaIndex + 2];
              final int a = rgbaBytes[rgbaIndex + 3];

              // Threshold for black pixel (luminance < 180 and opaque)
              final double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
              if (a > 128 && luminance < 180) {
                tempByte |= (1 << (7 - bit));
              }
            }
          }
          escPosBytes.add(tempByte);
        }
      }

      return escPosBytes;
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في معالجة شعار الطابعة النقطية: $e');
      }
      return [];
    }
  }

  /// Builds ESC/POS bytes for Network (IP) printers with new design & logo.
  static Future<List<int>> buildNetworkInvoiceBytes({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
  }) async {
    final List<int> bytes = [];

    // Initialize printer: ESC @ (0x1B, 0x40)
    bytes.addAll([0x1B, 0x40]);

    // 1. Logo printing (Center aligned)
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      // 200px width is perfect for 58mm, 300px for 80mm
      final int targetWidth = paperSize == 80 ? 300 : 200;
      final List<int> logoBytes = await convertImageToEscPos(logoBase64, targetWidth: targetWidth);
      if (logoBytes.isNotEmpty) {
        // Alignment: Center (ESC a 1)
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll(logoBytes);
        // Print extra line feed after logo
        bytes.addAll('\n'.codeUnits);
      }
    }

    // 2. Company Information Header (Center aligned)
    bytes.addAll([0x1B, 0x61, 0x01]);
    final String companyName = companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = companySettings?['Address'] ?? 'العارضيه';
    final String phone = companySettings?['Phone'] ?? '55381505';

    final String sep = _getSeparator(paperSize);
    final String dSep = _getDashedSeparator(paperSize);

    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll('   $companyName\n'.codeUnits);
    bytes.addAll('   العنوان: $address\n'.codeUnits);
    bytes.addAll('   الهاتف: $phone\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    // 3. Invoice Header Information (Right aligned)
    bytes.addAll([0x1B, 0x61, 0x02]);

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

    bytes.addAll('فاتورة $typeName جديدة\n'.codeUnits);
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      bytes.addAll('المستودع: $openWarehouseName\n'.codeUnits);
    }
    bytes.addAll('رقم الفاتورة: $invIdStr\n'.codeUnits);
    
    // Print partner name if available
    bytes.addAll('العميل/المورد: $partnerName\n'.codeUnits);
    
    bytes.addAll('التاريخ: $shortDate\n'.codeUnits);
    bytes.addAll('الوقت: $timeStr\n'.codeUnits);
    bytes.addAll('اليوم: $dayName\n'.codeUnits);
    bytes.addAll('نوع العملية: ${invoice['type']}\n'.codeUnits);

    // 4. Temporary Customer/Shipping details (Right aligned)
    final String? tempCustomerName = invoice['temp_customer_name'];
    final String? tempPhone        = invoice['temp_phone'];
    final String? tempAddress      = invoice['temp_address'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'];

    if (tempCustomerName != null || tempPhone != null || tempAddress != null) {
      bytes.addAll('$dSep\n'.codeUnits);
      bytes.addAll('بيانات التوصيل والشحن:\n'.codeUnits);
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        bytes.addAll('اسم المستلم: $tempCustomerName\n'.codeUnits);
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        bytes.addAll('هاتف المستلم: $tempPhone\n'.codeUnits);
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        bytes.addAll('عنوان التوصيل: $tempAddress\n'.codeUnits);
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        bytes.addAll('تاريخ الشحن: $tempDeliveryDate\n'.codeUnits);
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        bytes.addAll('وقت الشحن: $tempDeliveryTime\n'.codeUnits);
      }
    }

    bytes.addAll('$dSep\n'.codeUnits);

    // 5. Items details (Right aligned)
    final items = invoice['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      final String name = item['name'] ?? '';
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
      final String qtyFormatted = _formatQuantity(qty, unitName);

      bytes.addAll('$name\n'.codeUnits);
      bytes.addAll('  $qtyFormatted x ${_formatCurrency(price)} = ${_formatCurrency(total)}\n'.codeUnits);
    }

    bytes.addAll('$dSep\n'.codeUnits);

    // 6. Totals & Payment Summary
    final double totalAmount       = (invoice['total_amount']        as num?)?.toDouble() ?? 0.0;
    final double paidAtCreate       = (invoice['paid_amount']         as num?)?.toDouble() ?? 0.0;
    final double voucherPaidAmount  = (invoice['voucher_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double remainder          = (invoice['remainder']           as num?)?.toDouble() ?? 0.0;
    final double totalPaid = paidAtCreate + voucherPaidAmount;

    final String formattedTotal     = _formatCurrency(totalAmount);
    final String formattedPaid      = _formatCurrency(totalPaid);
    final String formattedRemainder = _formatCurrency(remainder);
    final String cSymbol = _getCurrencySymbol(companySettings);

    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;
    final bool hasVoucherPayment = voucherPaidAmount > 0.001;

    bytes.addAll('الإجمالي الكلي: $formattedTotal $cSymbol\n'.codeUnits);
    if (hasSplitPayment) {
      if (hasVoucherPayment) {
        bytes.addAll('نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} $cSymbol\n'.codeUnits);
        bytes.addAll('عبر سند:         ${_formatCurrency(voucherPaidAmount)} $cSymbol\n'.codeUnits);
        bytes.addAll('إجمالي المدفوع:  $formattedPaid $cSymbol\n'.codeUnits);
      } else {
        bytes.addAll('المدفوع:         $formattedPaid $cSymbol\n'.codeUnits);
      }
      bytes.addAll('المتبقي آجل:     $formattedRemainder $cSymbol\n'.codeUnits);
    }
    bytes.addAll('$sep\n'.codeUnits);

    // 7. Footer (Center aligned)
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('شكراً لزيارتكم! طبعت عبر نظام POS\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    // Feed paper and cut (GS V 66 0)
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  /// Prints using Sunmi internal printer API.
  static Future<void> printSunmiInvoice({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
  }) async {
    // 1. Logo printing (Center aligned)
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final Uint8List logoBytes = base64Decode(logoBase64);
        await SunmiPrinter.printImage(logoBytes, align: SunmiPrintAlign.CENTER);
        // Print extra spacer line
        await SunmiPrinter.printText(' ');
      } catch (e) {
        if (kDebugMode) {
          print('خطأ أثناء طباعة شعار Sunmi: $e');
        }
      }
    }

    final String companyName = companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = companySettings?['Address'] ?? 'العارضيه';
    final String phone = companySettings?['Phone'] ?? '55381505';

    final String sep = _getSeparator(paperSize);
    final String dSep = _getDashedSeparator(paperSize);

    // 2. Company Information Header (Center aligned)
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // 3. Invoice Header Information (Right aligned)
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

    await SunmiPrinter.printText('فاتورة $typeName جديدة', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      await SunmiPrinter.printText('المستودع: $openWarehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    }
    await SunmiPrinter.printText('رقم الفاتورة: $invIdStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    await SunmiPrinter.printText('العميل/المورد: $partnerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    await SunmiPrinter.printText('التاريخ: $shortDate', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    await SunmiPrinter.printText('الوقت: $timeStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    await SunmiPrinter.printText('اليوم: $dayName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    await SunmiPrinter.printText('نوع العملية: ${invoice['type']}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 4. Temporary Customer/Shipping details (Right aligned)
    final String? tempCustomerName = invoice['temp_customer_name'];
    final String? tempPhone        = invoice['temp_phone'];
    final String? tempAddress      = invoice['temp_address'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'];

    if (tempCustomerName != null || tempPhone != null || tempAddress != null) {
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText('بيانات التوصيل والشحن:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        await SunmiPrinter.printText('اسم المستلم: $tempCustomerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        await SunmiPrinter.printText('هاتف المستلم: $tempPhone', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        await SunmiPrinter.printText('عنوان التوصيل: $tempAddress', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        await SunmiPrinter.printText('تاريخ الشحن: $tempDeliveryDate', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        await SunmiPrinter.printText('وقت الشحن: $tempDeliveryTime', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
    }

    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 5. Items details (Right aligned)
    final items = invoice['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      final String name = item['name'] ?? '';
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
      final String qtyFormatted = _formatQuantity(qty, unitName);

      await SunmiPrinter.printText(name, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText('  $qtyFormatted x ${_formatCurrency(price)} = ${_formatCurrency(total)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    }

    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 6. Totals & Payment Summary
    final double totalAmount       = (invoice['total_amount']        as num?)?.toDouble() ?? 0.0;
    final double paidAtCreate       = (invoice['paid_amount']         as num?)?.toDouble() ?? 0.0;
    final double voucherPaidAmount  = (invoice['voucher_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double remainder          = (invoice['remainder']           as num?)?.toDouble() ?? 0.0;
    final double totalPaid = paidAtCreate + voucherPaidAmount;

    final String formattedTotal     = _formatCurrency(totalAmount);
    final String formattedPaid      = _formatCurrency(totalPaid);
    final String formattedRemainder = _formatCurrency(remainder);
    final String cSymbol = _getCurrencySymbol(companySettings);

    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;
    final bool hasVoucherPayment = voucherPaidAmount > 0.001;

    await SunmiPrinter.printText('الإجمالي الكلي: $formattedTotal $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
    if (hasSplitPayment) {
      if (hasVoucherPayment) {
        await SunmiPrinter.printText('نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('عبر سند:         ${_formatCurrency(voucherPaidAmount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText('إجمالي المدفوع:  $formattedPaid $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      } else {
        await SunmiPrinter.printText('المدفوع:         $formattedPaid $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      await SunmiPrinter.printText('المتبقي آجل:     $formattedRemainder $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
    }
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 7. Footer (Center aligned)
    await SunmiPrinter.printText('شكراً لزيارتكم! طبعت عبر نظام POS', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // Feed paper and cut
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }
}
