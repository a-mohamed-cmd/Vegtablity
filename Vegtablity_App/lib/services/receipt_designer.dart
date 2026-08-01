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

  static String _getCurrencySymbol(Map<String, dynamic>? companySettings, {bool isArabic = true}) {
    final rawCurrency = companySettings?['CurrencySymbol']?.toString() ?? '';
    if (rawCurrency.isEmpty) return isArabic ? 'د.ك' : 'KWD';
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
        print('Error processing printer logo: $e');
      }
      return [];
    }
  }

  /// Builds ESC/POS bytes for Network (IP) printers.
  /// Supports both HD Raster Canvas mode (for 100% Arabic & Logo accuracy) and Direct Text mode.
  static Future<List<int>> buildNetworkInvoiceBytes({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderReceiptToCanvasEscPos(
        invoice: invoice,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextNetworkInvoiceBytes(
      invoice: invoice,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }

  /// Generates a high-definition raster bitmap image of the receipt for Network IP printers.
  /// Dynamically renders in Arabic or English based on `isArabic`.
  static Future<List<int>> renderReceiptToCanvasEscPos({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
    bool isArabic = true,
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
      ui.TextAlign? align,
      ui.Color color = const ui.Color(0xFF000000),
    }) {
      final ui.TextAlign defaultAlign = align ?? (isArabic ? ui.TextAlign.right : ui.TextAlign.left);
      final ui.TextDirection defaultDirection = isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr;

      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: defaultAlign,
          textDirection: defaultDirection,
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
    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    addLine();
    addText(companyName, bold: true, fontSize: 28.0, align: ui.TextAlign.center);
    addText(isArabic ? 'العنوان: $address' : 'Address: $address', fontSize: 22.0, align: ui.TextAlign.center);
    addText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', fontSize: 22.0, align: ui.TextAlign.center);
    addLine();

    // 3. Invoice Header
    final String invType = invoice['type'] ?? 'Sales';
    final String typeName = (invType == 'Sales' || invType == 'Sale') 
        ? (isArabic ? 'مبيعات' : 'Sales') 
        : (isArabic ? 'مشتريات' : 'Purchases');
        
    final int? invId = invoice['InvID'] ?? invoice['invoice_id'] ?? invoice['id'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة (غير محفوظة)' : 'New (Draft)');
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName.contains('Sales') || typeName == 'مبيعات' ? (isArabic ? 'عميل نقدي' : 'Cash Customer') : (isArabic ? 'مورد نقدي' : 'Cash Supplier'));

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
    final List<String> days = isArabic 
        ? ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final String dayName = days[printDateTime.weekday - 1];

    addText(isArabic ? 'فاتورة $typeName جديدة' : 'New $typeName Invoice', bold: true, fontSize: 26.0);
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: 22.0);
    }
    addText(isArabic ? 'رقم الفاتورة: $invIdStr' : 'Invoice No: $invIdStr', fontSize: 22.0);
    addText(isArabic ? 'العميل/المورد: $partnerName' : 'Customer/Supplier: $partnerName', fontSize: 22.0);
    addText(isArabic ? 'التاريخ والوقت: $shortDate $timeStr ($dayName)' : 'Date & Time: $shortDate $timeStr ($dayName)', fontSize: 20.0);
    addText(isArabic ? 'نوع العملية: ${invoice['type']}' : 'Operation Type: ${invoice['type']}', fontSize: 20.0);

    // 4. Shipping/Delivery details if present
    final String? tempCustomerName = invoice['temp_customer_name'];
    final String? tempPhone        = invoice['temp_phone'];
    final String? tempAddress      = invoice['temp_address'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'];

    if (tempCustomerName != null || tempPhone != null || tempAddress != null) {
      addLine(dashed: true);
      addText(isArabic ? 'بيانات التوصيل والشحن:' : 'Delivery & Shipping Info:', bold: true, fontSize: 22.0);
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        addText(isArabic ? 'اسم المستلم: $tempCustomerName' : 'Recipient: $tempCustomerName', fontSize: 20.0);
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        addText(isArabic ? 'هاتف المستلم: $tempPhone' : 'Phone: $tempPhone', fontSize: 20.0);
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        addText(isArabic ? 'عنوان التوصيل: $tempAddress' : 'Address: $tempAddress', fontSize: 20.0);
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        addText(isArabic ? 'تاريخ الشحن: $tempDeliveryDate' : 'Ship Date: $tempDeliveryDate', fontSize: 20.0);
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        addText(isArabic ? 'وقت الشحن: $tempDeliveryTime' : 'Ship Time: $tempDeliveryTime', fontSize: 20.0);
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
    final String cSymbol = _getCurrencySymbol(companySettings, isArabic: isArabic);

    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;
    final bool hasVoucherPayment = voucherPaidAmount > 0.001;

    addText(isArabic ? 'الإجمالي الكلي: $formattedTotal $cSymbol' : 'Grand Total: $formattedTotal $cSymbol', bold: true, fontSize: 26.0);
    if (hasSplitPayment) {
      if (hasVoucherPayment) {
        addText(isArabic ? 'نقداً عند الإنشاء: ${_formatCurrency(paidAtCreate)} $cSymbol' : 'Paid at creation: ${_formatCurrency(paidAtCreate)} $cSymbol', fontSize: 22.0);
        addText(isArabic ? 'عبر سند: ${_formatCurrency(voucherPaidAmount)} $cSymbol' : 'Voucher Paid: ${_formatCurrency(voucherPaidAmount)} $cSymbol', fontSize: 22.0);
        addText(isArabic ? 'إجمالي المدفوع: $formattedPaid $cSymbol' : 'Total Paid: $formattedPaid $cSymbol', fontSize: 22.0);
      } else {
        addText(isArabic ? 'المدفوع: $formattedPaid $cSymbol' : 'Paid Amount: $formattedPaid $cSymbol', fontSize: 22.0);
      }
      addText(isArabic ? 'المتبقي آجل: $formattedRemainder $cSymbol' : 'Balance Due: $formattedRemainder $cSymbol', bold: true, fontSize: 24.0, color: const ui.Color(0xFF8B0000));
    }
    addLine();

    // 7. Footer
    addText(isArabic ? 'شكراً لزيارتكم! طُبعت عبر نظام POS' : 'Thank you for your visit! Printed via POS System', fontSize: 22.0, align: ui.TextAlign.center);
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
      canvas.drawParagraph(paragraphs[i], offsets[i]);
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
  }

  /// Builds ESC/POS bytes using direct text streaming.
  static Future<List<int>> buildDirectTextNetworkInvoiceBytes({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic>? companySettings,
    required int paperSize,
    required String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final String sep = _getSeparator(paperSize);
    final String dSep = _getDashedSeparator(paperSize);
    final String cSymbol = _getCurrencySymbol(companySettings, isArabic: isArabic);

    // Initialize printer (ESC @)
    bytes.addAll([0x1B, 0x40]);

    // 1. Logo if present
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

    // 2. Company Info (Center aligned)
    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll('  $companyName\n'.codeUnits);
    bytes.addAll(isArabic ? '  العنوان: $address\n'.codeUnits : '  Address: $address\n'.codeUnits);
    bytes.addAll(isArabic ? '  الهاتف: $phone\n'.codeUnits : '  Phone: $phone\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    // 3. Invoice Header
    final String invType = invoice['type'] ?? 'Sales';
    final String typeName = (invType == 'Sales' || invType == 'Sale') 
        ? (isArabic ? 'مبيعات' : 'Sales') 
        : (isArabic ? 'مشتريات' : 'Purchases');
        
    final int? invId = invoice['InvID'] ?? invoice['invoice_id'] ?? invoice['id'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة' : 'New');
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName.contains('Sales') || typeName == 'مبيعات' ? (isArabic ? 'عميل نقدي' : 'Cash Customer') : (isArabic ? 'مورد نقدي' : 'Cash Supplier'));

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

    bytes.addAll(isArabic ? '  فاتورة $typeName جديدة\n'.codeUnits : '  New $typeName Invoice\n'.codeUnits);
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      bytes.addAll(isArabic ? 'المستودع: $openWarehouseName\n'.codeUnits : 'Warehouse: $openWarehouseName\n'.codeUnits);
    }
    bytes.addAll(isArabic ? 'رقم الفاتورة: $invIdStr\n'.codeUnits : 'Invoice No: $invIdStr\n'.codeUnits);
    bytes.addAll(isArabic ? 'العميل/المورد: $partnerName\n'.codeUnits : 'Customer/Supplier: $partnerName\n'.codeUnits);
    bytes.addAll(isArabic ? 'التاريخ والوقت: $shortDate $timeStr\n'.codeUnits : 'Date & Time: $shortDate $timeStr\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);

    // 4. Items
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

    // 5. Totals
    final double totalAmount       = (invoice['total_amount']        as num?)?.toDouble() ?? 0.0;
    final double paidAtCreate       = (invoice['paid_amount']         as num?)?.toDouble() ?? 0.0;
    final double voucherPaidAmount  = (invoice['voucher_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double remainder          = (invoice['remainder']           as num?)?.toDouble() ?? 0.0;
    final double totalPaid = paidAtCreate + voucherPaidAmount;

    final String formattedTotal     = _formatCurrency(totalAmount);
    final String formattedPaid      = _formatCurrency(totalPaid);
    final String formattedRemainder = _formatCurrency(remainder);

    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;

    bytes.addAll(isArabic ? 'الإجمالي الكلي: $formattedTotal $cSymbol\n'.codeUnits : 'Grand Total: $formattedTotal $cSymbol\n'.codeUnits);
    if (hasSplitPayment) {
      bytes.addAll(isArabic ? 'المدفوع:         $formattedPaid $cSymbol\n'.codeUnits : 'Paid Amount:     $formattedPaid $cSymbol\n'.codeUnits);
      bytes.addAll(isArabic ? 'المتبقي آجل:     $formattedRemainder $cSymbol\n'.codeUnits : 'Balance Due:     $formattedRemainder $cSymbol\n'.codeUnits);
    }
    bytes.addAll('$sep\n'.codeUnits);

    // 6. Footer (Center aligned)
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(isArabic ? 'شكراً لزيارتكم! طبعت عبر نظام POS\n'.codeUnits : 'Thank you for your visit! Printed via POS System\n'.codeUnits);
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
    bool isArabic = true,
  }) async {
    final SunmiPrintAlign align = isArabic ? SunmiPrintAlign.RIGHT : SunmiPrintAlign.LEFT;

    // 1. Logo printing (Center aligned)
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final Uint8List logoBytes = base64Decode(logoBase64);
        await SunmiPrinter.printImage(logoBytes, align: SunmiPrintAlign.CENTER);
        await SunmiPrinter.printText(' ');
      } catch (e) {
        if (kDebugMode) {
          print('Error printing Sunmi logo: $e');
        }
      }
    }

    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    final String sep = _getSeparator(paperSize);
    final String dSep = _getDashedSeparator(paperSize);

    // 2. Company Information Header (Center aligned)
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText(isArabic ? 'العنوان: $address' : 'Address: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // 3. Invoice Header Information
    final String invType = invoice['type'] ?? 'Sales';
    final String typeName = (invType == 'Sales' || invType == 'Sale') 
        ? (isArabic ? 'مبيعات' : 'Sales') 
        : (isArabic ? 'مشتريات' : 'Purchases');

    final int? invId = invoice['InvID'] ?? invoice['invoice_id'] ?? invoice['id'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة' : 'New');
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName.contains('Sales') || typeName == 'مبيعات' ? (isArabic ? 'عميل نقدي' : 'Cash Customer') : (isArabic ? 'مورد نقدي' : 'Cash Supplier'));

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
    final List<String> days = isArabic 
        ? ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final String dayName = days[printDateTime.weekday - 1];

    await SunmiPrinter.printText(isArabic ? 'فاتورة $typeName جديدة' : 'New $typeName Invoice', style: SunmiTextStyle(align: align, bold: true));
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      await SunmiPrinter.printText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', style: SunmiTextStyle(align: align));
    }
    await SunmiPrinter.printText(isArabic ? 'رقم الفاتورة: $invIdStr' : 'Invoice No: $invIdStr', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'العميل/المورد: $partnerName' : 'Customer/Supplier: $partnerName', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'التاريخ: $shortDate' : 'Date: $shortDate', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'الوقت: $timeStr' : 'Time: $timeStr', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'اليوم: $dayName' : 'Day: $dayName', style: SunmiTextStyle(align: align));

    // 4. Temporary Customer/Shipping details
    final String? tempCustomerName = invoice['temp_customer_name'];
    final String? tempPhone        = invoice['temp_phone'];
    final String? tempAddress      = invoice['temp_address'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'];

    if (tempCustomerName != null || tempPhone != null || tempAddress != null) {
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: align));
      await SunmiPrinter.printText(isArabic ? 'بيانات التوصيل والشحن:' : 'Delivery & Shipping Info:', style: SunmiTextStyle(align: align, bold: true));
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'اسم المستلم: $tempCustomerName' : 'Recipient: $tempCustomerName', style: SunmiTextStyle(align: align));
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'هاتف المستلم: $tempPhone' : 'Phone: $tempPhone', style: SunmiTextStyle(align: align));
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'عنوان التوصيل: $tempAddress' : 'Address: $tempAddress', style: SunmiTextStyle(align: align));
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'تاريخ الشحن: $tempDeliveryDate' : 'Ship Date: $tempDeliveryDate', style: SunmiTextStyle(align: align));
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'وقت الشحن: $tempDeliveryTime' : 'Ship Time: $tempDeliveryTime', style: SunmiTextStyle(align: align));
      }
    }

    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: align));

    // 5. Items details
    final items = invoice['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      final String name = item['name'] ?? '';
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final String unitName = item['UnitName'] ?? item['unit'] ?? item['unit_name'] ?? '';
      final String qtyFormatted = _formatQuantity(qty, unitName);

      await SunmiPrinter.printText(name, style: SunmiTextStyle(align: align, bold: true));
      await SunmiPrinter.printText('  $qtyFormatted x ${_formatCurrency(price)} = ${_formatCurrency(total)}', style: SunmiTextStyle(align: align));
    }

    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: align));

    // 6. Totals & Payment Summary
    final double totalAmount       = (invoice['total_amount']        as num?)?.toDouble() ?? 0.0;
    final double paidAtCreate       = (invoice['paid_amount']         as num?)?.toDouble() ?? 0.0;
    final double voucherPaidAmount  = (invoice['voucher_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final double remainder          = (invoice['remainder']           as num?)?.toDouble() ?? 0.0;
    final double totalPaid = paidAtCreate + voucherPaidAmount;

    final String formattedTotal     = _formatCurrency(totalAmount);
    final String formattedPaid      = _formatCurrency(totalPaid);
    final String formattedRemainder = _formatCurrency(remainder);
    final String cSymbol = _getCurrencySymbol(companySettings, isArabic: isArabic);

    final bool hasSplitPayment = remainder > 0.001 || totalPaid < totalAmount - 0.001;

    await SunmiPrinter.printText(isArabic ? 'الإجمالي الكلي: $formattedTotal $cSymbol' : 'Grand Total: $formattedTotal $cSymbol', style: SunmiTextStyle(align: align, bold: true));
    if (hasSplitPayment) {
      await SunmiPrinter.printText(isArabic ? 'المدفوع:         $formattedPaid $cSymbol' : 'Paid Amount:     $formattedPaid $cSymbol', style: SunmiTextStyle(align: align));
      await SunmiPrinter.printText(isArabic ? 'المتبقي آجل:     $formattedRemainder $cSymbol' : 'Balance Due:     $formattedRemainder $cSymbol', style: SunmiTextStyle(align: align, bold: true));
    }
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: align));

    // 7. Footer (Center aligned)
    await SunmiPrinter.printText(isArabic ? 'شكراً لزيارتكم! طبعت عبر نظام POS' : 'Thank you for your visit! Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
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
    bool isArabic = true,
  }) async {
    final sep = _getSeparator(paperSize);
    final dSep = _getDashedSeparator(paperSize);
    final SunmiPrintAlign align = isArabic ? SunmiPrintAlign.RIGHT : SunmiPrintAlign.LEFT;

    await SunmiPrinter.initPrinter();
    await SunmiPrinter.startTransactionPrint(true);

    // 1. Logo printing
    final String? logoBase64 = companySettings?['Logo'];
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final Uint8List imageBytes = base64Decode(logoBase64);
        await SunmiPrinter.printImage(imageBytes, align: SunmiPrintAlign.CENTER);
        await SunmiPrinter.lineWrap(1);
      } catch (_) {}
    }

    // 2. Company Information Header
    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText(isArabic ? 'العنوان: $address' : 'Address: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    // 3. Recipe Info
    final String recipeName = recipe['RecipeName'] ?? (isArabic ? 'وصفة تصنيع' : 'Production Recipe');
    final String productName = recipe['ProductName'] ?? '-';
    final double yieldQty = (recipe['YieldQuantity'] as num?)?.toDouble() ?? 1.0;
    final double totalCost = (recipe['TotalCost'] as num?)?.toDouble() ?? 0.0;
    final String cSymbol = _getCurrencySymbol(companySettings, isArabic: isArabic);

    await SunmiPrinter.printText(isArabic ? '*** بطاقة وصفة تصنيع ***' : '*** PRODUCTION RECIPE CARD ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText(isArabic ? 'اسم الوصفة: $recipeName' : 'Recipe Name: $recipeName', style: SunmiTextStyle(align: align, bold: true));
    await SunmiPrinter.printText(isArabic ? 'المنتج النهائي: $productName' : 'Finished Product: $productName', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'الكمية المنتجة: $yieldQty' : 'Yield Quantity: $yieldQty', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(isArabic ? 'التكلفة التقديرية: ${_formatCurrency(totalCost)} $cSymbol' : 'Est. Cost: ${_formatCurrency(totalCost)} $cSymbol', style: SunmiTextStyle(align: align));
    await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: align));

    // 4. Ingredients
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? recipe['Items'] as List<dynamic>? ?? [];
    if (ingredients.isNotEmpty) {
      await SunmiPrinter.printText(isArabic ? 'المكونات والمواد الخام:' : 'Ingredients & Materials:', style: SunmiTextStyle(align: align, bold: true));
      for (final ing in ingredients) {
        final String ingName = ing['IngredientName'] ?? ing['ProductName'] ?? ing['name'] ?? '';
        final double qty = (ing['Quantity'] as num?)?.toDouble() ?? 0.0;
        final double cost = (ing['Cost'] as num?)?.toDouble() ?? 0.0;
        final String unit = ing['UnitName'] ?? ing['unit'] ?? '';

        await SunmiPrinter.printText('• $ingName', style: SunmiTextStyle(align: align, bold: true));
        await SunmiPrinter.printText('  ${_formatQuantity(qty, unit)} x ${_formatCurrency(cost)} $cSymbol', style: SunmiTextStyle(align: align));
      }
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: align));
    }

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
    await SunmiPrinter.exitTransactionPrint(true);
  }

  /// Builds network bytes for Recipe Card
  static Future<List<int>> buildNetworkRecipeBytes({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final String sep = _getSeparator(paperSize);
    final String dSep = _getDashedSeparator(paperSize);
    final String cSymbol = _getCurrencySymbol(companySettings, isArabic: isArabic);

    bytes.addAll([0x1B, 0x40]);

    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll('  $companyName\n'.codeUnits);
    bytes.addAll(isArabic ? '  العنوان: $address\n'.codeUnits : '  Address: $address\n'.codeUnits);
    bytes.addAll(isArabic ? '  الهاتف: $phone\n'.codeUnits : '  Phone: $phone\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);

    final String recipeName = recipe['RecipeName'] ?? (isArabic ? 'وصفة تصنيع' : 'Production Recipe');
    final String productName = recipe['ProductName'] ?? '-';
    final double yieldQty = (recipe['YieldQuantity'] as num?)?.toDouble() ?? 1.0;
    final double totalCost = (recipe['TotalCost'] as num?)?.toDouble() ?? 0.0;

    bytes.addAll(isArabic ? '*** بطاقة وصفة تصنيع ***\n'.codeUnits : '*** PRODUCTION RECIPE CARD ***\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);
    bytes.addAll(isArabic ? 'اسم الوصفة: $recipeName\n'.codeUnits : 'Recipe Name: $recipeName\n'.codeUnits);
    bytes.addAll(isArabic ? 'المنتج النهائي: $productName\n'.codeUnits : 'Finished Product: $productName\n'.codeUnits);
    bytes.addAll(isArabic ? 'الكمية المنتجة: $yieldQty\n'.codeUnits : 'Yield Quantity: $yieldQty\n'.codeUnits);
    bytes.addAll(isArabic ? 'التكلفة التقديرية: ${_formatCurrency(totalCost)} $cSymbol\n'.codeUnits : 'Est. Cost: ${_formatCurrency(totalCost)} $cSymbol\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);

    final ingredients = recipe['ingredients'] as List<dynamic>? ?? recipe['Items'] as List<dynamic>? ?? [];
    if (ingredients.isNotEmpty) {
      bytes.addAll(isArabic ? 'المكونات والمواد الخام:\n'.codeUnits : 'Ingredients & Materials:\n'.codeUnits);
      for (final ing in ingredients) {
        final String ingName = ing['IngredientName'] ?? ing['ProductName'] ?? ing['name'] ?? '';
        final double qty = (ing['Quantity'] as num?)?.toDouble() ?? 0.0;
        final double cost = (ing['Cost'] as num?)?.toDouble() ?? 0.0;
        final String unit = ing['UnitName'] ?? ing['unit'] ?? '';

        bytes.addAll('• $ingName\n'.codeUnits);
        bytes.addAll('  ${_formatQuantity(qty, unit)} x ${_formatCurrency(cost)} $cSymbol\n'.codeUnits);
      }
      bytes.addAll('$sep\n'.codeUnits);
    }

    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }
}
