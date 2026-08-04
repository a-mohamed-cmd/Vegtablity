import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

/// Dedicated Print Designer for Production Recipes (بطاقات الوصفات والتصنيع)
class RecipePrintDesigner {
  // =========================================================================
  // SECTION 1: DEFAULT & BLUETOOTH MODE (النص المباشر والبلوتوث - الوضع التلقائي)
  // =========================================================================

  static Future<void> printSunmiRecipe({
    required Map<String, dynamic> recipe,
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
      await SunmiPrinter.printText(isArabic ? '*** بطاقة وصفة تصنيع ***' : '*** PRODUCTION RECIPE CARD ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final String name = PrinterBase.getProductName(recipe, isArabic: isArabic);
      final String code = recipe['code'] ?? recipe['RecipeCode'] ?? '--';
      final double qty = double.tryParse(recipe['produced_quantity']?.toString() ?? recipe['Quantity']?.toString() ?? '1') ?? 1.0;

      await SunmiPrinter.printText(isArabic ? 'اسم الوصفة: $name' : 'Recipe Name: $name', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      await SunmiPrinter.printText(isArabic ? 'كود الوصفة: $code' : 'Recipe Code: $code', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'الكمية المنتجة: $qty' : 'Produced Quantity: $qty', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List ingredients = (recipe['items'] ?? recipe['ingredients'] ?? recipe['Ingredients'] ?? []) as List;
      if (ingredients.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'المكونات والمواد الخام:' : 'Ingredients & Materials:', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var item in ingredients) {
          final String iName = PrinterBase.getProductName(item, isArabic: isArabic);
          final double iQty = double.tryParse(item['quantity']?.toString() ?? item['Quantity']?.toString() ?? '0') ?? 0.0;
          final String iUnit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
          await SunmiPrinter.printText('• $iName: ${PrinterBase.formatQuantity(iQty, iUnit)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      }

      await SunmiPrinter.printText(isArabic ? 'طُبعت عبر نظام POS' : 'Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi recipe: $e');
    }
  }

  static Future<List<int>> buildDirectTextRecipeBytes({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll(isArabic ? '  بطاقة وصفة\n'.codeUnits : '  Recipe Card\n'.codeUnits);
    bytes.addAll([0x1B, 0x64, 0x04]);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  // =========================================================================
  // SECTION 2: CANVA & RASTER NETWORK MODE (إعدادات CANVA والنص المباشر Network)
  // =========================================================================

  static Future<List<int>> renderRecipeToCanvasEscPos({
    required Map<String, dynamic> recipe,
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

    addText(isArabic ? '*** بطاقة وصفة تصنيع ***' : '*** PRODUCTION RECIPE CARD ***', bold: true, fontSize: headerSize, align: ui.TextAlign.center);
    addDivider(dashed: true);

    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }

    final String name = PrinterBase.getProductName(recipe, isArabic: isArabic);
    final String code = recipe['code'] ?? recipe['RecipeCode'] ?? '--';
    final double qty = double.tryParse(recipe['produced_quantity']?.toString() ?? recipe['Quantity']?.toString() ?? '1') ?? 1.0;

    addText(isArabic ? 'اسم الوصفة: $name' : 'Recipe Name: $name', bold: true, fontSize: headerSize);
    addText(isArabic ? 'كود الوصفة: $code' : 'Recipe Code: $code', fontSize: bodySize);
    addText(isArabic ? 'الكمية المنتجة: $qty' : 'Produced Quantity: $qty', fontSize: bodySize);
    addDivider(dashed: true);

    final List ingredients = (recipe['items'] ?? recipe['ingredients'] ?? recipe['Ingredients'] ?? []) as List;
    if (ingredients.isNotEmpty) {
      addText(isArabic ? 'المكونات والمواد الخام:' : 'Ingredients & Materials:', bold: true, fontSize: headerSize);
      for (var item in ingredients) {
        final String iName = PrinterBase.getProductName(item, isArabic: isArabic);
        final double iQty = double.tryParse(item['quantity']?.toString() ?? item['Quantity']?.toString() ?? '0') ?? 0.0;
        final String iUnit = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? '';
        addText('• $iName: ${PrinterBase.formatQuantity(iQty, iUnit)}', fontSize: bodySize);
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

  // =========================================================================
  // MAIN ENTRY DISPATCHER
  // =========================================================================

  static Future<List<int>> buildRecipeBytes({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderRecipeToCanvasEscPos(
        recipe: recipe,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextRecipeBytes(
      recipe: recipe,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }
}
