import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

/// Unified Print Designer for Receipt Vouchers, Payment Vouchers, and General Vouchers (سندات القبض والصرف والسندات العامة)
class VoucherPrintDesigner {
  static String _formatPaymentAccountName(dynamic rawName, bool isArabic) {
    if (rawName == null) return '';
    return rawName.toString().trim();
  }
  // =========================================================================
  // SECTION 1: DEFAULT & BLUETOOTH MODE (النص المباشر والبلوتوث - الوضع التلقائي)
  // =========================================================================

  static Future<void> printSunmiVoucher({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);
      await PrinterBase.openSunmiDrawer();

      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);
      final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

      final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
      final String type = voucher['type'] ?? voucher['VoucherType'] ?? 'receipt';
      final bool isReceipt = type == 'receipt' || type.toString().contains('قبض');
      final String voucherTitle = isReceipt ? (isArabic ? '*** سند قبض ***' : '*** RECEIPT VOUCHER ***') : (isArabic ? '*** سند صرف ***' : '*** PAYMENT VOUCHER ***');

      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(voucherTitle, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final dynamic voucherId = voucher['VoucherID'] ?? voucher['id'] ?? '--';
      final String partnerName = voucher['PartnerName'] ?? voucher['partner_name'] ?? '--';
      final String dateStr = voucher['date'] ?? voucher['VoucherDate'] ?? DateTime.now().toString().split(' ').first;

      await SunmiPrinter.printText(isArabic ? 'رقم السند: #$voucherId' : 'Voucher No: #$voucherId', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'العميل/المورد: $partnerName' : 'Partner: $partnerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'التاريخ والوقت: $dateStr' : 'Date & Time: $dateStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final double amount = double.tryParse(voucher['Amount']?.toString() ?? voucher['amount']?.toString() ?? '0') ?? 0.0;
      await SunmiPrinter.printText(isArabic ? 'المبلغ المستلم: ${PrinterBase.formatCurrency(amount)} $cSymbol' : 'Amount: ${PrinterBase.formatCurrency(amount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));

      final String rawMethod = (voucher['payment_method'] ?? voucher['PaymentMethod'] ?? voucher['account_name'] ?? voucher['AccountName'] ?? '').toString();
      final String method = rawMethod.isNotEmpty ? _formatPaymentAccountName(rawMethod, isArabic) : (isArabic ? 'نقداً' : 'Cash');
      await SunmiPrinter.printText(isArabic ? 'طريقة الدفع: $method' : 'Payment Method: $method', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

      final String notes = voucher['Notes'] ?? voucher['notes'] ?? voucher['description'] ?? '';
      if (notes.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'البيان: $notes' : 'Description: $notes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      if (paidInvoices.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'الفواتير المسددة بالسند:' : 'Paid Invoices:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var inv in paidInvoices) {
          final dynamic invNo = inv['InvoiceID'] ?? inv['id'] ?? '--';
          final double paidAmt = double.tryParse(inv['PaidAmount']?.toString() ?? inv['paid']?.toString() ?? '0') ?? 0.0;
          await SunmiPrinter.printText(isArabic ? '• فاتورة #$invNo : ${PrinterBase.formatCurrency(paidAmt)} $cSymbol' : '• Invoice #$invNo: ${PrinterBase.formatCurrency(paidAmt)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      await SunmiPrinter.printText(isArabic ? 'توقيع المستلم: ___________________' : 'Recipient Signature: ___________________', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(isArabic ? 'شكراً لتعاملكم معنا!' : 'Thank you for your business!', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi voucher: $e');
    }
  }

  static Future<void> printSunmiGeneralVoucher({
    required Map<String, dynamic> voucher,
    required String targetAccountName,
    required String cashAccountName,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);
      await PrinterBase.openSunmiDrawer();

      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);
      final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

      final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
      final String type = voucher['type'] ?? 'Receipt';
      final bool isReceipt = type == 'Receipt' || type.toString().contains('قبض');
      final String title = isReceipt ? (isArabic ? '*** سند قبض عام ***' : '*** GENERAL RECEIPT VOUCHER ***') : (isArabic ? '*** سند صرف عام ***' : '*** GENERAL PAYMENT VOUCHER ***');

      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(title, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final dynamic vId = voucher['VoucherID'] ?? voucher['id'] ?? '--';
      await SunmiPrinter.printText(isArabic ? 'رقم السند: #$vId' : 'Voucher ID: #$vId', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'حساب النقدية: $cashAccountName' : 'Cash Account: $cashAccountName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'الحساب المستهدف: $targetAccountName' : 'Target Account: $targetAccountName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final double amount = double.tryParse(voucher['amount']?.toString() ?? voucher['Amount']?.toString() ?? '0') ?? 0.0;
      await SunmiPrinter.printText(isArabic ? 'المبلغ: ${PrinterBase.formatCurrency(amount)} $cSymbol' : 'Amount: ${PrinterBase.formatCurrency(amount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));

      final String notes = voucher['notes'] ?? voucher['Notes'] ?? '';
      if (notes.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'البيان: $notes' : 'Notes: $notes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(isArabic ? 'طُبعت عبر نظام POS' : 'Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi general voucher: $e');
    }
  }

  static Future<List<int>> buildDirectTextVoucherBytes({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final String sep = PrinterBase.getSeparator(paperSize);
    final String dSep = PrinterBase.getDashedSeparator(paperSize);

    bytes.addAll(PrinterBase.getDrawerKickBytes());
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll(isArabic ? '  سند مالية\n'.codeUnits : '  Voucher Receipt\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  static Future<List<int>> buildDirectTextGeneralVoucherBytes({
    required Map<String, dynamic> voucher,
    required String targetAccountName,
    required String cashAccountName,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    bytes.addAll(PrinterBase.getDrawerKickBytes());
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll(isArabic ? '  سند عام\n'.codeUnits : '  General Voucher\n'.codeUnits);
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  // =========================================================================
  // SECTION 2: CANVA & RASTER NETWORK MODE (إعدادات CANVA والنص المباشر Network)
  // =========================================================================

  static Future<List<int>> renderVoucherToCanvasEscPos({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final int canvasWidth = paperSize == 80 ? 576 : 384;
    final double textWidth = canvasWidth.toDouble() - 20.0;

    final double titleSize = paperSize == 80 ? 28.0 : 22.0;
    final double headerSize = paperSize == 80 ? 22.0 : 18.0;
    final double bodySize = paperSize == 80 ? 20.0 : 16.0;
    final double smallSize = paperSize == 80 ? 18.0 : 14.0;

    ui.Image? logoImage;
    if (companySettings != null && companySettings['Logo'] != null) {
      try {
        final String rawLogo = companySettings['Logo'].toString();
        final String base64Str = rawLogo.contains(',') ? rawLogo.split(',').last : rawLogo;
        final Uint8List logoBytes = base64Decode(base64Str);
        final ui.Codec codec = await ui.instantiateImageCodec(logoBytes);
        final ui.FrameInfo fi = await codec.getNextFrame();
        logoImage = fi.image;
      } catch (e) {
        if (kDebugMode) print('Error processing logo in voucher canvas: $e');
      }
    }

    final List<ui.Paragraph> paragraphs = [];
    final List<ui.Offset> offsets = [];
    final List<ui.Image> images = [];
    final List<ui.Offset> imageOffsets = [];
    final List<ui.Size> imageSizes = [];

    double currentY = 10.0;

    void addText(
      String text, {
      double? fontSize,
      bool bold = false,
      ui.TextAlign? align,
      ui.Color color = const ui.Color(0xFF000000),
    }) {
      final ui.TextAlign defaultAlign = align ?? (isArabic ? ui.TextAlign.right : ui.TextAlign.left);
      final ui.TextDirection defaultDirection = isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr;

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: defaultAlign,
          textDirection: defaultDirection,
          maxLines: 10,
        ),
      );
      builder.pushStyle(
        ui.TextStyle(
          color: color,
          fontSize: fontSize ?? bodySize,
          fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
        ),
      );
      builder.addText(text);
      final ui.Paragraph paragraph = builder.build();
      paragraph.layout(ui.ParagraphConstraints(width: textWidth));

      paragraphs.add(paragraph);
      offsets.add(ui.Offset(10.0, currentY));
      currentY += paragraph.height + 4.0;
    }

    void addDivider({bool dashed = false}) {
      final String lineStr = dashed ? PrinterBase.getDashedSeparator(paperSize) : PrinterBase.getSeparator(paperSize);
      addText(lineStr, fontSize: smallSize, align: ui.TextAlign.center);
    }

    if (logoImage != null) {
      final double maxLogoW = canvasWidth * 0.45;
      final double logoW = logoImage.width > maxLogoW ? maxLogoW : logoImage.width.toDouble();
      final double logoH = logoW * (logoImage.height / logoImage.width);

      images.add(logoImage);
      imageOffsets.add(ui.Offset((canvasWidth - logoW) / 2, currentY));
      imageSizes.add(ui.Size(logoW, logoH));
      currentY += logoH + 10.0;
    }

    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
    final String phone = companySettings?['Phone'] ?? '55381505';

    addDivider();
    addText(companyName, bold: true, fontSize: titleSize, align: ui.TextAlign.center);
    if (address.isNotEmpty) addText(isArabic ? 'العنوان: $address' : 'Address: $address', fontSize: bodySize, align: ui.TextAlign.center);
    if (phone.isNotEmpty) addText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', fontSize: bodySize, align: ui.TextAlign.center);
    addDivider();

    final String type = voucher['type'] ?? voucher['VoucherType'] ?? 'receipt';
    final bool isReceipt = type == 'receipt' || type.toString().contains('قبض');
    final String voucherTitle = isReceipt ? (isArabic ? '*** سند قبض ***' : '*** RECEIPT VOUCHER ***') : (isArabic ? '*** سند صرف ***' : '*** PAYMENT VOUCHER ***');

    addText(voucherTitle, bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final dynamic voucherId = voucher['VoucherID'] ?? voucher['id'] ?? '--';
    final String partnerName = voucher['PartnerName'] ?? voucher['partner_name'] ?? '--';
    final String dateStr = voucher['date'] ?? voucher['VoucherDate'] ?? DateTime.now().toString().split(' ').first;

    addText(isArabic ? 'رقم السند: #$voucherId' : 'Voucher No: #$voucherId', fontSize: bodySize);
    addText(isArabic ? 'العميل/المورد: $partnerName' : 'Partner: $partnerName', fontSize: bodySize);
    addText(isArabic ? 'التاريخ والوقت: $dateStr' : 'Date & Time: $dateStr', fontSize: smallSize);
    addDivider(dashed: true);

    final double amount = double.tryParse(voucher['Amount']?.toString() ?? voucher['amount']?.toString() ?? '0') ?? 0.0;
    final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

    addText(isArabic ? 'المبلغ المستلم: ${PrinterBase.formatCurrency(amount)} $cSymbol' : 'Amount: ${PrinterBase.formatCurrency(amount)} $cSymbol', bold: true, fontSize: headerSize);
    final String rawMethod = (voucher['payment_method'] ?? voucher['PaymentMethod'] ?? voucher['account_name'] ?? voucher['AccountName'] ?? '').toString();
    final String method = rawMethod.isNotEmpty ? _formatPaymentAccountName(rawMethod, isArabic) : (isArabic ? 'نقداً' : 'Cash');
    addText(isArabic ? 'طريقة الدفع: $method' : 'Payment Method: $method', fontSize: bodySize);

    final String notes = voucher['Notes'] ?? voucher['notes'] ?? voucher['description'] ?? '';
    if (notes.isNotEmpty) {
      addText(isArabic ? 'البيان: $notes' : 'Description: $notes', fontSize: bodySize);
    }
    addDivider(dashed: true);

    if (paidInvoices.isNotEmpty) {
      addText(isArabic ? 'الفواتير المسددة بالسند:' : 'Paid Invoices:', bold: true, fontSize: bodySize);
      for (var inv in paidInvoices) {
        final dynamic invNo = inv['InvoiceID'] ?? inv['id'] ?? '--';
        final double paidAmt = double.tryParse(inv['PaidAmount']?.toString() ?? inv['paid']?.toString() ?? '0') ?? 0.0;
        addText(isArabic ? '• فاتورة #$invNo : ${PrinterBase.formatCurrency(paidAmt)} $cSymbol' : '• Invoice #$invNo: ${PrinterBase.formatCurrency(paidAmt)} $cSymbol', fontSize: bodySize);
      }
      addDivider(dashed: true);
    }

    addText(isArabic ? 'توقيع المستلم: ___________________' : 'Recipient Signature: ___________________', fontSize: bodySize);
    addDivider();
    addText(isArabic ? 'شكراً لتعاملكم معنا!' : 'Thank you for your business!', fontSize: bodySize, align: ui.TextAlign.center);
    addDivider();
    currentY += 15.0;

    final int finalHeight = currentY.ceil();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    final ui.Paint bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), finalHeight.toDouble()), bgPaint);

    for (int i = 0; i < images.length; i++) {
      canvas.drawImageRect(
        images[i],
        ui.Rect.fromLTWH(0, 0, images[i].width.toDouble(), images[i].height.toDouble()),
        ui.Rect.fromLTWH(imageOffsets[i].dx, imageOffsets[i].dy, imageSizes[i].width, imageSizes[i].height),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }

    for (int i = 0; i < paragraphs.length; i++) {
      canvas.drawParagraph(paragraphs[i], offsets[i]);
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image renderedImage = await picture.toImage(canvasWidth, finalHeight);

    final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final List<int> rasterBytes = PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, finalHeight);
    return [...PrinterBase.getDrawerKickBytes(), ...rasterBytes];
  }

  static Future<List<int>> renderGeneralVoucherToCanvasEscPos({
    required Map<String, dynamic> voucher,
    required String targetAccountName,
    required String cashAccountName,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final int canvasWidth = paperSize == 80 ? 576 : 384;
    final double textWidth = canvasWidth.toDouble() - 20.0;

    final double titleSize = paperSize == 80 ? 28.0 : 22.0;
    final double headerSize = paperSize == 80 ? 22.0 : 18.0;
    final double bodySize = paperSize == 80 ? 20.0 : 16.0;

    final List<ui.Paragraph> paragraphs = [];
    final List<ui.Offset> offsets = [];

    double currentY = 10.0;

    void addText(
      String text, {
      double? fontSize,
      bool bold = false,
      ui.TextAlign? align,
    }) {
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: align ?? (isArabic ? ui.TextAlign.right : ui.TextAlign.left),
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          maxLines: 10,
        ),
      );
      builder.pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000), fontSize: fontSize ?? bodySize, fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal));
      builder.addText(text);
      final ui.Paragraph paragraph = builder.build();
      paragraph.layout(ui.ParagraphConstraints(width: textWidth));

      paragraphs.add(paragraph);
      offsets.add(ui.Offset(10.0, currentY));
      currentY += paragraph.height + 4.0;
    }

    void addDivider({bool dashed = false}) {
      addText(dashed ? PrinterBase.getDashedSeparator(paperSize) : PrinterBase.getSeparator(paperSize), fontSize: 16.0, align: ui.TextAlign.center);
    }

    final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
    addDivider();
    addText(companyName, bold: true, fontSize: titleSize, align: ui.TextAlign.center);
    addDivider();

    final String type = voucher['type'] ?? 'Receipt';
    final bool isReceipt = type == 'Receipt' || type.toString().contains('قبض');
    final String title = isReceipt ? (isArabic ? '*** سند قبض عام ***' : '*** GENERAL RECEIPT VOUCHER ***') : (isArabic ? '*** سند صرف عام ***' : '*** GENERAL PAYMENT VOUCHER ***');

    addText(title, bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final dynamic vId = voucher['VoucherID'] ?? voucher['id'] ?? '--';
    addText(isArabic ? 'رقم السند: #$vId' : 'Voucher ID: #$vId', fontSize: bodySize);
    addText(isArabic ? 'حساب النقدية: $cashAccountName' : 'Cash Account: $cashAccountName', fontSize: bodySize);
    addText(isArabic ? 'الحساب المستهدف: $targetAccountName' : 'Target Account: $targetAccountName', fontSize: bodySize);
    addDivider(dashed: true);

    final double amount = double.tryParse(voucher['amount']?.toString() ?? voucher['Amount']?.toString() ?? '0') ?? 0.0;
    final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

    addText(isArabic ? 'المبلغ: ${PrinterBase.formatCurrency(amount)} $cSymbol' : 'Amount: ${PrinterBase.formatCurrency(amount)} $cSymbol', bold: true, fontSize: headerSize);
    final String notes = voucher['notes'] ?? voucher['Notes'] ?? '';
    if (notes.isNotEmpty) {
      addText(isArabic ? 'البيان: $notes' : 'Notes: $notes', fontSize: bodySize);
    }
    addDivider();

    addText(isArabic ? 'طُبعت عبر نظام POS' : 'Printed via POS System', fontSize: bodySize, align: ui.TextAlign.center);
    addDivider();
    currentY += 15.0;

    final int finalHeight = currentY.ceil();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), finalHeight.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    for (int i = 0; i < paragraphs.length; i++) {
      canvas.drawParagraph(paragraphs[i], offsets[i]);
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image renderedImage = await picture.toImage(canvasWidth, finalHeight);

    final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final List<int> rasterBytes = PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, finalHeight);
    return [...PrinterBase.getDrawerKickBytes(), ...rasterBytes];
  }

  // =========================================================================
  // MAIN ENTRY DISPATCHERS
  // =========================================================================

  static Future<List<int>> buildVoucherBytes({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderVoucherToCanvasEscPos(
        voucher: voucher,
        paidInvoices: paidInvoices,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextVoucherBytes(
      voucher: voucher,
      paidInvoices: paidInvoices,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }

  static Future<List<int>> buildGeneralVoucherBytes({
    required Map<String, dynamic> voucher,
    required String targetAccountName,
    required String cashAccountName,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderGeneralVoucherToCanvasEscPos(
        voucher: voucher,
        targetAccountName: targetAccountName,
        cashAccountName: cashAccountName,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextGeneralVoucherBytes(
      voucher: voucher,
      targetAccountName: targetAccountName,
      cashAccountName: cashAccountName,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }
}
