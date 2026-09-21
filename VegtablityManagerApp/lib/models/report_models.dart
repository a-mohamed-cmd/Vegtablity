double _asDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) {
    return double.tryParse(val) ?? fallback;
  }
  return fallback;
}

int _asInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) {
    return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? fallback);
  }
  return fallback;
}

// 1. أرباح الأصناف
class ProductProfitModel {
  final int? productID;
  final String productCode;
  final String productName;
  final String categoryName;
  final double quantitySold;
  final double totalSales;
  final double totalCost;
  final double totalProfit;
  final double profitMargin;

  ProductProfitModel({
    this.productID,
    required this.productCode,
    required this.productName,
    required this.categoryName,
    required this.quantitySold,
    required this.totalSales,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
  });

  factory ProductProfitModel.fromJson(Map<String, dynamic> json) {
    final qty = _asDouble(json['TotalQtySold'] ?? json['QuantitySold'] ?? json['Quantity']);
    final sales = _asDouble(json['TotalRevenue'] ?? json['TotalSales']);
    final cost = _asDouble(json['TotalCost']);
    final profit = json.containsKey('NetProfit') || json.containsKey('TotalProfit')
        ? _asDouble(json['NetProfit'] ?? json['TotalProfit'])
        : (sales - cost);
    final margin = json.containsKey('ProfitMarginPercent') || json.containsKey('ProfitMargin')
        ? _asDouble(json['ProfitMarginPercent'] ?? json['ProfitMargin'])
        : (sales > 0 ? (profit / sales) * 100 : 0.0);

    return ProductProfitModel(
      productID: _asInt(json['ProductID']),
      productCode: json['Barcode']?.toString() ?? json['ProductCode']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      categoryName: json['UnitName']?.toString() ?? json['CatName']?.toString() ?? json['CategoryName']?.toString() ?? '',
      quantitySold: qty,
      totalSales: sales,
      totalCost: cost,
      totalProfit: profit,
      profitMargin: margin,
    );
  }
}

// 2. أرباح الفواتير
class InvoiceProfitModel {
  final int invoiceID;
  final String invoiceNumber;
  final String invoiceDate;
  final String customerName;
  final String cashierName;
  final double netTotal;
  final double totalCost;
  final double totalProfit;
  final double profitMargin;

  InvoiceProfitModel({
    required this.invoiceID,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    required this.cashierName,
    required this.netTotal,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
  });

  factory InvoiceProfitModel.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['InvID'] ?? json['InvoiceID']);
    final sales = _asDouble(json['NetAmount'] ?? json['NetTotal'] ?? json['TotalAmount']);
    final cost = _asDouble(json['TotalCost']);
    final profit = json.containsKey('NetProfit') || json.containsKey('TotalProfit')
        ? _asDouble(json['NetProfit'] ?? json['TotalProfit'])
        : (sales - cost);
    final margin = json.containsKey('ProfitMargin') || json.containsKey('ProfitMarginPercent')
        ? _asDouble(json['ProfitMargin'] ?? json['ProfitMarginPercent'])
        : (sales > 0 ? (profit / sales) * 100 : 0.0);

    return InvoiceProfitModel(
      invoiceID: id,
      invoiceNumber: id > 0 ? id.toString() : (json['InvoiceNumber']?.toString() ?? ''),
      invoiceDate: json['InvDate']?.toString() ?? json['InvoiceDate']?.toString() ?? '',
      customerName: json['CustomerName']?.toString() ?? json['PartnerName']?.toString() ?? 'عميل نقدي',
      cashierName: json['CashierName']?.toString() ?? '',
      netTotal: sales,
      totalCost: cost,
      totalProfit: profit,
      profitMargin: margin,
    );
  }
}

// 3. اتجاهات المبيعات
class SalesTrendModel {
  final String period;
  final int invoiceCount;
  final double totalSales;
  final double totalCost;
  final double totalProfit;
  final double cashTotal;
  final double cardTotal;
  final double creditTotal;

  SalesTrendModel({
    required this.period,
    required this.invoiceCount,
    required this.totalSales,
    required this.totalCost,
    required this.totalProfit,
    required this.cashTotal,
    required this.cardTotal,
    required this.creditTotal,
  });

  factory SalesTrendModel.fromJson(Map<String, dynamic> json) {
    final sales = _asDouble(json['TotalNetAmount'] ?? json['TotalSales'] ?? json['TotalGrossAmount']);
    final cost = _asDouble(json['TotalCost']);
    final profit = json.containsKey('TotalProfit') ? _asDouble(json['TotalProfit']) : (sales - cost);

    return SalesTrendModel(
      period: json['PeriodString']?.toString() ?? json['Period']?.toString() ?? json['PeriodLabel']?.toString() ?? '',
      invoiceCount: _asInt(json['InvoiceCount']),
      totalSales: sales,
      totalCost: cost,
      totalProfit: profit,
      cashTotal: _asDouble(json['TotalPaid'] ?? json['CashTotal']),
      cardTotal: _asDouble(json['CardTotal']),
      creditTotal: _asDouble(json['TotalCredit'] ?? json['CreditTotal']),
    );
  }
}

// 4. كبار العملاء
class TopCustomerModel {
  final int partnerID;
  final String partnerName;
  final String partnerPhone;
  final int invoiceCount;
  final double totalSales;
  final double totalPaid;
  final double remainingDebt;

  TopCustomerModel({
    required this.partnerID,
    required this.partnerName,
    required this.partnerPhone,
    required this.invoiceCount,
    required this.totalSales,
    required this.totalPaid,
    required this.remainingDebt,
  });

  factory TopCustomerModel.fromJson(Map<String, dynamic> json) {
    return TopCustomerModel(
      partnerID: _asInt(json['PartnerID']),
      partnerName: json['PartnerName']?.toString() ?? '',
      partnerPhone: json['Phone']?.toString() ?? json['PartnerPhone']?.toString() ?? '',
      invoiceCount: _asInt(json['TotalInvoices'] ?? json['InvoiceCount']),
      totalSales: _asDouble(json['TotalPurchases'] ?? json['TotalSales']),
      totalPaid: _asDouble(json['TotalPaid']),
      remainingDebt: _asDouble(json['TotalCreditBalance'] ?? json['RemainingDebt']),
    );
  }
}

// 5. أعمار الديون
class AgingDebtModel {
  final int invoiceID;
  final String invoiceNumber;
  final String invoiceDate;
  final String partnerName;
  final String partnerPhone;
  final double remainingAmount;
  final int daysOverdue;
  final String agingBucket;

  AgingDebtModel({
    required this.invoiceID,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.partnerName,
    required this.partnerPhone,
    required this.remainingAmount,
    required this.daysOverdue,
    required this.agingBucket,
  });

  factory AgingDebtModel.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['InvID'] ?? json['InvoiceID']);
    final days = _asInt(json['DaysOverdue'] ?? json['AgeDays']);
    String bucket = json['AgingBucket']?.toString() ?? '0-30 يوم';
    if (bucket == '1_0_to_30_Days' || bucket == '0-30 يوم') {
      bucket = '0-30 يوم';
    } else if (bucket == '2_31_to_60_Days' || bucket == '31-60 يوم') {
      bucket = '31-60 يوم';
    } else if (bucket == '3_61_to_90_Days' || bucket == '61-90 يوم') {
      bucket = '61-90 يوم';
    } else if (bucket == '4_Over_90_Days' || bucket == '90+ يوم') {
      bucket = 'أكثر من 90 يوم';
    }

    return AgingDebtModel(
      invoiceID: id,
      invoiceNumber: id > 0 ? id.toString() : (json['InvoiceNumber']?.toString() ?? ''),
      invoiceDate: json['InvDate']?.toString() ?? json['InvoiceDate']?.toString() ?? '',
      partnerName: json['CustomerName']?.toString() ?? json['PartnerName']?.toString() ?? '',
      partnerPhone: json['Phone']?.toString() ?? '',
      remainingAmount: _asDouble(json['UnpaidBalance'] ?? json['RemainingAmount'] ?? json['Remainder']),
      daysOverdue: days,
      agingBucket: bucket,
    );
  }
}

// 6. تقييم المخزون
class InventoryValuationModel {
  final int productID;
  final String productCode;
  final String productName;
  final String warehouseName;
  final double currentStock;
  final double purchasePrice;
  final double sellingPrice;
  final double totalCostValue;
  final double totalSaleValue;
  final double potentialProfit;

  InventoryValuationModel({
    required this.productID,
    required this.productCode,
    required this.productName,
    required this.warehouseName,
    required this.currentStock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.totalCostValue,
    required this.totalSaleValue,
    required this.potentialProfit,
  });

  factory InventoryValuationModel.fromJson(Map<String, dynamic> json) {
    final stock = _asDouble(json['CurrentStock'] ?? json['CurrentQty']);
    final cost = _asDouble(json['UnitCost'] ?? json['PurchasePrice']);
    final sell = _asDouble(json['UnitSellingPrice'] ?? json['SalePrice'] ?? json['SellingPrice']);
    final totCost = json.containsKey('TotalCostValue') ? _asDouble(json['TotalCostValue']) : (stock * cost);
    final totSell = json.containsKey('TotalRetailValue') || json.containsKey('TotalSaleValue')
        ? _asDouble(json['TotalRetailValue'] ?? json['TotalSaleValue'])
        : (stock * sell);

    return InventoryValuationModel(
      productID: _asInt(json['ProductID']),
      productCode: json['Barcode']?.toString() ?? json['ProductCode']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      warehouseName: json['WarehouseName']?.toString() ?? 'المخزن الرئيسي',
      currentStock: stock,
      purchasePrice: cost,
      sellingPrice: sell,
      totalCostValue: totCost,
      totalSaleValue: totSell,
      potentialProfit: (totSell - totCost),
    );
  }
}

// 7. الأصناف الراكدة
class SlowMovingStockModel {
  final int productID;
  final String productCode;
  final String productName;
  final double currentStock;
  final double purchasePrice;
  final double totalCostValue;
  final String lastSaleDate;
  final int daysInactive;

  SlowMovingStockModel({
    required this.productID,
    required this.productCode,
    required this.productName,
    required this.currentStock,
    required this.purchasePrice,
    required this.totalCostValue,
    required this.lastSaleDate,
    required this.daysInactive,
  });

  factory SlowMovingStockModel.fromJson(Map<String, dynamic> json) {
    final stock = _asDouble(json['CurrentTotalStock'] ?? json['CurrentStock']);
    final cost = _asDouble(json['PurchasePrice']);

    return SlowMovingStockModel(
      productID: _asInt(json['ProductID']),
      productCode: json['Barcode']?.toString() ?? json['ProductCode']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      currentStock: stock,
      purchasePrice: cost,
      totalCostValue: (stock * cost),
      lastSaleDate: json['LastSoldDate']?.toString() ?? json['LastSaleDate']?.toString() ?? 'لا توجد مبيعات',
      daysInactive: _asInt(json['DaysSinceLastSale'] ?? json['DaysInactive']),
    );
  }
}

// 8. تحليل المصروفات
class ExpensesAnalysisModel {
  final String accountCode;
  final String accountName;
  final String category;
  final double totalAmount;
  final int voucherCount;
  final double percentageOfTotal;

  ExpensesAnalysisModel({
    required this.accountCode,
    required this.accountName,
    required this.category,
    required this.totalAmount,
    required this.voucherCount,
    required this.percentageOfTotal,
  });

  factory ExpensesAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ExpensesAnalysisModel(
      accountCode: json['AccountCode']?.toString() ?? '',
      accountName: json['AccountName']?.toString() ?? '',
      category: json['Category']?.toString() ?? 'مصروفات تشغيلية',
      totalAmount: _asDouble(json['TotalExpense'] ?? json['TotalAmount']),
      voucherCount: _asInt(json['TransactionCount'] ?? json['VoucherCount']),
      percentageOfTotal: _asDouble(json['PercentageOfTotal']),
    );
  }
}

// 9. أرباح التصنيفات
class CategoryProfitModel {
  final int categoryID;
  final String categoryName;
  final int productCount;
  final double quantitySold;
  final double totalSales;
  final double totalCost;
  final double netProfit;
  final double profitMargin;

  CategoryProfitModel({
    required this.categoryID,
    required this.categoryName,
    required this.productCount,
    required this.quantitySold,
    required this.totalSales,
    required this.totalCost,
    required this.netProfit,
    required this.profitMargin,
  });

  factory CategoryProfitModel.fromJson(Map<String, dynamic> json) {
    final sales = _asDouble(json['TotalRevenue']);
    final cost = _asDouble(json['TotalCost']);
    final profit = json.containsKey('NetProfit') ? _asDouble(json['NetProfit']) : (sales - cost);
    final margin = json.containsKey('ProfitMarginPercent')
        ? _asDouble(json['ProfitMarginPercent'])
        : (sales > 0 ? (profit / sales) * 100 : 0.0);

    return CategoryProfitModel(
      categoryID: _asInt(json['CategoryID']),
      categoryName: json['CategoryName']?.toString() ?? 'عام',
      productCount: _asInt(json['ProductCount']),
      quantitySold: _asDouble(json['TotalQtySold']),
      totalSales: sales,
      totalCost: cost,
      netProfit: profit,
      profitMargin: margin,
    );
  }
}

// 10. أداء الكاشير والمستخدمين
class CashierPerformanceModel {
  final int userID;
  final String cashierName;
  final int invoiceCount;
  final double grossSales;
  final double discountsGiven;
  final double netSales;
  final double cashCollected;
  final double creditSales;
  final double averageTicket;

  CashierPerformanceModel({
    required this.userID,
    required this.cashierName,
    required this.invoiceCount,
    required this.grossSales,
    required this.discountsGiven,
    required this.netSales,
    required this.cashCollected,
    required this.creditSales,
    required this.averageTicket,
  });

  factory CashierPerformanceModel.fromJson(Map<String, dynamic> json) {
    return CashierPerformanceModel(
      userID: _asInt(json['UserID']),
      cashierName: json['CashierName']?.toString() ?? 'كاشير',
      invoiceCount: _asInt(json['InvoiceCount']),
      grossSales: _asDouble(json['TotalGrossSales']),
      discountsGiven: _asDouble(json['TotalDiscountsGiven']),
      netSales: _asDouble(json['TotalNetSales']),
      cashCollected: _asDouble(json['TotalCashCollected']),
      creditSales: _asDouble(json['TotalCreditSales']),
      averageTicket: _asDouble(json['AverageInvoiceValue']),
    );
  }
}

// 11. تحليل طرق الدفع
class PaymentMethodModel {
  final int accountID;
  final String paymentMethodName;
  final int invoiceCount;
  final double totalCollected;

  PaymentMethodModel({
    required this.accountID,
    required this.paymentMethodName,
    required this.invoiceCount,
    required this.totalCollected,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      accountID: _asInt(json['AccountID']),
      paymentMethodName: json['PaymentMethodName']?.toString() ?? 'كاش',
      invoiceCount: _asInt(json['InvoiceCount']),
      totalCollected: _asDouble(json['TotalAmountCollected']),
    );
  }
}

// 12. ربحية العملاء التفصيلية
class CustomerProfitabilityModel {
  final int partnerID;
  final String partnerName;
  final String phone;
  final int invoiceCount;
  final double totalSales;
  final double totalCost;
  final double netProfit;
  final double profitMargin;
  final double totalPaid;
  final double outstandingDebt;

  CustomerProfitabilityModel({
    required this.partnerID,
    required this.partnerName,
    required this.phone,
    required this.invoiceCount,
    required this.totalSales,
    required this.totalCost,
    required this.netProfit,
    required this.profitMargin,
    required this.totalPaid,
    required this.outstandingDebt,
  });

  factory CustomerProfitabilityModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfitabilityModel(
      partnerID: _asInt(json['PartnerID']),
      partnerName: json['PartnerName']?.toString() ?? 'عميل نقدي',
      phone: json['Phone']?.toString() ?? '',
      invoiceCount: _asInt(json['InvoiceCount']),
      totalSales: _asDouble(json['TotalSales']),
      totalCost: _asDouble(json['TotalCost'] ?? json['TotalCOGS']),
      netProfit: _asDouble(json['NetProfit'] ?? json['TotalProfit']),
      profitMargin: _asDouble(json['ProfitMarginPercent']),
      totalPaid: _asDouble(json['TotalPaid']),
      outstandingDebt: _asDouble(json['OutstandingDebt']),
    );
  }
}

// 13. ملخص الأرباح والخسائر التنفيذي
class ExecutivePnLModel {
  final double grossRevenue;
  final double totalDiscounts;
  final double netRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossProfitMargin;
  final double operatingExpenses;
  final double wastageLoss;
  final double netOperatingProfit;
  final double netProfitMargin;

  ExecutivePnLModel({
    required this.grossRevenue,
    required this.totalDiscounts,
    required this.netRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.grossProfitMargin,
    required this.operatingExpenses,
    required this.wastageLoss,
    required this.netOperatingProfit,
    required this.netProfitMargin,
  });

  factory ExecutivePnLModel.fromJson(Map<String, dynamic> json) {
    return ExecutivePnLModel(
      grossRevenue: _asDouble(json['GrossRevenue']),
      totalDiscounts: _asDouble(json['TotalDiscounts']),
      netRevenue: _asDouble(json['NetRevenue']),
      costOfGoodsSold: _asDouble(json['CostOfGoodsSold']),
      grossProfit: _asDouble(json['GrossProfit']),
      grossProfitMargin: _asDouble(json['GrossProfitMarginPercent']),
      operatingExpenses: _asDouble(json['OperatingExpenses']),
      wastageLoss: _asDouble(json['WastageLoss']),
      netOperatingProfit: _asDouble(json['NetOperatingProfit']),
      netProfitMargin: _asDouble(json['NetProfitMarginPercent']),
    );
  }

  factory ExecutivePnLModel.empty() {
    return ExecutivePnLModel(
      grossRevenue: 0.0,
      totalDiscounts: 0.0,
      netRevenue: 0.0,
      costOfGoodsSold: 0.0,
      grossProfit: 0.0,
      grossProfitMargin: 0.0,
      operatingExpenses: 0.0,
      wastageLoss: 0.0,
      netOperatingProfit: 0.0,
      netProfitMargin: 0.0,
    );
  }
}

// 14. الهالك والتوالف
class WastageAnalysisModel {
  final int productID;
  final String barcode;
  final String productName;
  final String categoryName;
  final double totalWastageQty;
  final double totalLossValue;
  final int incidentsCount;

  WastageAnalysisModel({
    required this.productID,
    required this.barcode,
    required this.productName,
    required this.categoryName,
    required this.totalWastageQty,
    required this.totalLossValue,
    required this.incidentsCount,
  });

  factory WastageAnalysisModel.fromJson(Map<String, dynamic> json) {
    return WastageAnalysisModel(
      productID: _asInt(json['ProductID']),
      barcode: json['Barcode']?.toString() ?? '',
      productName: json['ProductName']?.toString() ?? '',
      categoryName: json['CategoryName']?.toString() ?? 'عام',
      totalWastageQty: _asDouble(json['TotalWastageQty']),
      totalLossValue: _asDouble(json['TotalLossValue']),
      incidentsCount: _asInt(json['IncidentsCount']),
    );
  }
}

// 15. حركة الورديات
class ShiftAnalyticsModel {
  final int shiftID;
  final String cashierName;
  final String startTime;
  final String? endTime;
  final String status;
  final double startingCash;
  final double endingCash;
  final double totalSales;
  final double totalPurchases;
  final double totalCashIn;
  final double totalCashOut;
  final int invoiceCount;
  final double totalInvoicesNet;
  final double totalPaidCollected;

  ShiftAnalyticsModel({
    required this.shiftID,
    required this.cashierName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.startingCash,
    required this.endingCash,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.invoiceCount,
    required this.totalInvoicesNet,
    required this.totalPaidCollected,
  });

  factory ShiftAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return ShiftAnalyticsModel(
      shiftID: _asInt(json['ShiftID']),
      cashierName: json['CashierName']?.toString() ?? 'كاشير',
      startTime: json['StartTime']?.toString() ?? '',
      endTime: json['EndTime']?.toString(),
      status: json['Status']?.toString() ?? 'Open',
      startingCash: _asDouble(json['StartingCash']),
      endingCash: _asDouble(json['EndingCash']),
      totalSales: _asDouble(json['TotalSales']),
      totalPurchases: _asDouble(json['TotalPurchases']),
      totalCashIn: _asDouble(json['TotalCashIn']),
      totalCashOut: _asDouble(json['TotalCashOut']),
      invoiceCount: _asInt(json['InvoiceCount']),
      totalInvoicesNet: _asDouble(json['TotalInvoicesNet']),
      totalPaidCollected: _asDouble(json['TotalPaidCollected']),
    );
  }
}

