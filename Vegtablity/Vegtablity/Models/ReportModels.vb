Imports System

Namespace Models
    ' ==========================================================
    ' Report 1: Product Profits
    ' ==========================================================
    Public Class ReportProductProfit
        Public Property ProductID As Integer
        Public Property Barcode As String
        Public Property ProductName As String
        Public Property UnitName As String
        Public Property TotalQtySold As Decimal
        Public Property TotalRevenue As Decimal
        Public Property TotalCost As Decimal
        Public Property NetProfit As Decimal
        Public Property ProfitMarginPercent As Decimal
    End Class

    ' ==========================================================
    ' Report 2: Invoice Profits
    ' ==========================================================
    Public Class ReportInvoiceProfit
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property CustomerName As String
        Public Property GrossTotal As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property TotalCost As Decimal
        Public Property NetProfit As Decimal
        Public Property IsPosted As Boolean
    End Class

    ' ==========================================================
    ' Report 3: Sales Summary By Period
    ' ==========================================================
    Public Class ReportSalesSummary
        Public Property PeriodString As String
        Public Property InvoiceCount As Integer
        Public Property TotalGrossAmount As Decimal
        Public Property TotalDiscount As Decimal
        Public Property TotalNetAmount As Decimal
        Public Property TotalPaid As Decimal
        Public Property TotalCredit As Decimal
    End Class

    ' ==========================================================
    ' Report 4: Top Customers
    ' ==========================================================
    Public Class ReportTopCustomer
        Public Property PartnerID As Integer
        Public Property PartnerName As String
        Public Property Phone As String
        Public Property TotalInvoices As Integer
        Public Property TotalPurchases As Decimal
        Public Property TotalPaid As Decimal
        Public Property TotalCreditBalance As Decimal
    End Class

    ' ==========================================================
    ' Report 5: Unpaid Invoices Aging
    ' ==========================================================
    Public Class ReportUnpaidInvoice
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property CustomerName As String
        Public Property InvoiceTotal As Decimal
        Public Property PaidAmount As Decimal
        Public Property UnpaidBalance As Decimal
        Public Property DaysOverdue As Integer
        Public Property AgingBucket As String
    End Class

    ' ==========================================================
    ' Report 6: Inventory Valuation
    ' ==========================================================
    Public Class ReportInventoryValuation
        Public Property WarehouseName As String
        Public Property ProductID As Integer
        Public Property Barcode As String
        Public Property ProductName As String
        Public Property UnitName As String
        Public Property CurrentStock As Decimal
        Public Property UnitCost As Decimal
        Public Property UnitSellingPrice As Decimal
        Public Property TotalCostValue As Decimal
        Public Property TotalRetailValue As Decimal
    End Class

    ' ==========================================================
    ' Report 7: Slow Moving Stock
    ' ==========================================================
    Public Class ReportSlowMovingStock
        Public Property ProductID As Integer
        Public Property Barcode As String
        Public Property ProductName As String
        Public Property CatName As String
        Public Property UnitName As String
        Public Property CurrentTotalStock As Decimal
        Public Property PurchasePrice As Decimal
        Public Property LastSoldDate As DateTime?
        Public Property DaysSinceLastSale As Integer
    End Class

    ' ==========================================================
    ' Report 8: Stock Movement
    ' ==========================================================
    Public Class ReportStockMovement
        Public Property TransactionDate As DateTime
        Public Property TransactionType As String
        Public Property WarehouseName As String
        Public Property QtyIn As Decimal
        Public Property QtyOut As Decimal
        Public Property UnitPrice As Decimal
    End Class

    ' ==========================================================
    ' Report 9: Expenses Analysis
    ' ==========================================================
    Public Class ReportExpenseAnalysis
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property TotalExpense As Decimal
    End Class

    ' ==========================================================
    ' Report 10: Quotation Status
    ' ==========================================================
    Public Class ReportQuotationStatus
        Public Property QuoteID As Integer
        Public Property CustomerName As String
        Public Property QuoteDate As DateTime
        Public Property ExpiryDate As DateTime?
        Public Property IsActive As Boolean
        Public Property QuoteTotalValue As Decimal
        Public Property QuoteStatus As String
    End Class

    ' ==========================================================
    ' Report 11: Account Statement
    ' ==========================================================
    Public Class AccountStatementReport
        Public Property OpeningBalance As Decimal
        Public Property Transactions As New List(Of AccountStatementItem)
        Public Property TotalDebit As Decimal
        Public Property TotalCredit As Decimal
        Public Property EndingBalance As Decimal
    End Class

    Public Class AccountStatementItem
        Public Property EntryNo As Integer
        Public Property EntryDate As DateTime
        Public Property ReferenceType As String
        Public Property Description As String
        Public Property DebitAmount As Decimal
        Public Property CreditAmount As Decimal
        Public Property Balance As Decimal
    End Class

    ' ==========================================================
    ' Report 12: Trial Balance
    ' ==========================================================
    Public Class TrialBalanceReport
        Public Property StartDate As DateTime
        Public Property EndDate As DateTime
        Public Property Items As New List(Of TrialBalanceItem)
        Public Property TotalOpeningBalance As Decimal
        Public Property TotalPeriodDebit As Decimal
        Public Property TotalPeriodCredit As Decimal
        Public Property TotalEndingBalance As Decimal
    End Class

    Public Class TrialBalanceItem
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property OpeningBalance As Decimal
        Public Property PeriodDebit As Decimal
        Public Property PeriodCredit As Decimal
        Public Property EndingBalance As Decimal
    End Class

    ' ==========================================================
    ' Report 13: Financial Reports (Profit/Loss, Balance Sheet)
    ' ==========================================================
    Public Class FinancialReport
        Public Property Title As String
        Public Property StartDate As DateTime?
        Public Property EndDate As DateTime
        Public Property Items As New List(Of FinancialReportItem)
        Public Property TotalBalance As Decimal
    End Class

    Public Class FinancialReportItem
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property Balance As Decimal
        Public Property AccountType As String
    End Class

    ' ==========================================================
    ' Report 14: Customer Sales Summary (Profitability)
    ' ==========================================================
    Public Class ReportCustomerSalesSummary
        Public Property PartnerID As Integer
        Public Property PartnerName As String
        Public Property AccountID As Integer?
        Public Property InvoiceCount As Integer
        Public Property TotalSales As Decimal
        Public Property TotalCOGS As Decimal
        Public Property TotalProfit As Decimal
    End Class

    ' ==========================================================
    ' Report 15: Customer Invoices Detail (Profitability)
    ' ==========================================================
    Public Class ReportCustomerInvoiceDetail
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property ReferenceNo As String
        Public Property TotalAmount As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property TotalCOGS As Decimal
        Public Property Profit As Decimal
    End Class

    ' ==========================================================
    ' Report 16: Customer Product Sales (Profitability)
    ' ==========================================================
    Public Class ReportCustomerProductSale
        Public Property PartnerName As String
        Public Property ProductName As String
        Public Property TotalQty As Decimal
        Public Property TotalSalesValue As Decimal
        Public Property TotalCostValue As Decimal
        Public Property NetProfit As Decimal
    End Class

End Namespace
