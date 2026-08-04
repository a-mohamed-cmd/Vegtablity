export 'printing/printer_base.dart';
export 'printing/invoice_print_designer.dart';
export 'printing/shift_report_print_designer.dart';
export 'printing/voucher_print_designer.dart';
export 'printing/recipe_print_designer.dart';
export 'printing/inventory_print_designer.dart';

import 'printing/invoice_print_designer.dart';
import 'printing/shift_report_print_designer.dart';
import 'printing/voucher_print_designer.dart';
import 'printing/recipe_print_designer.dart';

/// Legacy ReceiptDesigner Facade for backward compatibility
class ReceiptDesigner {
  static Future<List<int>> buildNetworkInvoiceBytes({
    required Map<String, dynamic> invoice,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) => InvoicePrintDesigner.buildInvoicePrintBytes(
    invoice: invoice,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
    networkPrintMode: networkPrintMode,
  );

  static Future<void> printSunmiInvoice({
    required Map<String, dynamic> invoice,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) => InvoicePrintDesigner.printSunmiInvoice(
    invoice: invoice,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
  );

  static Future<List<int>> buildNetworkShiftReportBytes({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) => ShiftReportPrintDesigner.buildShiftReportBytes(
    summary: summary,
    salesInvoices: salesInvoices,
    purchaseInvoices: purchaseInvoices,
    endingCash: endingCash,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
    networkPrintMode: networkPrintMode,
  );

  static Future<void> printSunmiShiftReport({
    required Map<String, dynamic> summary,
    List<dynamic>? salesInvoices,
    List<dynamic>? purchaseInvoices,
    double? endingCash,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
  }) => ShiftReportPrintDesigner.printSunmiShiftReport(
    summary: summary,
    salesInvoices: salesInvoices,
    purchaseInvoices: purchaseInvoices,
    endingCash: endingCash,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
  );

  static Future<void> printSunmiVoucher({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) => VoucherPrintDesigner.printSunmiVoucher(
    voucher: voucher,
    paidInvoices: paidInvoices,
    companySettings: companySettings,
    paperSize: paperSize,
    isArabic: isArabic,
  );

  static Future<List<int>> buildNetworkVoucherBytes({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> paidInvoices,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) => VoucherPrintDesigner.buildVoucherBytes(
    voucher: voucher,
    paidInvoices: paidInvoices,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
    networkPrintMode: networkPrintMode,
  );

  static Future<void> printRecipeReceipt({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    bool isArabic = true,
  }) => RecipePrintDesigner.printSunmiRecipe(
    recipe: recipe,
    companySettings: companySettings,
    paperSize: paperSize,
    isArabic: isArabic,
  );

  static Future<List<int>> buildNetworkRecipeBytes({
    required Map<String, dynamic> recipe,
    Map<String, dynamic>? companySettings,
    int paperSize = 80,
    String? openWarehouseName,
    bool isArabic = true,
    String networkPrintMode = 'direct',
  }) => RecipePrintDesigner.buildRecipeBytes(
    recipe: recipe,
    companySettings: companySettings,
    paperSize: paperSize,
    openWarehouseName: openWarehouseName,
    isArabic: isArabic,
    networkPrintMode: networkPrintMode,
  );
}
