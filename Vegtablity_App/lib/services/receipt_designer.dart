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
    if (rawCurrency.isEmpty) return 'د.ك';
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
        0x1D, 0x76, 0x30, 0x00,
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
       /// Builds ESC/POS bytes for Network (IP) printers using high-definition Canvas raster rendering.
  /// This eliminates garbage characters and prints 100% crisp Arabic text on all 80mm & 58mm IP printers.
  static Future<List<int>> buildNetworkInvoiceBytes({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
  }) async {
    return await renderReceiptToCanvasEscPos(
      invoice: invoice,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
    );
  }

  /// Generates a high-definition raster bitmap image of the receipt for Network IP printers.
  static Future<List<int>> renderReceiptToCanvasEscPos({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
  }) async {
    final int canvasWidth = paperSize == 80 ? 576 : 384;
    final double textWidth = canvasWidth.toDouble() - 20.0;

    final List<ui.Paragraph> paragraphs = [];
    final List<ui.Offset> offsets = [];
    final List<ui.Image?> imagesToDraw = [];
    final List<ui.Offset> imageOffsets = [];
    final List<ui.Size> imageSizes = [];

    double currentY = 10.0;

    ui.Paragraph addText(
      String text, {
      bool bold = false,
      double fontSize = 24.0,
      ui.TextAlign align = ui.TextAlign.right,
      ui.Color color = const ui.Color(0xFF000000),
    }) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: align,
          textDirection: ui.TextDirection.rtl,
          fontSize: fontSize,
          fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
        ),
      );
      builder.pushStyle(ui.TextStyle(color: color));
      builder.addText(text);
      final p = builder.build();
      p.layout(ui.ParagraphConstraints(width: textWidth));
      paragraphs.add(p);
      offsets.add(ui.Offset(10.0, currentY));
      currentY += p.height + 4.0;
      return p;
    }

    void addLine({bool dashed = false}) {
      final String line = paperSize == 80
          ? (dashed ? '----------------------------------------' : '========================================')
          : (dashed ? '--------------------------------' : '================================');
      addText(line, align: ui.TextAlign.center, fontSize: 20.0);
    }

    // 1. Logo
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final Uint8List logoBytes = base64Decode(logoBase64);
        final ui.Codec codec = await ui.instantiateImageCodec(logoBytes);
        final ui.FrameInfo fi = await codec.getNextFrame();
        final ui.Image logoImg = fi.image;

        final double maxLogoW = canvasWidth * 0.5;
        final double scale = maxLogoW / logoImg.width;
        final double logoW = maxLogoW;
        final double logoH = logoImg.height * scale;

        imagesToDraw.add(logoImg);
        imageOffsets.add(ui.Offset((canvasWidth - logoW) / 2, currentY));
        imageSizes.add(ui.Size(logoW, logoH));
        currentY += logoH + 10.0;
      } catch (_) {}
    }

    // 2. Company Info
    final String companyName = companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = companySettings?['Address'] ?? 'العارضيه';
    final String phone = companySettings?['Phone'] ?? '55381505';

    addLine();
    addText(companyName, bold: true, fontSize: 28.0, align: ui.TextAlign.center);
    addText('العنوان: $address', fontSize: 22.0, align: ui.TextAlign.center);
    addText('الهاتف: $phone', fontSize: 22.0, align: ui.TextAlign.center);
    addLine();

    // 3. Invoice Header
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

    addText('فاتورة $typeName جديدة', bold: true, fontSize: 26.0, align: ui.TextAlign.right);
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText('المستودع: $openWarehouseName', fontSize: 22.0);
    }
    addText('رقم الفاتورة: $invIdStr', fontSize: 22.0);
    addText('العميل/المورد: $partnerName', fontSize: 22.0);
    addText('التاريخ والوقت: $shortDate $timeStr ($dayName)', fontSize: 20.0);
    addText('نوع العملية: ${invoice['type']}', fontSize: 20.0);

    // 4. Shipping/Delivery details if present
    final String? tempCustomerName = invoice['temp_customer_name'];
    final String? tempPhone        = invoice['temp_phone'];
    final String? tempAddress      = invoice['temp_address'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'];

    if (tempCustomerName != null || tempPhone != null || tempAddress != null) {
      addLine(dashed: true);
      addText('بيانات التوصيل والشحن:', bold: true, fontSize: 22.0);
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        addText('اسم المستلم: $tempCustomerName', fontSize: 20.0);
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        addText('هاتف المستلم: $tempPhone', fontSize: 20.0);
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        addText('عنوان التوصيل: $tempAddress', fontSize: 20.0);
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        addText('تاريخ الشحن: $tempDeliveryDate', fontSize: 20.0);
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        addText('وقت الشحن: $tempDeliveryTime', fontSize: 20.0);
      }
    }

    addLine(dashed: true);

    // 5. Items
    final items = invoice['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      final String name = item['name'] ?? '';
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
      final String qtyFormatted = _formatQuantity(qty, unitName);

      addText(name, bold: true, fontSize: 24.0);
      addText('  $qtyFormatted x ${_formatCurrency(price)} = ${_formatCurrency(total)}', fontSize: 22.0);
    }

    addLine(dashed: true);

    // 6. Totals
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

    addText('الإجمالي الكلي: $formattedTotal $cSymbol', bold: true, fontSize: 26.0);
    if (hasSplitPayment) {
      if (hasVoucherPayment) {
        addText('نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} $cSymbol', fontSize: 22.0);
        addText('عبر سند: ${_formatCurrency(voucherPaidAmount)} $cSymbol', fontSize: 22.0);
        addText('إجمالي المدفوع: $formattedPaid $cSymbol', fontSize: 22.0);
      } else {
        addText('المدفوع: $formattedPaid $cSymbol', fontSize: 22.0);
      }
      addText('المتبقي آجل: $formattedRemainder $cSymbol', bold: true, fontSize: 24.0, color: const ui.Color(0xFF8B0000));
    }
    addLine();

    // 7. Footer
    addText('شكراً لزيارتكم! طُبعت عبر نظام POS', fontSize: 22.0, align: ui.TextAlign.center);
    addLine();
    currentY += 10.0;

    // Draw everything on PictureRecorder canvas
    final int finalHeight = currentY.toInt();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // Draw White Background
    final ui.Paint bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), finalHeight.toDouble()), bgPaint);

    // Draw Logos
    for (int i = 0; i < imagesToDraw.length; i++) {
      final img = imagesToDraw[i];
      if (img != null) {
        final off = imageOffsets[i];
        final sz = imageSizes[i];
        canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          ui.Rect.fromLTWH(off.dx, off.dy, sz.width, sz.height),
          ui.Paint(),
        );
      }
    }

    // Draw Paragraphs
    for (int i = 0; i < paragraphs.length; i++) {
      paragraphs[i].paint(canvas, offsets[i]);
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image renderedImage = await picture.toImage(canvasWidth, finalHeight);

    final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final Uint8List rgbaBytes = byteData.buffer.asUint8List();
    final int widthInBytes = (canvasWidth + 7) ~/ 8;
    final List<int> escPosBytes = [];

    // Initialize printer (ESC @)
    escPosBytes.addAll([0x1B, 0x40]);
    // Center alignment (ESC a 1)
    escPosBytes.addAll([0x1B, 0x61, 0x01]);

    // ESC/POS GS v 0 raster command: GS v 0 m xL xH yL yH
    escPosBytes.addAll([
      0x1D, 0x76, 0x30, 0x00,
      widthInBytes & 0xFF,
      (widthInBytes >> 8) & 0xFF,
      finalHeight & 0xFF,
      (finalHeight >> 8) & 0xFF,
    ]);

    for (int y = 0; y < finalHeight; y++) {
      for (int byteX = 0; byteX < widthInBytes; byteX++) {
        int tempByte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final int pixelX = byteX * 8 + bit;
          if (pixelX < canvasWidth) {
            final int rgbaIndex = (y * canvasWidth + pixelX) * 4;
            final int r = rgbaBytes[rgbaIndex];
            final int g = rgbaBytes[rgbaIndex + 1];
            final int b = rgbaBytes[rgbaIndex + 2];
            final int a = rgbaBytes[rgbaIndex + 3];

            final double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
            if (a > 128 && luminance < 180) {
              tempByte |= (1 << (7 - bit));
            }
          }
        }
        escPosBytes.add(tempByte);
      }
    }

    // Feed paper and cut (GS V 66 0)
    escPosBytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return escPosBytes;
  }�:     $formattedRemainder $cSymbol\n'.codeUnits);
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

  /// Prints thermal receipt for Recipe Card
  static Future<void> printRecipeReceipt({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
  }) async {
    final sep = _getSeparator(paperSize);
    final dSep = _getDashedSeparator(paperSize);

    await SunmiPrinter.initPrinter();
    await SunmiPrinter.startTransactionPrint(true);

    // 1. Logo printing (Center aligned if available)
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final Uint8List imageBytes = base64Decode(logoBase64);
        await SunmiPrinter.printImage(imageBytes, align: SunmiPrintAlign.CENTER);
        await SunmiPrinter.lineWrap(1);
      } catch (_) {}
    }

    // 2. Company Information Header (Same as Invoice Receipt)
    final String companyName = companySettings?['CompanyName'] ?? 'شركه الضحي للمنتجات الزراعيه';
    final String address = companySettings?['Address'] ?? 'العارضيه';
    final String phone = companySettings?['Phone'] ?? '55381505';

    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText('العنوان: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('الهاتف: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // 3. Document Title
    await SunmiPrinter.printText('بطاقة وصفة ومكونات صنف', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // 4. Product & Warehouse info
    final String prodName = recipe['ProductName'] ?? recipe['product_name'] ?? 'وصفة صنف';
    final String warehouseName = recipe['WarehouseName'] ?? recipe['warehouse_name'] ?? '';
    final String notes = recipe['Notes'] ?? recipe['notes'] ?? '';

    await SunmiPrinter.printText('المنتج المصنع: $prodName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
    if (warehouseName.isNotEmpty) {
      await SunmiPrinter.printText('المستودع: $warehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    }
    if (notes.isNotEmpty) {
      await SunmiPrinter.printText('ملاحظات: $notes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    }
    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 5. Details list
    final details = recipe['Details'] as List<dynamic>? ?? [];
    for (final item in details) {
      final String barcode = item['IngredientBarcode'] ?? item['barcode'] ?? '';
      final String name = item['IngredientName'] ?? item['name'] ?? 'مادة خام';
      final String unit = item['UnitName'] ?? item['unit'] ?? '';
      final double qty = (item['Qty'] as num?)?.toDouble() ?? 0.0;
      final double unitCost = (item['UnitCost'] as num?)?.toDouble() ?? 0.0;
      final double lineCost = (item['LineCost'] as num?)?.toDouble() ?? (qty * unitCost);

      final String qtyFormatted = _formatQuantity(qty, unit);

      await SunmiPrinter.printText('$name ${barcode.isNotEmpty ? "($barcode)" : ""}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText('  $qtyFormatted x ${_formatCurrency(unitCost)} = ${_formatCurrency(lineCost)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
    }

    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

    // 6. Total Recipe Cost
    final double totalCost = (recipe['TotalCost'] as num?)?.toDouble() ?? 0.0;
    final String cSymbol = _getCurrencySymbol(companySettings);

    await SunmiPrinter.printText('التكلفة الكلية للوصفة: ${_formatCurrency(totalCost)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }

  /// Builds ESC/POS bytes for Network recipe printing
  static Future<List<int>> buildNetworkRecipeBytes({
    required Map<String, dynamic> recipe,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
  }) async {
    final List<int> bytes = [];

    // Initialize printer: ESC @ (0x1B, 0x40)
    bytes.addAll([0x1B, 0x40]);

    // 1. Logo printing (Center aligned)
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      final int targetWidth = paperSize == 80 ? 300 : 200;
      final List<int> logoBytes = await convertImageToEscPos(logoBase64, targetWidth: targetWidth);
      if (logoBytes.isNotEmpty) {
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll(logoBytes);
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
    bytes.addAll('$companyName\n'.codeUnits);
    bytes.addAll('العنوان: $address\n'.codeUnits);
    bytes.addAll('الهاتف: $phone\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    // 3. Document Title
    bytes.addAll('بطاقة وصفة ومكونات صنف\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);

    // 4. Product & Warehouse info
    bytes.addAll([0x1B, 0x61, 0x02]);
    final String prodName = recipe['ProductName'] ?? recipe['product_name'] ?? 'وصفة صنف';
    final String warehouseName = recipe['WarehouseName'] ?? recipe['warehouse_name'] ?? '';
    final String notes = recipe['Notes'] ?? recipe['notes'] ?? '';

    bytes.addAll('المنتج المصنع: $prodName\n'.codeUnits);
    if (warehouseName.isNotEmpty) {
      bytes.addAll('المستودع: $warehouseName\n'.codeUnits);
    }
    if (notes.isNotEmpty) {
      bytes.addAll('ملاحظات: $notes\n'.codeUnits);
    }
    bytes.addAll('$dSep\n'.codeUnits);

    // 5. Details list
    final details = recipe['Details'] as List<dynamic>? ?? [];
    for (final item in details) {
      final String barcode = item['IngredientBarcode'] ?? item['barcode'] ?? '';
      final String name = item['IngredientName'] ?? item['name'] ?? 'مادة خام';
      final String unit = item['UnitName'] ?? item['unit'] ?? '';
      final double qty = (item['Qty'] as num?)?.toDouble() ?? 0.0;
      final double unitCost = (item['UnitCost'] as num?)?.toDouble() ?? 0.0;
      final double lineCost = (item['LineCost'] as num?)?.toDouble() ?? (qty * unitCost);

      final String qtyFormatted = _formatQuantity(qty, unit);

      bytes.addAll('$name ${barcode.isNotEmpty ? "($barcode)" : ""}\n'.codeUnits);
      bytes.addAll('  $qtyFormatted x ${_formatCurrency(unitCost)} = ${_formatCurrency(lineCost)}\n'.codeUnits);
    }

    bytes.addAll('$sep\n'.codeUnits);

    // 6. Total Recipe Cost
    final double totalCost = (recipe['TotalCost'] as num?)?.toDouble() ?? 0.0;
    final String cSymbol = _getCurrencySymbol(companySettings);

    bytes.addAll('التكلفة الكلية للوصفة: ${_formatCurrency(totalCost)} $cSymbol\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    // Feed paper and cut
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }
}
