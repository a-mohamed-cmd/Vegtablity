import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

class BarcodePrintDesigner {
  /// Code 128 B pattern lookup table (107 patterns, 6 bar/space widths each)
  static const List<List<int>> _code128Patterns = [
    [2, 1, 2, 2, 2, 2], // 0  ' '
    [2, 2, 2, 1, 2, 2], // 1  '!'
    [2, 2, 2, 2, 2, 1], // 2  '"'
    [1, 2, 1, 2, 2, 3], // 3  '#'
    [1, 2, 1, 3, 2, 2], // 4  '$'
    [1, 3, 1, 2, 2, 2], // 5  '%'
    [1, 2, 2, 2, 1, 3], // 6  '&'
    [1, 2, 2, 3, 1, 2], // 7  '\''
    [1, 3, 2, 2, 1, 2], // 8  '('
    [2, 2, 1, 2, 1, 3], // 9  ')'
    [2, 2, 1, 3, 1, 2], // 10 '*'
    [2, 3, 1, 2, 1, 2], // 11 '+'
    [1, 1, 2, 2, 3, 2], // 12 ','
    [1, 2, 2, 1, 3, 2], // 13 '-'
    [1, 2, 2, 2, 3, 1], // 14 '.'
    [1, 1, 3, 2, 2, 2], // 15 '/'
    [1, 2, 3, 2, 1, 2], // 16 '0'
    [2, 2, 3, 2, 1, 1], // 17 '1'
    [2, 2, 1, 2, 3, 1], // 18 '2'
    [2, 1, 3, 2, 1, 2], // 19 '3'
    [2, 2, 3, 1, 1, 2], // 20 '4'
    [3, 1, 2, 1, 3, 1], // 21 '5'
    [3, 1, 1, 2, 2, 2], // 22 '6'
    [3, 2, 1, 1, 2, 2], // 23 '7'
    [3, 2, 2, 2, 1, 1], // 24 '8'
    [2, 1, 2, 1, 2, 3], // 25 '9'
    [2, 1, 2, 3, 2, 1], // 26 ':'
    [2, 3, 2, 1, 2, 1], // 27 ';'
    [1, 1, 1, 3, 2, 3], // 28 '<'
    [1, 3, 1, 1, 2, 3], // 29 '='
    [1, 3, 1, 3, 2, 1], // 30 '>'
    [1, 1, 2, 3, 1, 3], // 31 '?'
    [1, 3, 2, 1, 1, 3], // 32 '@'
    [2, 1, 1, 1, 3, 3], // 33 'A'
    [2, 1, 1, 3, 3, 1], // 34 'B'
    [2, 3, 1, 1, 3, 1], // 35 'C'
    [2, 1, 3, 1, 1, 3], // 36 'D'
    [2, 1, 3, 3, 1, 1], // 37 'E'
    [2, 3, 3, 1, 1, 1], // 38 'F'
    [3, 1, 1, 1, 2, 3], // 39 'G'
    [3, 1, 1, 3, 2, 1], // 40 'H'
    [3, 3, 1, 1, 2, 1], // 41 'I'
    [3, 1, 2, 1, 1, 3], // 42 'J'
    [3, 1, 2, 3, 1, 1], // 43 'K'
    [3, 3, 2, 1, 1, 1], // 44 'L'
    [3, 1, 4, 1, 1, 1], // 45 'M'
    [2, 2, 1, 4, 1, 1], // 46 'N'
    [4, 3, 1, 1, 1, 1], // 47 'O'
    [1, 1, 1, 2, 2, 4], // 48 'P'
    [1, 1, 1, 4, 2, 2], // 49 'Q'
    [1, 2, 1, 1, 2, 4], // 50 'R'
    [1, 2, 1, 4, 2, 1], // 51 'S'
    [1, 4, 1, 1, 2, 2], // 52 'T'
    [1, 4, 1, 2, 2, 1], // 53 'U'
    [1, 1, 2, 2, 1, 4], // 54 'V'
    [1, 1, 2, 4, 1, 2], // 55 'W'
    [1, 2, 2, 1, 1, 4], // 56 'X'
    [1, 2, 2, 4, 1, 1], // 57 'Y'
    [1, 4, 2, 1, 1, 2], // 58 'Z'
    [1, 4, 2, 2, 1, 1], // 59 '['
    [2, 4, 1, 1, 1, 2], // 60 '\\'
    [1, 3, 4, 1, 1, 1], // 61 ']'
    [1, 1, 1, 2, 4, 2], // 62 '^'
    [1, 2, 1, 1, 4, 2], // 63 '_'
    [1, 2, 1, 2, 4, 1], // 64 '`'
    [1, 1, 4, 2, 1, 2], // 65 'a'
    [1, 2, 4, 1, 1, 2], // 66 'b'
    [1, 2, 4, 2, 1, 1], // 67 'c'
    [4, 1, 1, 2, 1, 2], // 68 'd'
    [4, 2, 1, 1, 1, 2], // 69 'e'
    [4, 2, 1, 2, 1, 1], // 70 'f'
    [2, 1, 2, 1, 4, 1], // 71 'g'
    [2, 1, 4, 1, 2, 1], // 72 'h'
    [4, 1, 2, 1, 2, 1], // 73 'i'
    [1, 1, 1, 1, 4, 3], // 74 'j'
    [1, 1, 1, 3, 4, 1], // 75 'k'
    [1, 3, 1, 1, 4, 1], // 76 'l'
    [1, 1, 4, 1, 1, 3], // 77 'm'
    [1, 1, 4, 3, 1, 1], // 78 'n'
    [4, 1, 1, 1, 1, 3], // 79 'o'
    [4, 1, 1, 3, 1, 1], // 80 'p'
    [1, 1, 3, 1, 4, 1], // 81 'q'
    [1, 1, 4, 1, 3, 1], // 82 'r'
    [3, 1, 1, 1, 4, 1], // 83 's'
    [4, 1, 1, 1, 3, 1], // 84 't'
    [2, 1, 1, 4, 1, 2], // 85 'u'
    [2, 1, 1, 2, 1, 4], // 86 'v'
    [2, 1, 4, 1, 1, 2], // 87 'w'
    [2, 3, 1, 1, 1, 4], // 88 'x'
    [2, 1, 1, 4, 2, 1], // 89 'y'
    [2, 1, 2, 4, 1, 1], // 90 'z'
    [3, 3, 2, 1, 1, 2], // 91 '{'
    [3, 1, 4, 1, 1, 2], // 92 '|'
    [3, 1, 2, 1, 4, 1], // 93 '}'
    [3, 1, 2, 2, 4, 1], // 94 '~'
    [3, 1, 4, 1, 2, 1], // 95 DEL
    [3, 1, 2, 1, 2, 4], // 96 FNC3
    [3, 1, 2, 4, 2, 1], // 97 FNC2
    [3, 1, 2, 1, 1, 4], // 98 SHIFT
    [3, 1, 2, 1, 4, 1], // 99 CODE C
    [3, 1, 4, 1, 1, 2], // 100 CODE B
    [2, 1, 1, 4, 1, 2], // 101 FNC1
    [2, 1, 1, 2, 1, 4], // 102 START A
    [2, 1, 1, 2, 3, 2], // 103 START B
    [2, 1, 1, 2, 2, 3], // 104 START C
    [2, 3, 3, 1, 1, 1], // 105 STOP
  ];

  /// Encodes input string into Code 128 (Type B) bit list (true = black bar, false = white space)
  static List<bool> encodeCode128B(String text) {
    if (text.isEmpty) text = "000000";
    final List<int> values = [];
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 32 && code <= 126) {
        values.add(code - 32);
      } else {
        values.add(0); // Fallback to space
      }
    }

    const int startB = 103;
    int checksum = startB;
    for (int i = 0; i < values.length; i++) {
      checksum += values[i] * (i + 1);
    }
    checksum %= 103;

    final List<int> patternSequence = [];
    patternSequence.add(startB);
    patternSequence.addAll(values);
    patternSequence.add(checksum);
    patternSequence.add(105); // STOP pattern

    final List<bool> bits = [];
    for (int pIndex in patternSequence) {
      final List<int> widths = _code128Patterns[pIndex];
      bool isBar = true;
      for (int width in widths) {
        for (int w = 0; w < width; w++) {
          bits.add(isBar);
        }
        isBar = !isBar;
      }
    }
    // Code 128 termination bar (width 2)
    bits.add(true);
    bits.add(true);
    return bits;
  }

  /// Generates HD Canvas Raster Bytes for 80mm / 58mm Thermal Printers (Network / IP / Canvas Mode)
  static Future<List<int>> generateCanvasRasterBytes(
    Map<String, dynamic> product,
    Map<String, dynamic>? companySettings, {
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    final int canvasWidth = paperSize == 80 ? 576 : 384;
    final String companyName = companySettings?['CompanyName']?.toString().trim() ?? 'Vegtablity POS';
    final String productName = PrinterBase.getProductName(product, isArabic: isArabic);
    final String barcode = product['Barcode']?.toString().trim() ?? product['barcode']?.toString().trim() ?? '000000';
    final double salePrice = double.tryParse(product['SalePrice']?.toString() ?? product['saleprice']?.toString() ?? '0') ?? 0.0;
    final String currencySymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // White background
    final ui.Paint bgPaint = ui.Paint()..color = Colors.white;
    int currentY = 10;
    
    // Calculate total label canvas height dynamically
    const int canvasHeight = 240;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()), bgPaint);

    // 1. Company Name Header
    final TextPainter headerPainter = TextPainter(
      text: TextSpan(
        text: companyName,
        style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
    headerPainter.layout(maxWidth: canvasWidth.toDouble() - 20);
    headerPainter.paint(canvas, Offset((canvasWidth - headerPainter.width) / 2, currentY.toDouble()));
    currentY += headerPainter.height.toInt() + 10;

    // 2. Product Name
    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: productName,
        style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
    namePainter.layout(maxWidth: canvasWidth.toDouble() - 20);
    namePainter.paint(canvas, Offset((canvasWidth - namePainter.width) / 2, currentY.toDouble()));
    currentY += namePainter.height.toInt() + 12;

    // 3. Render Code 128 Barcode Image (Solid Black Rectangles for 100% Crisp Scan)
    final List<bool> bits = encodeCode128B(barcode);
    const double moduleWidth = 2.5;
    final double totalBarcodeWidth = bits.length * moduleWidth;
    final double startX = (canvasWidth - totalBarcodeWidth) / 2;
    const double barcodeHeight = 70.0;

    final ui.Paint barPaint = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.fill;

    for (int i = 0; i < bits.length; i++) {
      if (bits[i]) {
        final double x = startX + (i * moduleWidth);
        canvas.drawRect(
          ui.Rect.fromLTWH(x, currentY.toDouble(), moduleWidth, barcodeHeight),
          barPaint,
        );
      }
    }
    currentY += barcodeHeight.toInt() + 8;

    // 4. Barcode Text (Numbers)
    final TextPainter barcodePainter = TextPainter(
      text: TextSpan(
        text: barcode,
        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2.0),
      ),
      textDirection: TextDirection.ltr,
    );
    barcodePainter.layout(maxWidth: canvasWidth.toDouble() - 20);
    barcodePainter.paint(canvas, Offset((canvasWidth - barcodePainter.width) / 2, currentY.toDouble()));
    currentY += barcodePainter.height.toInt() + 8;

    // 5. Sale Price + Currency
    final String priceText = isArabic
        ? 'السعر: ${PrinterBase.formatCurrency(salePrice)} $currencySymbol'
        : 'Price: ${PrinterBase.formatCurrency(salePrice)} $currencySymbol';
    final TextPainter pricePainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
    pricePainter.layout(maxWidth: canvasWidth.toDouble() - 20);
    pricePainter.paint(canvas, Offset((canvasWidth - pricePainter.width) / 2, currentY.toDouble()));

    // Finalize Canvas to Byte Image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(canvasWidth, canvasHeight);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) return [];
    return PrinterBase.convertRgbaToRasterBytes(byteData.buffer.asUint8List(), canvasWidth, canvasHeight);
  }

  /// Generates direct ESC/POS byte sequence for Bluetooth & Thermal Direct printers
  static Future<List<int>> generateEscPosBarcodeBytes(
    Map<String, dynamic> product,
    Map<String, dynamic>? companySettings, {
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final rasterBytes = await generateCanvasRasterBytes(product, companySettings, paperSize: paperSize, isArabic: isArabic);
    if (rasterBytes.isNotEmpty) {
      bytes.addAll(rasterBytes);
    }
    return bytes;
  }

  /// Native Sunmi Printer Execution for Barcode Labels (Physical Barcode Lines via Code 128)
  static Future<void> printSunmiBarcodeLabel({
    required Map<String, dynamic> product,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) async {
    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      final String companyName = companySettings?['CompanyName']?.toString().trim() ?? (isArabic ? 'شركة الخضار والفاكهة' : 'Vegtablity POS');
      final String productName = PrinterBase.getProductName(product, isArabic: isArabic);
      final String barcode = product['Barcode']?.toString().trim() ?? product['barcode']?.toString().trim() ?? '000000';
      final double salePrice = double.tryParse(product['SalePrice']?.toString() ?? product['saleprice']?.toString() ?? '0') ?? 0.0;
      final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);
      final String sep = PrinterBase.getSeparator(paperSize);
      final String dSep = PrinterBase.getDashedSeparator(paperSize);

      // 1. Header & Company Name
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      // 2. Product Name
      await SunmiPrinter.printText(productName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      // 3. Print Native Sunmi QR / Barcode Symbol & Text
      try {
        await SunmiPrinter.printQRCode(barcode);
      } catch (e) {
        if (kDebugMode) print('Sunmi printQRCode error: $e');
      }
      await SunmiPrinter.printText('* $barcode *', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));

      // 4. Sale Price & Currency
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      final String priceText = isArabic
          ? 'السعر: ${PrinterBase.formatCurrency(salePrice)} $cSymbol'
          : 'Price: ${PrinterBase.formatCurrency(salePrice)} $cSymbol';
      await SunmiPrinter.printText(priceText, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      // Line wrap & cut paper
      await SunmiPrinter.lineWrap(2);
      try { await SunmiPrinter.cutPaper(); } catch (_) { try { await SunmiPrinter.cut(); } catch (_) {} }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error in printSunmiBarcodeLabel: $e');
    }
  }
}
