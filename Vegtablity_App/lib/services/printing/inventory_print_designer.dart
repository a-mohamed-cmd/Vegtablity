import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

/// Dedicated Print Designer for Wastage & Stock Take Receipts (الهالك وجرد المخزون)
class InventoryPrintDesigner {
  // =========================================================================
  // SECTION 1: DEFAULT & BLUETOOTH MODE (النص المباشر والبلوتوث - الوضع التلقائي)
  // =========================================================================

  static Future<void> printSunmiWastage({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);

      final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(isArabic ? '*** إيصال إتلاف مواد ***' : '*** WASTAGE RECEIPT ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final dynamic id = data['WastageID'] ?? data['id'] ?? '--';
      final String reason = data['Reason'] ?? data['reason'] ?? '--';
      final String date = data['date'] ?? data['Date'] ?? DateTime.now().toString().split(' ').first;

      await SunmiPrinter.printText(isArabic ? 'رقم الإيصال: #$id' : 'Receipt ID: #$id', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'السبب: $reason' : 'Reason: $reason', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'التاريخ: $date' : 'Date: $date', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List items = (data['items'] ?? data['details'] ?? []) as List;
      if (items.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'المواد التالفة:' : 'Wasted Items:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var item in items) {
          final String name = PrinterBase.getProductName(item, isArabic: isArabic);
          final double qty = double.tryParse(item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
          final String unit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
          await SunmiPrinter.printText('• $name: ${PrinterBase.formatQuantity(qty, unit)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      await SunmiPrinter.printText(isArabic ? 'طُبعت عبر نظام POS' : 'Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi wastage: $e');
    }
  }

  static Future<void> printSunmiStockTake({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);

      final String companyName = companySettings?['CompanyName'] ?? (isArabic ? 'شركه الضحي للمنتجات الزراعيه' : 'Al-Doha Agricultural Products');
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(isArabic ? '*** إيصال جرد المخزون ***' : '*** STOCK TAKE RECEIPT ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final dynamic id = data['StockTakeID'] ?? data['id'] ?? '--';
      final String date = data['date'] ?? data['Date'] ?? DateTime.now().toString().split(' ').first;

      await SunmiPrinter.printText(isArabic ? 'رقم الجرد: #$id' : 'Stock Take ID: #$id', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'التاريخ: $date' : 'Date: $date', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List items = (data['items'] ?? data['details'] ?? []) as List;
      if (items.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'الأصناف المجرودة:' : 'Counted Items:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var item in items) {
          final String name = PrinterBase.getProductName(item, isArabic: isArabic);
          final double count = double.tryParse(item['CountedQty']?.toString() ?? item['counted']?.toString() ?? '0') ?? 0.0;
          final String unit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
          await SunmiPrinter.printText('• $name: ${PrinterBase.formatQuantity(count, unit)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      await SunmiPrinter.printText(isArabic ? 'توقيع المسؤول: ___________________' : 'Auditor Signature: ___________________', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(isArabic ? 'طُبعت عبر نظام POS' : 'Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi stock take: $e');
    }
  }

  static Future<List<int>> buildDirectTextWastageBytes({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll(isArabic ? '  إيصال تالف\n'.codeUnits : '  Wastage Receipt\n'.codeUnits);
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  static Future<List<int>> buildDirectTextStockTakeBytes({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll(isArabic ? '  إيصال جرد\n'.codeUnits : '  Stock Take Receipt\n'.codeUnits);
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  // =========================================================================
  // SECTION 2: CANVA & RASTER NETWORK MODE (إعدادات CANVA والنص المباشر Network)
  // =========================================================================

  static Future<List<int>> renderWastageToCanvasEscPos({
    required Map<String, dynamic> data,
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

    addText(isArabic ? '*** إيصال إتلاف مواد ***' : '*** WASTAGE RECEIPT ***', bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final dynamic id = data['WastageID'] ?? data['id'] ?? '--';
    final String reason = data['Reason'] ?? data['reason'] ?? '--';
    final String date = data['date'] ?? data['Date'] ?? DateTime.now().toString().split(' ').first;

    addText(isArabic ? 'رقم الإيصال: #$id' : 'Receipt ID: #$id', fontSize: bodySize);
    addText(isArabic ? 'السبب: $reason' : 'Reason: $reason', fontSize: bodySize);
    addText(isArabic ? 'التاريخ: $date' : 'Date: $date', fontSize: bodySize);
    addDivider(dashed: true);

    final List items = (data['items'] ?? data['details'] ?? []) as List;
    if (items.isNotEmpty) {
      addText(isArabic ? 'المواد التالفة:' : 'Wasted Items:', bold: true, fontSize: headerSize);
      for (var item in items) {
        final String name = PrinterBase.getProductName(item, isArabic: isArabic);
        final double qty = double.tryParse(item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
        final String unit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
        addText('• $name: ${PrinterBase.formatQuantity(qty, unit)}', fontSize: bodySize);
      }
      addDivider();
    }

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

    return PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, finalHeight);
  }

  static Future<List<int>> renderStockTakeToCanvasEscPos({
    required Map<String, dynamic> data,
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

    addText(isArabic ? '*** إيصال جرد المخزون ***' : '*** STOCK TAKE RECEIPT ***', bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final dynamic id = data['StockTakeID'] ?? data['id'] ?? '--';
    final String date = data['date'] ?? data['Date'] ?? DateTime.now().toString().split(' ').first;

    addText(isArabic ? 'رقم الجرد: #$id' : 'Stock Take ID: #$id', fontSize: bodySize);
    addText(isArabic ? 'التاريخ: $date' : 'Date: $date', fontSize: bodySize);
    addDivider(dashed: true);

    final List items = (data['items'] ?? data['details'] ?? []) as List;
    if (items.isNotEmpty) {
      addText(isArabic ? 'الأصناف المجرودة:' : 'Counted Items:', bold: true, fontSize: headerSize);
      for (var item in items) {
        final String name = PrinterBase.getProductName(item, isArabic: isArabic);
        final double count = double.tryParse(item['CountedQty']?.toString() ?? item['counted']?.toString() ?? '0') ?? 0.0;
        final String unit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
        addText('• $name: ${PrinterBase.formatQuantity(count, unit)}', fontSize: bodySize);
      }
      addDivider();
    }

    addText(isArabic ? 'توقيع المسؤول: ___________________' : 'Auditor Signature: ___________________', fontSize: bodySize);
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

    return PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, finalHeight);
  }

  // =========================================================================
  // MAIN ENTRY DISPATCHERS
  // =========================================================================

  static Future<List<int>> buildWastageBytes({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderWastageToCanvasEscPos(
        data: data,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextWastageBytes(
      data: data,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }

  static Future<List<int>> buildStockTakeBytes({
    required Map<String, dynamic> data,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderStockTakeToCanvasEscPos(
        data: data,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextStockTakeBytes(
      data: data,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }
}
