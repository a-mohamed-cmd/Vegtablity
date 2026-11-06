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
        Public Property CashierName As String = "-"
        Public Property GrossTotal As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property TotalCost As Decimal
        Public Property NetProfit As Decimal
        Public Property IsPosted As Boolean

        Public Property TotalAmount As Decimal
            Get
                Return GrossTotal
            End Get
            Set(value As Decimal)
                GrossTotal = value
            End Set
        End Property
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

        Public Property PeriodLabel As String
            Get
                Return PeriodString
            End Get
            Set(value As String)
                PeriodString = value
            End Set
        End Property

        Public Property TotalGrossSales As Decimal
            Get
                Return TotalGrossAmount
            End Get
            Set(value As Decimal)
                TotalGrossAmount = value
            End Set
        End Property

        Public Property TotalDiscounts As Decimal
            Get
                Return TotalDiscount
            End Get
            Set(value As Decimal)
                TotalDiscount = value
            End Set
        End Property

        Public Property TotalNetSales As Decimal
            Get
                Return TotalNetAmount
            End Get
            Set(value As Decimal)
                TotalNetAmount = value
            End Set
        End Property

        Public Property TotalRemainder As Decimal
            Get
                Return TotalCredit
            End Get
            Set(value As Decimal)
                TotalCredit = value
            End Set
        End Property
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

        Public Property TotalRemainder As Decimal
            Get
                Return TotalCreditBalance
            End Get
            Set(value As Decimal)
                TotalCreditBalance = value
            End Set
        End Property
    End Class

    ' ==========================================================
    ' Report 5: Unpaid Invoices Aging
    ' ==========================================================
    Public Class ReportUnpaidInvoice
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property CustomerName As String
        Public Property Phone As String = "-"
        Public Property InvoiceTotal As Decimal
        Public Property PaidAmount As Decimal
        Public Property UnpaidBalance As Decimal
        Public Property DaysOverdue As Integer
        Public Property AgingBucket As String

        Public Property NetAmount As Decimal
            Get
                Return InvoiceTotal
            End Get
            Set(value As Decimal)
                InvoiceTotal = value
            End Set
        End Property

        Public Property AgingCategory As String
            Get
                Return AgingBucket
            End Get
            Set(value As String)
                AgingBucket = value
            End Set
        End Property
    End Class

    ' ==========================================================
    ' Report 6: Inventory Valuation
    ' ==========================================================
    Public Class ReportInventoryValuation
        Public Property WarehouseName As String
        Public Property ProductID As Integer
        Public Property Barcode As String
        Public Property ProductName As String
        Public Property CategoryName As String = "-"
        Public Property UnitName As String
        Public Property CurrentStock As Decimal
        Public Property UnitCost As Decimal
        Public Property UnitSellingPrice As Decimal
        Public Property TotalCostValue As Decimal
        Public Property TotalRetailValue As Decimal

        Public Property CurrentQty As Decimal
            Get
                Return CurrentStock
            End Get
            Set(value As Decimal)
                CurrentStock = value
            End Set
        End Property

        Public Property AvgCostPrice As Decimal
            Get
                Return UnitCost
            End Get
            Set(value As Decimal)
                UnitCost = value
            End Set
        End Property
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

        Public Property CategoryName As String
            Get
                Return CatName
            End Get
            Set(value As String)
                CatName = value
            End Set
        End Property

        Public Property CurrentQty As Decimal
            Get
                Return CurrentTotalStock
            End Get
            Set(value As Decimal)
                CurrentTotalStock = value
            End Set
        End Property

        Public Property LastSaleDate As DateTime?
            Get
                Return LastSoldDate
            End Get
            Set(value As DateTime?)
                LastSoldDate = value
            End Set
        End Property
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
        Public Property InvID As Integer
        Public Property PartnerName As String = "-"
        Public Property CashierName As String = "-"
        Public Property RunningBalance As Decimal

        Public Property MovementDate As DateTime
            Get
                Return TransactionDate
            End Get
            Set(value As DateTime)
                TransactionDate = value
            End Set
        End Property

        Public Property MovementType As String
            Get
                Return TransactionType
            End Get
            Set(value As String)
                TransactionType = value
            End Set
        End Property

        Public Property QtyMoved As Decimal
            Get
                Return If(QtyIn > 0, QtyIn, -QtyOut)
            End Get
            Set(value As Decimal)
                If value >= 0 Then
                    QtyIn = value
                Else
                    QtyOut = Math.Abs(value)
                End If
            End Set
        End Property
    End Class

    ' ==========================================================
    ' Report 9: Expenses Analysis
    ' ==========================================================
    Public Class ReportExpenseAnalysis
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property TotalExpense As Decimal
        Public Property VoucherCount As Integer = 1
        Public Property LastExpenseDate As DateTime = DateTime.MinValue

        Public Property ExpenseCategory As String
            Get
                Return If(Not String.IsNullOrEmpty(AccountCode), AccountCode & " - " & AccountName, AccountName)
            End Get
            Set(value As String)
                AccountName = value
            End Set
        End Property

        Public Property TotalExpenses As Decimal
            Get
                Return TotalExpense
            End Get
            Set(value As Decimal)
                TotalExpense = value
            End Set
        End Property
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
        Public Property ItemsCount As Integer

        Public Property TotalAmount As Decimal
            Get
                Return QuoteTotalValue
            End Get
            Set(value As Decimal)
                QuoteTotalValue = value
            End Set
        End Property
    End Class

    ' ==========================================================
    ' Report 11: Account Statement (Exact 3 Decimal Digits Without Rounding)
    ' ==========================================================
    Public Class AccountStatementReport
        Private _openingBalance As Decimal
        Private _totalDebit As Decimal
        Private _totalCredit As Decimal
        Private _endingBalance As Decimal

        Public Shared Function TruncateTo3Decimals(val As Decimal) As Decimal
            Return Math.Truncate(val * 1000D) / 1000D
        End Function

        Public Shared Function FormatExact3Decimals(val As Decimal) As String
            Dim truncated As Decimal = TruncateTo3Decimals(val)
            Return truncated.ToString("#,##0.000", System.Globalization.CultureInfo.InvariantCulture)
        End Function

        Public Property OpeningBalance As Decimal
            Get
                Return _openingBalance
            End Get
            Set(value As Decimal)
                _openingBalance = TruncateTo3Decimals(value)
            End Set
        End Property

        Public Property Transactions As New List(Of AccountStatementItem)

        Public Property TotalDebit As Decimal
            Get
                Return _totalDebit
            End Get
            Set(value As Decimal)
                _totalDebit = TruncateTo3Decimals(value)
            End Set
        End Property

        Public Property TotalCredit As Decimal
            Get
                Return _totalCredit
            End Get
            Set(value As Decimal)
                _totalCredit = TruncateTo3Decimals(value)
            End Set
        End Property

        Public Property EndingBalance As Decimal
            Get
                Return _endingBalance
            End Get
            Set(value As Decimal)
                _endingBalance = TruncateTo3Decimals(value)
            End Set
        End Property

        Public ReadOnly Property OpeningBalanceText As String
            Get
                Return FormatExact3Decimals(_openingBalance)
            End Get
        End Property

        Public ReadOnly Property TotalDebitText As String
            Get
                Return FormatExact3Decimals(_totalDebit)
            End Get
        End Property

        Public ReadOnly Property TotalCreditText As String
            Get
                Return FormatExact3Decimals(_totalCredit)
            End Get
        End Property

        Public ReadOnly Property EndingBalanceText As String
            Get
                Return FormatExact3Decimals(_endingBalance)
            End Get
        End Property
    End Class

    Public Class AccountStatementItem
        Private _debitAmount As Decimal
        Private _creditAmount As Decimal
        Private _balance As Decimal

        Public Property EntryNo As Integer
        Public Property EntryDate As DateTime
        Public Property ReferenceType As String
        Public Property Description As String

        Public Property DebitAmount As Decimal
            Get
                Return _debitAmount
            End Get
            Set(value As Decimal)
                _debitAmount = AccountStatementReport.TruncateTo3Decimals(value)
            End Set
        End Property

        Public Property CreditAmount As Decimal
            Get
                Return _creditAmount
            End Get
            Set(value As Decimal)
                _creditAmount = AccountStatementReport.TruncateTo3Decimals(value)
            End Set
        End Property

        Public Property Balance As Decimal
            Get
                Return _balance
            End Get
            Set(value As Decimal)
                _balance = AccountStatementReport.TruncateTo3Decimals(value)
            End Set
        End Property

        Public ReadOnly Property DebitAmountText As String
            Get
                Return AccountStatementReport.FormatExact3Decimals(_debitAmount)
            End Get
        End Property

        Public ReadOnly Property CreditAmountText As String
            Get
                Return AccountStatementReport.FormatExact3Decimals(_creditAmount)
            End Get
        End Property

        Public ReadOnly Property BalanceText As String
            Get
                Return AccountStatementReport.FormatExact3Decimals(_balance)
            End Get
        End Property
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
        Public Property PercentageOfSales As Decimal = 0
        
        Public ReadOnly Property PercentageOfSalesText As String
            Get
                Return PercentageOfSales.ToString("F1") & " %"
            End Get
        End Property
    End Class

    ' ==========================================================
    ' Report 13.1: Horizontal Monthly Comparative Profit & Loss
    ' ==========================================================
    Public Class MonthlyPeriodHeader
        Public Property MonthKey As String            ' e.g. "2026-01"
        Public Property MonthName As String           ' e.g. "يناير 2026"
        Public Property Year As Integer
        Public Property MonthNumber As Integer
        Public Property StartDate As DateTime
        Public Property EndDate As DateTime
    End Class

    Public Class MonthlyComparativeRow
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property AccountType As String
        Public Property MonthlyValues As New Dictionary(Of String, Decimal)()
        Public Property TotalBalance As Decimal
        Public Property PercentageOfSales As Decimal

        Public ReadOnly Property PercentageOfSalesText As String
            Get
                Return PercentageOfSales.ToString("F1") & " %"
            End Get
        End Property

        Public Function GetMonthValue(monthKey As String) As Decimal
            If MonthlyValues IsNot Nothing AndAlso MonthlyValues.ContainsKey(monthKey) Then
                Return MonthlyValues(monthKey)
            End If
            Return 0
        End Function
    End Class

    Public Class MonthlyComparativeReport
        Public Property Title As String = "قائمة الأرباح والخسائر المقارنة شهرياً"
        Public Property StartDate As DateTime
        Public Property EndDate As DateTime
        Public Property Months As New List(Of MonthlyPeriodHeader)()
        Public Property RevenueRows As New List(Of MonthlyComparativeRow)()
        Public Property ExpenseRows As New List(Of MonthlyComparativeRow)()
        Public Property MonthlyRevenuesTotal As New Dictionary(Of String, Decimal)()
        Public Property MonthlyExpensesTotal As New Dictionary(Of String, Decimal)()
        Public Property MonthlyNetProfit As New Dictionary(Of String, Decimal)()
        Public Property TotalRevenues As Decimal
        Public Property TotalExpenses As Decimal
        Public Property TotalNetProfit As Decimal
        Public Property NetProfitPercentageOfSales As Decimal
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

    ' ==========================================================
    ' Report 17: Wastage Report (تقرير الهالك)
    ' ==========================================================
    Public Class ReportWastageItem
        Public Property WastageID As Integer
        Public Property WastageDate As DateTime
        Public Property WarehouseName As String
        Public Property ProductCode As String
        Public Property ProductName As String
        Public Property Quantity As Decimal
        Public Property CostPrice As Decimal
        Public Property TotalCost As Decimal
        Public Property IsPosted As Boolean
        Public Property Notes As String

        ' Computed display helpers
        Public ReadOnly Property StatusText As String
            Get
                Return If(IsPosted, "مرحّل", "مسودة")
            End Get
        End Property
    End Class

    ' ==========================================================
    ' Report 18: Warehouse / Branch Sales Report (مبيعات الفروع والمخازن)
    ' ==========================================================
    Public Class ReportWarehouseSales
        Public Property WarehouseID As Integer
        Public Property WarehouseName As String
        Public Property InvoiceCount As Integer
        Public Property TotalGrossSales As Decimal
        Public Property TotalDiscounts As Decimal
        Public Property TotalNetSales As Decimal
        Public Property TotalPaid As Decimal
        Public Property TotalRemainder As Decimal
        Public Property TotalCost As Decimal
        Public Property NetProfit As Decimal
        Public Property ProfitMarginPercent As Decimal
        Public Property SalesSharePercent As Decimal
    End Class

    ' ==========================================================
    ' Report 19: Purchase Invoices Report (تقرير فواتير المشتريات)
    ' ==========================================================
    Public Class ReportPurchaseInvoice
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property ReferenceNo As String = "-"
        Public Property PartnerID As Integer
        Public Property SupplierName As String = "مورد نقدي"
        Public Property SupplierPhone As String = "-"
        Public Property WarehouseName As String = "-"
        Public Property UserName As String = "-"
        Public Property ItemsCount As Integer
        Public Property TotalAmount As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property PaidAmount As Decimal
        Public Property Remainder As Decimal
        Public Property IsPosted As Boolean
        Public Property Notes As String = ""

        Public ReadOnly Property StatusText As String
            Get
                Return If(IsPosted, "مرحّلة", "مسودة")
            End Get
        End Property
    End Class

    ' ==========================================================
    ' UI Helper Models for Summary Bar & ReportRowControl
    ' ==========================================================
    Public Class ReportSummaryMetric
        Public Property Title As String
        Public Property ValueText As String
        Public Property SubText As String
        Public Property Icon As String
        Public Property AccentColor As String = "#2563EB"
        Public Property BgColor As String = "#EFF6FF"
        Public Property BorderColor As String = "#BFDBFE"
    End Class

    Public Class ReportColumnHeader
        Public Property Title As String
        Public Property WidthWeight As Double = 1.0
        Public Property IsHighlight As Boolean = False
        Public Property AccentColor As String = "#334155"
    End Class

    Public Class ReportCellInfo
        Public Property Text As String
        Public Property SubText As String = ""
        Public Property WidthWeight As Double = 1.0
        Public Property ForegroundColor As String = "#1E293B"
        Public Property IsBold As Boolean = False
        Public Property IsBadge As Boolean = False
        Public Property BadgeBgColor As String = "#F1F5F9"
        Public Property BadgeBorderColor As String = "#E2E8F0"
        Public Property HorizontalAlign As String = "Right" ' Right, Center, Left
    End Class

    Public Class ReportRowItem
        Public Property RowNumber As Integer
        Public Property IsEvenRow As Boolean
        Public Property RawItem As Object
        Public Property SearchableText As String = ""
        Public Property Cells As New List(Of ReportCellInfo)()
    End Class

End Namespace
