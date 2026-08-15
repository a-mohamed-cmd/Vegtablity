import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

/// Dedicated Print Designer for Daily Shift Closing Reports (تقرير إغلاق الوردية)
class ShiftReportPrintDesigner {
  static String _formatPaymentAccountName(dynamic rawName, bool isArabic) {
    if (rawName == null) return '';
    final String str = rawName.toString().trim();
    if (str.toLowerCase() == 'cash') {
      return isArabic ? 'نقداً' : 'Cash';
    }
    return str;
  }
  // =========================================================================
  // SECTION 1: DEFAULT & BLUETOOTH MODE (النص المباشر والبلوتوث - الوضع التلقائي)
  // =========================================================================

  static Future<void> printSunmiShiftReport({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);
      final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

      final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
      final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
      final String phone = companySettings?['Phone'] ?? '55381505';

      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      if (address.isNotEmpty) await SunmiPrinter.printText(isArabic ? 'العنوان: $address' : 'Address: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      if (phone.isNotEmpty) await SunmiPrinter.printText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.printText(isArabic ? '*** تقرير إغلاق الوردية ***' : '*** SHIFT CLOSING REPORT ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }

      final dynamic shiftId = summary['ShiftID'] ?? summary['id'] ?? summary['ShiftId'] ?? '--';
      final String userName = summary['UserName'] ?? summary['user_name'] ?? summary['Cashier'] ?? '--';

      DateTime? shiftStart;
      DateTime? shiftEnd;
      try { if (summary['StartTime'] != null) shiftStart = DateTime.parse(summary['StartTime'].toString()).toLocal(); } catch (_) {}
      try { if (summary['EndTime'] != null) shiftEnd = DateTime.parse(summary['EndTime'].toString()).toLocal(); } catch (_) {}

      String fmtDT(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      final String startStr = shiftStart != null ? fmtDT(shiftStart) : '--';
      final String endStr = shiftEnd != null ? fmtDT(shiftEnd) : fmtDT(DateTime.now());

      await SunmiPrinter.printText(isArabic ? 'رقم الوردية: #$shiftId' : 'Shift ID: #$shiftId', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'الكاشير: $userName' : 'Cashier: $userName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'بداية الوردية: $startStr' : 'Shift Start: $startStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'نهاية الوردية: $endStr' : 'Shift End: $endStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final double startCash = double.tryParse(summary['StartingCash']?.toString() ?? '0') ?? 0.0;
      final int salesCount = int.tryParse(summary['SalesCount']?.toString() ?? '0') ?? (salesInvoices?.length ?? 0);
      final double totalSales = double.tryParse(summary['TotalSales']?.toString() ?? '0') ?? 0.0;
      final double cashSales = double.tryParse(summary['TotalCashSales']?.toString() ?? summary['CashSales']?.toString() ?? summary['TotalPaidSales']?.toString() ?? '0') ?? 0.0;
      final double knetSales = double.tryParse(summary['TotalKnetSales']?.toString() ?? summary['KnetSales']?.toString() ?? summary['CardSales']?.toString() ?? '0') ?? 0.0;
      final double totalRefunds = double.tryParse(summary['TotalRefunds']?.toString() ?? summary['TotalReturns']?.toString() ?? '0') ?? 0.0;
      final double netSales = double.tryParse(summary['NetSales']?.toString() ?? '0') ?? (totalSales - totalRefunds);

      final int purchasesCount = int.tryParse(summary['PurchasesCount']?.toString() ?? '0') ?? (purchaseInvoices?.length ?? 0);
      final double totalPurchases = double.tryParse(summary['TotalPurchases']?.toString() ?? '0') ?? 0.0;
      final double cashPurchases = double.tryParse(summary['TotalCashPurchases']?.toString() ?? summary['CashPurchases']?.toString() ?? summary['TotalPaidPurchases']?.toString() ?? '0') ?? 0.0;
      final double receiptVouchers = double.tryParse(summary['TotalReceiptVouchers']?.toString() ?? '0') ?? 0.0;
      final double paymentVouchers = double.tryParse(summary['TotalPaymentVouchers']?.toString() ?? '0') ?? 0.0;
      final double totalExpenses = double.tryParse(summary['TotalExpenses']?.toString() ?? '0') ?? 0.0;

      final double expectedCash = double.tryParse(summary['ExpectedCash']?.toString() ?? '0') ?? (startCash + cashSales - cashPurchases + receiptVouchers - paymentVouchers - totalExpenses);
      final double actualEndingCash = endingCash ?? double.tryParse(summary['EndingCash']?.toString() ?? '0') ?? expectedCash;

      await SunmiPrinter.printText(isArabic ? '*** الملخص المالي ***' : '*** FINANCIAL SUMMARY ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(isArabic ? 'رأس المال (بداية النقدية): ${PrinterBase.formatCurrency(startCash)} $cSymbol' : 'Starting Cash: ${PrinterBase.formatCurrency(startCash)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      if (salesCount > 0) await SunmiPrinter.printText(isArabic ? 'عدد فواتير المبيعات: $salesCount' : 'Sales Count: $salesCount', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'إجمالي المبيعات: ${PrinterBase.formatCurrency(totalSales)} $cSymbol' : 'Total Sales: ${PrinterBase.formatCurrency(totalSales)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      await SunmiPrinter.printText(isArabic ? 'مبيعات الكاش: ${PrinterBase.formatCurrency(cashSales)} $cSymbol' : 'Cash Sales: ${PrinterBase.formatCurrency(cashSales)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'مبيعات الشبكة (KNET): ${PrinterBase.formatCurrency(knetSales)} $cSymbol' : 'Card/KNET Sales: ${PrinterBase.formatCurrency(knetSales)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      if (totalRefunds > 0) await SunmiPrinter.printText(isArabic ? 'إجمالي المرتجعات: ${PrinterBase.formatCurrency(totalRefunds)} $cSymbol' : 'Total Refunds: ${PrinterBase.formatCurrency(totalRefunds)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'صافي المبيعات: ${PrinterBase.formatCurrency(netSales)} $cSymbol' : 'Net Sales: ${PrinterBase.formatCurrency(netSales)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      if (purchasesCount > 0 || totalPurchases > 0) {
        await SunmiPrinter.printText(isArabic ? 'عدد المشتريات: $purchasesCount' : 'Purchases Count: $purchasesCount', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText(isArabic ? 'إجمالي المشتريات: ${PrinterBase.formatCurrency(totalPurchases)} $cSymbol' : 'Total Purchases: ${PrinterBase.formatCurrency(totalPurchases)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      if (receiptVouchers > 0) await SunmiPrinter.printText(isArabic ? 'سندات القبض: ${PrinterBase.formatCurrency(receiptVouchers)} $cSymbol' : 'Receipt Vouchers: ${PrinterBase.formatCurrency(receiptVouchers)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      if (paymentVouchers > 0) await SunmiPrinter.printText(isArabic ? 'سندات الصرف: ${PrinterBase.formatCurrency(paymentVouchers)} $cSymbol' : 'Payment Vouchers: ${PrinterBase.formatCurrency(paymentVouchers)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      if (totalExpenses > 0) await SunmiPrinter.printText(isArabic ? 'المصروفات: ${PrinterBase.formatCurrency(totalExpenses)} $cSymbol' : 'Expenses: ${PrinterBase.formatCurrency(totalExpenses)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.printText(isArabic ? 'النقدية المتوقعة بالدرج: ${PrinterBase.formatCurrency(expectedCash)} $cSymbol' : 'Expected Cash: ${PrinterBase.formatCurrency(expectedCash)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      if (endingCash != null) {
        await SunmiPrinter.printText(isArabic ? 'النقدية الفعلية بالدرج: ${PrinterBase.formatCurrency(actualEndingCash)} $cSymbol' : 'Actual Cash: ${PrinterBase.formatCurrency(actualEndingCash)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        final double diff = actualEndingCash - expectedCash;
        final String diffStr = diff >= 0 ? '+${PrinterBase.formatCurrency(diff)}' : PrinterBase.formatCurrency(diff);
        await SunmiPrinter.printText(isArabic ? 'الفارق (عجز/زيادة): $diffStr $cSymbol' : 'Variance: $diffStr $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      }
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List paymentTotals = summary['PaymentTotals'] ?? [];
      if (paymentTotals.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'تفاصيل وسائل الدفع:' : 'Payment Methods Breakdown:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var pt in paymentTotals) {
          final String pName = pt['PaymentMethodName'] ?? 'طريقة دفع';
          final double pAmount = double.tryParse(pt['TotalAmount']?.toString() ?? '0') ?? 0.0;
          await SunmiPrinter.printText('• $pName: ${PrinterBase.formatCurrency(pAmount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      final List categories = summary['CategoryBreakdown'] ?? summary['categories'] ?? [];
      if (categories.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'تفاصيل المبيعات حسب الأقسام:' : 'Category Sales Breakdown:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var cat in categories) {
          final String catName = cat['CategoryName'] ?? cat['name'] ?? 'قسم';
          final double amount = double.tryParse(cat['Amount']?.toString() ?? cat['total']?.toString() ?? '0') ?? 0.0;
          await SunmiPrinter.printText('• $catName: ${PrinterBase.formatCurrency(amount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      await SunmiPrinter.printText(isArabic ? 'طُبعت عبر نظام POS - تقرير إغلاق الوردية' : 'Printed via POS - Shift Closing Report', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi shift report: $e');
    }
  }

  static Future<List<int>> buildDirectTextShiftReportBytes({
    required Map<String, dynamic> summary,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final String sep = PrinterBase.getSeparator(paperSize);
    final String dSep = PrinterBase.getDashedSeparator(paperSize);

    bytes.addAll([0x1B, 0x40]);
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll(isArabic ? '  تقرير إغلاق الوردية\n'.codeUnits : '  Shift Closing Report\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  // =========================================================================
  // SECTION 2: CANVA & RASTER NETWORK MODE (إعدادات CANVA والنص المباشر Network)
  // =========================================================================

  static Future<List<int>> renderShiftReportToCanvasEscPos({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
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
        if (kDebugMode) print('Error processing logo in shift report canvas: $e');
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

    addText(isArabic ? '*** تقرير إغلاق الوردية ***' : '*** SHIFT CLOSING REPORT ***', bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final dynamic shiftId = summary['ShiftID'] ?? summary['id'] ?? summary['ShiftId'] ?? '--';
    final String userName = summary['UserName'] ?? summary['user_name'] ?? summary['Cashier'] ?? '--';

    DateTime? shiftStart;
    DateTime? shiftEnd;
    try { if (summary['StartTime'] != null) shiftStart = DateTime.parse(summary['StartTime'].toString()).toLocal(); } catch (_) {}
    try { if (summary['EndTime'] != null) shiftEnd = DateTime.parse(summary['EndTime'].toString()).toLocal(); } catch (_) {}

    String fmtDT(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final String startStr = shiftStart != null ? fmtDT(shiftStart) : '--';
    final String endStr = shiftEnd != null ? fmtDT(shiftEnd) : fmtDT(DateTime.now());

    addText(isArabic ? 'رقم الوردية: #$shiftId' : 'Shift ID: #$shiftId', fontSize: bodySize);
    addText(isArabic ? 'الكاشير: $userName' : 'Cashier: $userName', fontSize: bodySize);
    addText(isArabic ? 'بداية الوردية: $startStr' : 'Shift Start: $startStr', fontSize: smallSize);
    addText(isArabic ? 'نهاية الوردية: $endStr' : 'Shift End: $endStr', fontSize: smallSize);
    addDivider(dashed: true);

    final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

    final double startCash = double.tryParse(summary['StartingCash']?.toString() ?? '0') ?? 0.0;
    final int salesCount = int.tryParse(summary['SalesCount']?.toString() ?? '0') ?? (salesInvoices?.length ?? 0);
    final double totalSales = double.tryParse(summary['TotalSales']?.toString() ?? '0') ?? 0.0;
    final double cashSales = double.tryParse(summary['TotalCashSales']?.toString() ?? summary['CashSales']?.toString() ?? summary['TotalPaidSales']?.toString() ?? '0') ?? 0.0;
    final double knetSales = double.tryParse(summary['TotalKnetSales']?.toString() ?? summary['KnetSales']?.toString() ?? summary['CardSales']?.toString() ?? '0') ?? 0.0;
    final double totalRefunds = double.tryParse(summary['TotalRefunds']?.toString() ?? summary['TotalReturns']?.toString() ?? '0') ?? 0.0;
    final double netSales = double.tryParse(summary['NetSales']?.toString() ?? '0') ?? (totalSales - totalRefunds);

    final int purchasesCount = int.tryParse(summary['PurchasesCount']?.toString() ?? '0') ?? (purchaseInvoices?.length ?? 0);
    final double totalPurchases = double.tryParse(summary['TotalPurchases']?.toString() ?? '0') ?? 0.0;
    final double cashPurchases = double.tryParse(summary['TotalCashPurchases']?.toString() ?? summary['CashPurchases']?.toString() ?? summary['TotalPaidPurchases']?.toString() ?? '0') ?? 0.0;
    final double receiptVouchers = double.tryParse(summary['TotalReceiptVouchers']?.toString() ?? '0') ?? 0.0;
    final double paymentVouchers = double.tryParse(summary['TotalPaymentVouchers']?.toString() ?? '0') ?? 0.0;
    final double totalExpenses = double.tryParse(summary['TotalExpenses']?.toString() ?? '0') ?? 0.0;

    final double expectedCash = double.tryParse(summary['ExpectedCash']?.toString() ?? '0') ?? (startCash + cashSales - cashPurchases + receiptVouchers - paymentVouchers - totalExpenses);
    final double actualEndingCash = endingCash ?? double.tryParse(summary['EndingCash']?.toString() ?? '0') ?? expectedCash;

    addText(isArabic ? '*** الملخص المالي للوردية ***' : '*** FINANCIAL SUMMARY ***', bold: true, fontSize: headerSize);
    addText(isArabic ? 'رأس المال (بداية النقدية): ${PrinterBase.formatCurrency(startCash)} $cSymbol' : 'Starting Cash: ${PrinterBase.formatCurrency(startCash)} $cSymbol', fontSize: bodySize);
    if (salesCount > 0) addText(isArabic ? 'عدد فواتير المبيعات: $salesCount' : 'Sales Invoices Count: $salesCount', fontSize: smallSize);
    addText(isArabic ? 'إجمالي المبيعات: ${PrinterBase.formatCurrency(totalSales)} $cSymbol' : 'Total Sales: ${PrinterBase.formatCurrency(totalSales)} $cSymbol', bold: true, fontSize: bodySize);
    addText(isArabic ? 'مبيعات الكاش (نقداً): ${PrinterBase.formatCurrency(cashSales)} $cSymbol' : 'Cash Sales: ${PrinterBase.formatCurrency(cashSales)} $cSymbol', fontSize: bodySize);
    addText(isArabic ? 'مبيعات الشبكة (KNET/بطاقة): ${PrinterBase.formatCurrency(knetSales)} $cSymbol' : 'Card/KNET Sales: ${PrinterBase.formatCurrency(knetSales)} $cSymbol', fontSize: bodySize);
    if (totalRefunds > 0) addText(isArabic ? 'إجمالي المرتجعات: ${PrinterBase.formatCurrency(totalRefunds)} $cSymbol' : 'Total Refunds: ${PrinterBase.formatCurrency(totalRefunds)} $cSymbol', fontSize: bodySize);
    addText(isArabic ? 'صافي المبيعات: ${PrinterBase.formatCurrency(netSales)} $cSymbol' : 'Net Sales: ${PrinterBase.formatCurrency(netSales)} $cSymbol', bold: true, fontSize: bodySize);
    addDivider(dashed: true);

    if (purchasesCount > 0 || totalPurchases > 0) {
      addText(isArabic ? 'عدد فواتير المشتريات: $purchasesCount' : 'Purchases Count: $purchasesCount', fontSize: smallSize);
      addText(isArabic ? 'إجمالي المشتريات: ${PrinterBase.formatCurrency(totalPurchases)} $cSymbol' : 'Total Purchases: ${PrinterBase.formatCurrency(totalPurchases)} $cSymbol', fontSize: bodySize);
    }
    if (receiptVouchers > 0) addText(isArabic ? 'سندات القبض: ${PrinterBase.formatCurrency(receiptVouchers)} $cSymbol' : 'Receipt Vouchers: ${PrinterBase.formatCurrency(receiptVouchers)} $cSymbol', fontSize: bodySize);
    if (paymentVouchers > 0) addText(isArabic ? 'سندات الصرف: ${PrinterBase.formatCurrency(paymentVouchers)} $cSymbol' : 'Payment Vouchers: ${PrinterBase.formatCurrency(paymentVouchers)} $cSymbol', fontSize: bodySize);
    if (totalExpenses > 0) addText(isArabic ? 'إجمالي المصروفات: ${PrinterBase.formatCurrency(totalExpenses)} $cSymbol' : 'Total Expenses: ${PrinterBase.formatCurrency(totalExpenses)} $cSymbol', fontSize: bodySize);
    addDivider(dashed: true);

    addText(isArabic ? 'النقدية المتوقعة بالدرج: ${PrinterBase.formatCurrency(expectedCash)} $cSymbol' : 'Expected Cash in Drawer: ${PrinterBase.formatCurrency(expectedCash)} $cSymbol', bold: true, fontSize: headerSize);
    if (endingCash != null) {
      addText(isArabic ? 'النقدية الفعلية بالدرج: ${PrinterBase.formatCurrency(actualEndingCash)} $cSymbol' : 'Actual Cash in Drawer: ${PrinterBase.formatCurrency(actualEndingCash)} $cSymbol', bold: true, fontSize: headerSize);
      final double diff = actualEndingCash - expectedCash;
      final String diffStr = diff >= 0 ? '+${PrinterBase.formatCurrency(diff)}' : PrinterBase.formatCurrency(diff);
      final ui.Color diffColor = diff < 0 ? const ui.Color(0xFF8B0000) : const ui.Color(0xFF006400);
      addText(isArabic ? 'الفارق (عجز/زيادة): $diffStr $cSymbol' : 'Variance: $diffStr $cSymbol', bold: true, fontSize: headerSize, color: diffColor);
    }
    addDivider();

    // Categories Breakdown
    final List categories = summary['CategoryBreakdown'] ?? summary['categories'] ?? [];
    if (categories.isNotEmpty) {
      addText(isArabic ? 'تفاصيل المبيعات حسب الأقسام:' : 'Category Sales Breakdown:', bold: true, fontSize: headerSize);
      for (var cat in categories) {
        final String name = cat['CategoryName'] ?? cat['name'] ?? 'قسم';
        final double amount = double.tryParse(cat['Amount']?.toString() ?? cat['total']?.toString() ?? '0') ?? 0.0;
        addText('• $name: ${PrinterBase.formatCurrency(amount)} $cSymbol', fontSize: bodySize);
      }
      addDivider();
    }

    addText(isArabic ? 'طُبعت عبر نظام POS - تقرير إغلاق الوردية' : 'Printed via POS - Shift Closing Report', fontSize: bodySize, align: ui.TextAlign.center);
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

    return PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, finalHeight);
  }

  // =========================================================================
  // MAIN ENTRY DISPATCHER
  // =========================================================================

  static Future<List<int>> buildShiftReportBytes({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderShiftReportToCanvasEscPos(
        summary: summary,
        salesInvoices: salesInvoices,
        purchaseInvoices: purchaseInvoices,
        endingCash: endingCash,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextShiftReportBytes(
      summary: summary,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }
}
