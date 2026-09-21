class DashboardSummaryModel {
  final String database;
  final String startDate;
  final String endDate;
  final double totalSales;
  final double totalProfit;
  final double profitMarginPercent;
  final int totalInvoices;
  final double averageTicket;
  final double totalPaid;
  final double totalCredit;
  final double totalTax;
  final double totalDiscounts;
  final double totalReceivables;
  final int inventoryItemsCount;
  final double inventoryCostValue;
  final double inventorySaleValue;
  final double totalExpenses;
  final double grossProfit;

  DashboardSummaryModel({
    required this.database,
    required this.startDate,
    required this.endDate,
    required this.totalSales,
    required this.totalProfit,
    required this.profitMarginPercent,
    required this.totalInvoices,
    required this.averageTicket,
    required this.totalPaid,
    required this.totalCredit,
    required this.totalTax,
    required this.totalDiscounts,
    required this.totalReceivables,
    required this.inventoryItemsCount,
    required this.inventoryCostValue,
    required this.inventorySaleValue,
    this.totalExpenses = 0.0,
    this.grossProfit = 0.0,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      database: json['database']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      profitMarginPercent: (json['profit_margin_percent'] as num?)?.toDouble() ?? 0.0,
      totalInvoices: (json['total_invoices'] as num?)?.toInt() ?? 0,
      averageTicket: (json['average_ticket'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
      totalDiscounts: (json['total_discounts'] as num?)?.toDouble() ?? 0.0,
      totalReceivables: (json['total_receivables'] as num?)?.toDouble() ?? 0.0,
      inventoryItemsCount: (json['inventory_items_count'] as num?)?.toInt() ?? 0,
      inventoryCostValue: (json['inventory_cost_value'] as num?)?.toDouble() ?? 0.0,
      inventorySaleValue: (json['inventory_sale_value'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DashboardSummaryModel.empty(String dbName) {
    return DashboardSummaryModel(
      database: dbName,
      startDate: '',
      endDate: '',
      totalSales: 0.0,
      totalProfit: 0.0,
      profitMarginPercent: 0.0,
      totalInvoices: 0,
      averageTicket: 0.0,
      totalPaid: 0.0,
      totalCredit: 0.0,
      totalTax: 0.0,
      totalDiscounts: 0.0,
      totalReceivables: 0.0,
      inventoryItemsCount: 0,
      inventoryCostValue: 0.0,
      inventorySaleValue: 0.0,
      totalExpenses: 0.0,
      grossProfit: 0.0,
    );
  }
}
