import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'printer_base.dart';

/// Unified Print Designer for Sales and Purchase Invoices (فواتير المبيعات والمشتريات)
class InvoicePrintDesigner {
  static double _parseNum(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  static String _formatPaymentAccountName(dynamic rawName, double paidAmount, bool isArabic) {
    final name = rawName?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      final lower = name.toLowerCase();
      if (lower == 'cash' || lower == 'csh') {
        return isArabic ? 'نقداً' : 'Cash';
      }
      return name;
    }
    if (paidAmount > 0) {
      return isArabic ? 'نقداً' : 'Cash';
    }
    return isArabic ? 'آجل' : 'Credit';
  }

  // =========================================================================
  // SECTION 1: DEFAULT & BLUETOOTH MODE (النص المباشر والبلوتوث - الوضع التلقائي)
  // =========================================================================

  static Future<void> printSunmiInvoice({
    required Map<String, dynamic> invoice,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
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
      final String address = companySettings?['Address'] ?? (isArabic ? 'العارضيه' : 'Ardiya');
      final String phone = companySettings?['Phone'] ?? '55381505';

      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(companyName, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
      if (address.isNotEmpty) await SunmiPrinter.printText(isArabic ? 'العنوان: $address' : 'Address: $address', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      if (phone.isNotEmpty) await SunmiPrinter.printText(isArabic ? 'الهاتف: $phone' : 'Phone: $phone', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final String invType = invoice['type']?.toString() ?? 'Sales';
      final String typeName = (invType.contains('Sales') || invType == 'مبيعات' || invType == 'Sale')
          ? (isArabic ? 'مبيعات' : 'Sales')
          : (isArabic ? 'مشتريات' : 'Purchases');

      final dynamic invId = invoice['id'] ?? invoice['InvoiceID'] ?? invoice['InvID'] ?? invoice['invoice_id'];
      final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة' : 'New');
      final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName.contains('Sales') || typeName == 'مبيعات' ? (isArabic ? 'عميل نقدي' : 'Cash Customer') : (isArabic ? 'مورد نقدي' : 'Cash Supplier'));

      DateTime printDateTime;
      try {
        if (invoice['created_at'] != null) {
          printDateTime = DateTime.parse(invoice['created_at'].toString());
        } else if (invoice['InvDate'] != null) {
          printDateTime = DateTime.parse(invoice['InvDate'].toString());
        } else {
          printDateTime = DateTime.now();
        }
      } catch (_) {
        printDateTime = DateTime.now();
      }

      final String shortDate = '${printDateTime.year}-${printDateTime.month.toString().padLeft(2, '0')}-${printDateTime.day.toString().padLeft(2, '0')}';
      final String timeStr = '${printDateTime.hour.toString().padLeft(2, '0')}:${printDateTime.minute.toString().padLeft(2, '0')}:${printDateTime.second.toString().padLeft(2, '0')}';

      await SunmiPrinter.printText(isArabic ? 'فاتورة $typeName جديدة' : 'New $typeName Invoice', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      }
      await SunmiPrinter.printText(isArabic ? 'رقم الفاتورة: $invIdStr' : 'Invoice No: $invIdStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'العميل/المورد: $partnerName' : 'Partner: $partnerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      await SunmiPrinter.printText(isArabic ? 'التاريخ والوقت: $shortDate $timeStr' : 'Date & Time: $shortDate $timeStr', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));

      // Shipping & Delivery Details
      final String? tempCustomerName = invoice['temp_customer_name'] ?? invoice['TempCustomerName'] ?? invoice['tempCustomerName'];
      final String? tempPhone        = invoice['temp_phone'] ?? invoice['TempPhone'] ?? invoice['tempPhone'];
      final String? tempAddress      = invoice['temp_address'] ?? invoice['TempAddress'] ?? invoice['tempAddress'];
      final String? tempDeliveryDate = invoice['temp_delivery_date'] ?? invoice['TempDeliveryDate'] ?? invoice['tempDeliveryDate'];
      final String? tempDeliveryTime = invoice['temp_delivery_time'] ?? invoice['TempDeliveryTime'] ?? invoice['tempDeliveryTime'];
      final String? tempNotes        = invoice['temp_notes'] ?? invoice['TempNotes'] ?? invoice['notes'] ?? invoice['Notes'];

      final bool hasDeliveryInfo = (tempCustomerName != null && tempCustomerName.isNotEmpty) ||
          (tempPhone != null && tempPhone.isNotEmpty) ||
          (tempAddress != null && tempAddress.isNotEmpty) ||
          (tempNotes != null && tempNotes.isNotEmpty);

      if (hasDeliveryInfo) {
        await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
        await SunmiPrinter.printText(isArabic ? '*** بيانات التوصيل والشحن ***' : '*** DELIVERY & SHIPPING INFO ***', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
        if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'اسم المستلم: $tempCustomerName' : 'Recipient: $tempCustomerName', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        if (tempPhone != null && tempPhone.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'هاتف المستلم: $tempPhone' : 'Phone: $tempPhone', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        if (tempAddress != null && tempAddress.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'عنوان التوصيل: $tempAddress' : 'Address: $tempAddress', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'تاريخ الشحن: $tempDeliveryDate' : 'Delivery Date: $tempDeliveryDate', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'وقت الشحن: $tempDeliveryTime' : 'Delivery Time: $tempDeliveryTime', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
        if (tempNotes != null && tempNotes.isNotEmpty) {
          await SunmiPrinter.printText(isArabic ? 'ملاحظات التوصيل: $tempNotes' : 'Delivery Notes: $tempNotes', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
      }

      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List items = (invoice['items'] ?? invoice['InvoiceDetails'] ?? invoice['Details'] ?? []) as List;
      double calculatedTotal = 0.0;
      for (var item in items) {
        final String name = PrinterBase.getProductName(item, isArabic: isArabic);
        final double qty = double.tryParse(item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
        final double price = double.tryParse(item['UnitPrice']?.toString() ?? item['Price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
        final double total = double.tryParse(item['TotalPrice']?.toString() ?? item['Total']?.toString() ?? item['total']?.toString() ?? (qty * price).toString()) ?? (qty * price);
        final double itemDiscount = double.tryParse(item['discountAmount']?.toString() ?? item['DiscountAmount']?.toString() ?? '0') ?? 0.0;
        final String unitName = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? item['Unit'] ?? item['unit_symbol'] ?? item['UnitSymbol'] ?? '';
        calculatedTotal += total;

        await SunmiPrinter.printText(name, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        await SunmiPrinter.printText('  ${PrinterBase.formatQuantity(qty, unitName)} x ${PrinterBase.formatCurrency(price)} = ${PrinterBase.formatCurrency(total)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        if (itemDiscount > 0) {
          final String discLabel = isArabic ? 'خصم الصنف' : 'Item Discount';
          await SunmiPrinter.printText('  ($discLabel: -${PrinterBase.formatCurrency(itemDiscount)})', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
      }

      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final double netAmount          = _parseNum(invoice['total_amount'] ?? invoice['NetAmount'] ?? invoice['TotalAmount'], calculatedTotal);
      final double totalDiscount     = _parseNum(invoice['total_discount'] ?? invoice['TotalDiscount'] ?? invoice['discount_amount'] ?? invoice['Discount']);
      final double originalTotal     = _parseNum(invoice['original_total'] ?? invoice['OriginalTotal'], netAmount + totalDiscount);
      final double paidAtCreate       = _parseNum(invoice['paid_amount'] ?? invoice['PaidAmount']);
      final double voucherPaidAmount  = _parseNum(invoice['voucher_paid_amount'] ?? invoice['VoucherPaidAmount']);
      final double remainder          = _parseNum(invoice['remainder'] ?? invoice['Remainder']);
      final double totalPaid = paidAtCreate + voucherPaidAmount;

      if (totalDiscount > 0) {
        await SunmiPrinter.printText(isArabic ? 'الإجمالي: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol' : 'Gross Total: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        await SunmiPrinter.printText(isArabic ? 'الخصم: -${PrinterBase.formatCurrency(totalDiscount)}' : 'Discount: -${PrinterBase.formatCurrency(totalDiscount)}', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      }
      await SunmiPrinter.printText(isArabic ? 'الصافي (Net Total): ${PrinterBase.formatCurrency(netAmount)} $cSymbol' : 'Net Total: ${PrinterBase.formatCurrency(netAmount)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      await SunmiPrinter.printText(dSep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      final List splits = (invoice['PaymentSplits'] ?? invoice['payment_splits'] ?? []) as List;
      final String rawAccName = (invoice['PaymentAccountName'] ?? invoice['AccountName'] ?? invoice['payment_account_name'] ?? invoice['PaymentMethodName'] ?? '').toString().trim();

      if (splits.isNotEmpty) {
        await SunmiPrinter.printText(isArabic ? '--- وسائل الدفع ---' : '--- Payment Methods ---', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
        for (var s in splits) {
          final String rawSName = (s['PaymentMethodName'] ?? s['AccountName'] ?? s['PaymentAccountName'] ?? '').toString().trim();
          final double sAmt = double.tryParse(s['Amount']?.toString() ?? '0') ?? 0.0;
          final String sName = _formatPaymentAccountName(rawSName, sAmt, isArabic);
          await SunmiPrinter.printText('• $sName: ${PrinterBase.formatCurrency(sAmt)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
        }
      } else {
        final String displayMethod = _formatPaymentAccountName(rawAccName, totalPaid, isArabic);
        await SunmiPrinter.printText(isArabic ? 'طريقة الدفع: $displayMethod' : 'Payment Method: $displayMethod', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      }

      await SunmiPrinter.printText(isArabic ? 'إجمالي المدفوع: ${PrinterBase.formatCurrency(totalPaid)} $cSymbol' : 'Total Paid: ${PrinterBase.formatCurrency(totalPaid)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT));
      if (remainder > 0.001) {
        await SunmiPrinter.printText(isArabic ? 'المتبقي آجل: ${PrinterBase.formatCurrency(remainder)} $cSymbol' : 'Balance Due: ${PrinterBase.formatCurrency(remainder)} $cSymbol', style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true));
      }
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(isArabic ? 'شكراً لزيارتكم! طُبعت عبر نظام POS' : 'Thank you for your visit! Printed via POS System', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(sep, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(3);
      try { await SunmiPrinter.cutPaper(); } catch (_) { await SunmiPrinter.cut(); }
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('Error printing Sunmi invoice: $e');
    }
  }

  static Future<List<int>> buildDirectTextInvoiceBytes({
    required Map<String, dynamic> invoice,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) async {
    final List<int> bytes = [];
    final String sep = PrinterBase.getSeparator(paperSize);
    final String dSep = PrinterBase.getDashedSeparator(paperSize);
    final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);

    bytes.addAll(PrinterBase.getDrawerKickBytes());
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

    final String invType = invoice['type']?.toString() ?? 'Sales';
    final String typeName = (invType.contains('Sales') || invType == 'مبيعات' || invType == 'Sale')
        ? (isArabic ? 'مبيعات' : 'Sales')
        : (isArabic ? 'مشتريات' : 'Purchases');

    final dynamic invId = invoice['id'] ?? invoice['InvoiceID'] ?? invoice['InvID'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة' : 'New');
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (isArabic ? 'عميل نقدي' : 'Cash Customer');

    DateTime printDateTime;
    try {
      if (invoice['created_at'] != null) {
        printDateTime = DateTime.parse(invoice['created_at'].toString());
      } else if (invoice['InvDate'] != null) {
        printDateTime = DateTime.parse(invoice['InvDate'].toString());
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
    bytes.addAll(isArabic ? 'العميل/المورد: $partnerName\n'.codeUnits : 'Partner: $partnerName\n'.codeUnits);
    bytes.addAll(isArabic ? 'التاريخ والوقت: $shortDate $timeStr\n'.codeUnits : 'Date & Time: $shortDate $timeStr\n'.codeUnits);

    // Shipping & Delivery Details
    final String? tempCustomerName = invoice['temp_customer_name'] ?? invoice['TempCustomerName'] ?? invoice['tempCustomerName'];
    final String? tempPhone        = invoice['temp_phone'] ?? invoice['TempPhone'] ?? invoice['tempPhone'];
    final String? tempAddress      = invoice['temp_address'] ?? invoice['TempAddress'] ?? invoice['tempAddress'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'] ?? invoice['TempDeliveryDate'] ?? invoice['tempDeliveryDate'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'] ?? invoice['TempDeliveryTime'] ?? invoice['tempDeliveryTime'];
    final String? tempNotes        = invoice['temp_notes'] ?? invoice['TempNotes'] ?? invoice['notes'] ?? invoice['Notes'];

    final bool hasDeliveryInfo = (tempCustomerName != null && tempCustomerName.isNotEmpty) ||
        (tempPhone != null && tempPhone.isNotEmpty) ||
        (tempAddress != null && tempAddress.isNotEmpty) ||
        (tempNotes != null && tempNotes.isNotEmpty);

    if (hasDeliveryInfo) {
      bytes.addAll('$dSep\n'.codeUnits);
      bytes.addAll(isArabic ? '  *** بيانات التوصيل والشحن ***\n'.codeUnits : '  *** DELIVERY & SHIPPING INFO ***\n'.codeUnits);
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        bytes.addAll(isArabic ? 'اسم المستلم: $tempCustomerName\n'.codeUnits : 'Recipient: $tempCustomerName\n'.codeUnits);
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        bytes.addAll(isArabic ? 'هاتف المستلم: $tempPhone\n'.codeUnits : 'Phone: $tempPhone\n'.codeUnits);
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        bytes.addAll(isArabic ? 'عنوان التوصيل: $tempAddress\n'.codeUnits : 'Address: $tempAddress\n'.codeUnits);
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        bytes.addAll(isArabic ? 'تاريخ الشحن: $tempDeliveryDate\n'.codeUnits : 'Delivery Date: $tempDeliveryDate\n'.codeUnits);
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        bytes.addAll(isArabic ? 'وقت الشحن: $tempDeliveryTime\n'.codeUnits : 'Delivery Time: $tempDeliveryTime\n'.codeUnits);
      }
      if (tempNotes != null && tempNotes.isNotEmpty) {
        bytes.addAll(isArabic ? 'ملاحظات التوصيل: $tempNotes\n'.codeUnits : 'Delivery Notes: $tempNotes\n'.codeUnits);
      }
    }

    bytes.addAll('$dSep\n'.codeUnits);

    final List items = (invoice['items'] ?? invoice['InvoiceDetails'] ?? invoice['Details'] ?? []) as List;
    for (var item in items) {
      final String name = PrinterBase.getProductName(item, isArabic: isArabic);
      final double qty = double.tryParse(item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
      final double price = double.tryParse(item['UnitPrice']?.toString() ?? item['Price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
      final double total = double.tryParse(item['TotalPrice']?.toString() ?? item['Total']?.toString() ?? item['total']?.toString() ?? (qty * price).toString()) ?? (qty * price);
      final String unitName = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? item['Unit'] ?? item['unit_symbol'] ?? item['UnitSymbol'] ?? '';

      final double itemDiscount = double.tryParse(item['discountAmount']?.toString() ?? item['DiscountAmount']?.toString() ?? '0') ?? 0.0;

      bytes.addAll('$name\n'.codeUnits);
      bytes.addAll('  ${PrinterBase.formatQuantity(qty, unitName)} x ${PrinterBase.formatCurrency(price)} = ${PrinterBase.formatCurrency(total)}\n'.codeUnits);
      if (itemDiscount > 0) {
        final String discLabel = isArabic ? 'خصم الصنف' : 'Item Discount';
        bytes.addAll('  ($discLabel: -${PrinterBase.formatCurrency(itemDiscount)})\n'.codeUnits);
      }
    }
    bytes.addAll('$dSep\n'.codeUnits);

    final double netAmount      = _parseNum(invoice['total_amount'] ?? invoice['NetAmount'] ?? invoice['TotalAmount']);
    final double totalDiscount = _parseNum(invoice['total_discount'] ?? invoice['TotalDiscount'] ?? invoice['discount_amount'] ?? invoice['Discount']);
    final double originalTotal = _parseNum(invoice['original_total'] ?? invoice['OriginalTotal'], netAmount + totalDiscount);
    final double paidAmount    = _parseNum(invoice['paid_amount'] ?? invoice['PaidAmount']);
    final double remainder     = _parseNum(invoice['remainder'] ?? invoice['Remainder']);
    final List splits = (invoice['PaymentSplits'] ?? invoice['payment_splits'] ?? []) as List;
    final String rawAccName = (invoice['PaymentAccountName'] ?? invoice['AccountName'] ?? invoice['payment_account_name'] ?? invoice['PaymentMethodName'] ?? '').toString().trim();

    if (totalDiscount > 0) {
      bytes.addAll(isArabic ? 'الإجمالي: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol\n'.codeUnits : 'Gross Total: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol\n'.codeUnits);
      bytes.addAll(isArabic ? 'الخصم: -${PrinterBase.formatCurrency(totalDiscount)}\n'.codeUnits : 'Discount: -${PrinterBase.formatCurrency(totalDiscount)}\n'.codeUnits);
    }
    bytes.addAll(isArabic ? 'الصافي (Net Total): ${PrinterBase.formatCurrency(netAmount)} $cSymbol\n'.codeUnits : 'Net Total: ${PrinterBase.formatCurrency(netAmount)} $cSymbol\n'.codeUnits);
    bytes.addAll('$dSep\n'.codeUnits);

    if (splits.isNotEmpty) {
      bytes.addAll(isArabic ? '--- وسائل الدفع ---\n'.codeUnits : '--- Payment Methods ---\n'.codeUnits);
      for (var s in splits) {
        final String rawSName = (s['PaymentMethodName'] ?? s['AccountName'] ?? s['PaymentAccountName'] ?? '').toString().trim();
        final double sAmt = double.tryParse(s['Amount']?.toString() ?? '0') ?? 0.0;
        final String sName = _formatPaymentAccountName(rawSName, sAmt, isArabic);
        bytes.addAll('• $sName: ${PrinterBase.formatCurrency(sAmt)} $cSymbol\n'.codeUnits);
      }
    } else {
      final String displayMethod = _formatPaymentAccountName(rawAccName, paidAmount, isArabic);
      bytes.addAll(isArabic ? 'طريقة الدفع: $displayMethod\n'.codeUnits : 'Payment Method: $displayMethod\n'.codeUnits);
    }

    bytes.addAll(isArabic ? 'إجمالي المدفوع: ${PrinterBase.formatCurrency(paidAmount)} $cSymbol\n'.codeUnits : 'Total Paid: ${PrinterBase.formatCurrency(paidAmount)} $cSymbol\n'.codeUnits);
    if (remainder > 0.001) {
      bytes.addAll(isArabic ? 'المتبقي آجل: ${PrinterBase.formatCurrency(remainder)} $cSymbol\n'.codeUnits : 'Balance Due: ${PrinterBase.formatCurrency(remainder)} $cSymbol\n'.codeUnits);
    }

    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(isArabic ? 'شكراً لزيارتكم! طُبعت عبر نظام POS\n'.codeUnits : 'Thank you for your visit! Printed via POS System\n'.codeUnits);
    bytes.addAll('$sep\n'.codeUnits);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  // =========================================================================
  // SECTION 2: CANVA & RASTER NETWORK MODE (إعدادات CANVA والنص المباشر Network)
  // =========================================================================

  static Future<List<int>> renderInvoiceToCanvasEscPos({
    required Map<String, dynamic> invoice,
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
        if (kDebugMode) print('Error processing logo in invoice canvas: $e');
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

    final String invType = invoice['type']?.toString() ?? 'Sales';
    final String typeName = (invType.contains('Sales') || invType == 'مبيعات' || invType == 'Sale')
        ? (isArabic ? 'مبيعات' : 'Sales')
        : (isArabic ? 'مشتريات' : 'Purchases');

    final dynamic invId = invoice['id'] ?? invoice['InvoiceID'] ?? invoice['InvID'] ?? invoice['invoice_id'];
    final String invIdStr = invId != null && invId != 0 ? '#$invId' : (isArabic ? 'جديدة' : 'New');
    final String partnerName = invoice['PartnerName'] ?? invoice['partner_name'] ?? (typeName.contains('Sales') || typeName == 'مبيعات' ? (isArabic ? 'عميل نقدي' : 'Cash Customer') : (isArabic ? 'مورد نقدي' : 'Cash Supplier'));

    DateTime printDateTime;
    try {
      if (invoice['created_at'] != null) {
        printDateTime = DateTime.parse(invoice['created_at'].toString());
      } else if (invoice['InvDate'] != null) {
        printDateTime = DateTime.parse(invoice['InvDate'].toString());
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

    addText(isArabic ? 'فاتورة $typeName جديدة' : 'New $typeName Invoice', bold: true, fontSize: headerSize);
    if (openWarehouseName != null && openWarehouseName.isNotEmpty) {
      addText(isArabic ? 'المستودع: $openWarehouseName' : 'Warehouse: $openWarehouseName', fontSize: bodySize);
    }
    addText(isArabic ? 'رقم الفاتورة: $invIdStr' : 'Invoice No: $invIdStr', fontSize: bodySize);
    addText(isArabic ? 'العميل/المورد: $partnerName' : 'Partner: $partnerName', fontSize: bodySize);
    addText(isArabic ? 'التاريخ والوقت: $shortDate $timeStr ($dayName)' : 'Date & Time: $shortDate $timeStr ($dayName)', fontSize: smallSize);
    addText(isArabic ? 'نوع العملية: $typeName' : 'Operation Type: $typeName', fontSize: smallSize);

    // Shipping & Delivery Details
    final String? tempCustomerName = invoice['temp_customer_name'] ?? invoice['TempCustomerName'] ?? invoice['tempCustomerName'];
    final String? tempPhone        = invoice['temp_phone'] ?? invoice['TempPhone'] ?? invoice['tempPhone'];
    final String? tempAddress      = invoice['temp_address'] ?? invoice['TempAddress'] ?? invoice['tempAddress'];
    final String? tempDeliveryDate = invoice['temp_delivery_date'] ?? invoice['TempDeliveryDate'] ?? invoice['tempDeliveryDate'];
    final String? tempDeliveryTime = invoice['temp_delivery_time'] ?? invoice['TempDeliveryTime'] ?? invoice['tempDeliveryTime'];
    final String? tempNotes        = invoice['temp_notes'] ?? invoice['TempNotes'] ?? invoice['notes'] ?? invoice['Notes'];

    final bool hasDeliveryInfo = (tempCustomerName != null && tempCustomerName.isNotEmpty) ||
        (tempPhone != null && tempPhone.isNotEmpty) ||
        (tempAddress != null && tempAddress.isNotEmpty) ||
        (tempNotes != null && tempNotes.isNotEmpty);

    if (hasDeliveryInfo) {
      addDivider(dashed: true);
      addText(isArabic ? '*** بيانات التوصيل والشحن ***' : '*** DELIVERY & SHIPPING INFO ***', bold: true, fontSize: headerSize);
      if (tempCustomerName != null && tempCustomerName.isNotEmpty) {
        addText(isArabic ? 'اسم المستلم: $tempCustomerName' : 'Recipient: $tempCustomerName', fontSize: bodySize);
      }
      if (tempPhone != null && tempPhone.isNotEmpty) {
        addText(isArabic ? 'هاتف المستلم: $tempPhone' : 'Phone: $tempPhone', fontSize: bodySize);
      }
      if (tempAddress != null && tempAddress.isNotEmpty) {
        addText(isArabic ? 'عنوان التوصيل: $tempAddress' : 'Address: $tempAddress', fontSize: bodySize);
      }
      if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty) {
        addText(isArabic ? 'تاريخ الشحن: $tempDeliveryDate' : 'Delivery Date: $tempDeliveryDate', fontSize: smallSize);
      }
      if (tempDeliveryTime != null && tempDeliveryTime.isNotEmpty) {
        addText(isArabic ? 'وقت الشحن: $tempDeliveryTime' : 'Delivery Time: $tempDeliveryTime', fontSize: smallSize);
      }
      if (tempNotes != null && tempNotes.isNotEmpty) {
        addText(isArabic ? 'ملاحظات التوصيل: $tempNotes' : 'Delivery Notes: $tempNotes', fontSize: bodySize);
      }
    }
    addDivider(dashed: true);

    // Items Section
    final List items = (invoice['items'] ?? invoice['InvoiceDetails'] ?? invoice['Details'] ?? []) as List;
    final String cSymbol = PrinterBase.getCurrencySymbol(companySettings, isArabic: isArabic);
    double calculatedTotal = 0.0;

    for (var item in items) {
      final String name = PrinterBase.getProductName(item, isArabic: isArabic);
      final double qty = double.tryParse(item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
      final double price = double.tryParse(item['UnitPrice']?.toString() ?? item['Price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
      final double total = double.tryParse(item['TotalPrice']?.toString() ?? item['Total']?.toString() ?? item['total']?.toString() ?? (qty * price).toString()) ?? (qty * price);
      final String unitName = item['UnitName'] ?? item['unit_name'] ?? item['unit'] ?? item['Unit'] ?? item['unit_symbol'] ?? item['UnitSymbol'] ?? '';
      final String qtyFormatted = PrinterBase.formatQuantity(qty, unitName);
      calculatedTotal += total;

      final double itemDiscount = double.tryParse(item['discountAmount']?.toString() ?? item['DiscountAmount']?.toString() ?? '0') ?? 0.0;

      addText(name, bold: true, fontSize: headerSize);
      addText('  $qtyFormatted x ${PrinterBase.formatCurrency(price)} = ${PrinterBase.formatCurrency(total)}', fontSize: bodySize);
      if (itemDiscount > 0) {
        final String discLabel = isArabic ? 'خصم الصنف' : 'Item Discount';
        addText('  ($discLabel: -${PrinterBase.formatCurrency(itemDiscount)})', fontSize: smallSize);
      }
    }
    addDivider(dashed: true);

    // Totals & Payment Section
    final double netAmount          = _parseNum(invoice['total_amount'] ?? invoice['NetAmount'] ?? invoice['TotalAmount'], calculatedTotal);
    final double totalDiscount     = _parseNum(invoice['total_discount'] ?? invoice['TotalDiscount'] ?? invoice['discount_amount'] ?? invoice['Discount']);
    final double originalTotal     = _parseNum(invoice['original_total'] ?? invoice['OriginalTotal'], netAmount + totalDiscount);
    final double totalPaid          = _parseNum(invoice['paid_amount'] ?? invoice['PaidAmount']);
    final double remainder          = _parseNum(invoice['remainder'] ?? invoice['Remainder']);

    final String formattedPaid      = PrinterBase.formatCurrency(totalPaid);
    final String formattedRemainder = PrinterBase.formatCurrency(remainder);

    final List splits = (invoice['PaymentSplits'] ?? invoice['payment_splits'] ?? []) as List;
    final String rawAccName = (invoice['PaymentAccountName'] ?? invoice['AccountName'] ?? invoice['payment_account_name'] ?? invoice['PaymentMethodName'] ?? '').toString().trim();

    if (totalDiscount > 0) {
      addText(isArabic ? 'الإجمالي: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol' : 'Gross Total: ${PrinterBase.formatCurrency(originalTotal)} $cSymbol', fontSize: bodySize);
      addText(isArabic ? 'الخصم: -${PrinterBase.formatCurrency(totalDiscount)}' : 'Discount: -${PrinterBase.formatCurrency(totalDiscount)}', bold: true, fontSize: bodySize);
    }
    addText(isArabic ? 'الصافي (Net Total): ${PrinterBase.formatCurrency(netAmount)} $cSymbol' : 'Net Total: ${PrinterBase.formatCurrency(netAmount)} $cSymbol', bold: true, fontSize: headerSize);
    addDivider(dashed: true);

    if (splits.isNotEmpty) {
      addText(isArabic ? '--- وسائل الدفع ---' : '--- Payment Methods ---', bold: true, fontSize: bodySize);
      for (var s in splits) {
        final String rawSName = (s['PaymentMethodName'] ?? s['AccountName'] ?? s['PaymentAccountName'] ?? '').toString().trim();
        final double sAmt = double.tryParse(s['Amount']?.toString() ?? '0') ?? 0.0;
        final String sName = _formatPaymentAccountName(rawSName, sAmt, isArabic);
        addText('• $sName: ${PrinterBase.formatCurrency(sAmt)} $cSymbol', fontSize: bodySize);
      }
    } else {
      final String displayMethod = _formatPaymentAccountName(rawAccName, totalPaid, isArabic);
      addText(isArabic ? 'طريقة الدفع: $displayMethod' : 'Payment Method: $displayMethod', bold: true, fontSize: bodySize);
    }

    addText(isArabic ? 'إجمالي المدفوع: $formattedPaid $cSymbol' : 'Total Paid: $formattedPaid $cSymbol', fontSize: bodySize);
    if (remainder > 0.001) {
      addText(isArabic ? 'المتبقي آجل: $formattedRemainder $cSymbol' : 'Balance Due: $formattedRemainder $cSymbol', bold: true, fontSize: headerSize, color: const ui.Color(0xFF8B0000));
    }
    addDivider();

    // Footer
    addText(isArabic ? 'شكراً لزيارتكم! طُبعت عبر نظام POS' : 'Thank you for your visit! Printed via POS System', fontSize: bodySize, align: ui.TextAlign.center);
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

  // =========================================================================
  // MAIN ENTRY DISPATCHER
  // =========================================================================

  static Future<List<int>> buildInvoicePrintBytes({
    required Map<String, dynamic> invoice,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) async {
    if (networkPrintMode == 'raster') {
      return await renderInvoiceToCanvasEscPos(
        invoice: invoice,
        companySettings: companySettings,
        paperSize: paperSize,
        openWarehouseName: openWarehouseName,
        isArabic: isArabic,
      );
    }
    return await buildDirectTextInvoiceBytes(
      invoice: invoice,
      companySettings: companySettings,
      paperSize: paperSize,
      openWarehouseName: openWarehouseName,
      isArabic: isArabic,
    );
  }
}
