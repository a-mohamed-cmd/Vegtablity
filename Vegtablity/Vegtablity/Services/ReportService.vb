Imports System.Collections.Generic
Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Namespace Services
    Public Class ReportService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' 1. Product Profits
        Public Function GetProductProfits(startDate As DateTime, endDate As DateTime, orderBy As String) As List(Of ReportProductProfit)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportProductProfit)(
                        StoredProcedures.SP_REPORT_PRODUCTPROFITS,
                        New With {.StartDate = startDate, .EndDate = endDate, .OrderBy = orderBy},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading product profits report: " & ex.Message, ex)
            End Try
        End Function

        ' 2. Invoice Profits
        Public Function GetInvoiceProfits(startDate As DateTime, endDate As DateTime) As List(Of ReportInvoiceProfit)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportInvoiceProfit)(
                        StoredProcedures.SP_REPORT_INVOICEPROFITS,
                        New With {.StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading invoice profits report: " & ex.Message, ex)
            End Try
        End Function

        ' 3. Sales By Period
        Public Function GetSalesSummaryByPeriod(startDate As DateTime, endDate As DateTime, periodType As String) As List(Of ReportSalesSummary)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportSalesSummary)(
                        StoredProcedures.SP_REPORT_SALESSUMMARYBYPERIOD,
                        New With {.StartDate = startDate, .EndDate = endDate, .PeriodType = periodType},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading sales summary report: " & ex.Message, ex)
            End Try
        End Function

        ' 4. Top Customers
        Public Function GetTopCustomers(startDate As DateTime, endDate As DateTime) As List(Of ReportTopCustomer)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportTopCustomer)(
                        StoredProcedures.SP_REPORT_TOPCUSTOMERS,
                        New With {.StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading top customers report: " & ex.Message, ex)
            End Try
        End Function

        ' 5. Aging Unpaid Invoices
        Public Function GetUnpaidInvoicesAging(asOfDate As DateTime?, Optional partnerID As Integer? = Nothing) As List(Of ReportUnpaidInvoice)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim targetDate As DateTime = If(asOfDate.HasValue, asOfDate.Value.Date, DateTime.Today)
                    Dim pId As Integer = If(partnerID.HasValue, partnerID.Value, 0)
                    Dim sql As String = "SELECT i.InvID, i.InvDate, ISNULL(p.PartnerName, N'عميل نقدي') AS CustomerName, ISNULL(p.Phone, N'-') AS Phone, i.NetAmount AS InvoiceTotal, i.PaidAmount, i.Remainder AS UnpaidBalance, DATEDIFF(DAY, i.InvDate, @AsOfDate) AS DaysOverdue, CASE WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 30 THEN '1_0_to_30_Days' WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 60 THEN '2_31_to_60_Days' WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 90 THEN '3_61_to_90_Days' ELSE '4_Over_90_Days' END AS AgingBucket FROM [Sales].[InvoiceHeader] i INNER JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.Remainder > 0 AND i.IsPosted = 1 AND CAST(i.InvDate AS DATE) <= @AsOfDate AND (@PartnerID = 0 OR i.PartnerID = @PartnerID) ORDER BY DaysOverdue DESC;"
                    Return conn.Query(Of ReportUnpaidInvoice)(sql, New With {.AsOfDate = targetDate, .PartnerID = pId}).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading aging invoices report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetUnpaidInvoicesAging_Old(asOfDate As DateTime?, Optional partnerID As Integer? = Nothing) As List(Of ReportUnpaidInvoice)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportUnpaidInvoice)(
                        StoredProcedures.SP_REPORT_UNPAIDINVOICESAGING,
                        New With {.AsOfDate = asOfDate, .PartnerID = partnerID},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading aging invoices report: " & ex.Message, ex)
            End Try
        End Function

        ' 6. Inventory Valuation
        Public Function GetInventoryValuation(warehouseId As Integer) As List(Of ReportInventoryValuation)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim sql As String = "SELECT ISNULL(w.WarehouseName, N'المخزن الرئيسي') AS WarehouseName, p.ProductID, ISNULL(p.Barcode, '') AS Barcode, ISNULL(p.ProductName, N'صنف غير معرف') AS ProductName, ISNULL(c.CatName, N'عام') AS CategoryName, ISNULL(u.UnitName, N'حبة') AS UnitName, ISNULL(s.CurrentQty, 0) AS CurrentStock, ISNULL(s.AvgCostPrice, ISNULL(p.PurchasePrice, 0)) AS UnitCost, ISNULL(p.SalePrice, 0) AS UnitSellingPrice, ISNULL(s.CurrentQty * ISNULL(s.AvgCostPrice, ISNULL(p.PurchasePrice, 0)), 0) AS TotalCostValue, ISNULL(s.CurrentQty * ISNULL(p.SalePrice, 0), 0) AS TotalRetailValue FROM [Inventory].[ProductStock] s INNER JOIN [Inventory].[Products] p ON s.ProductID = p.ProductID INNER JOIN [Settings].[Warehouses] w ON s.WarehouseID = w.WarehouseID LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID WHERE (@WarehouseID = 0 OR s.WarehouseID = @WarehouseID) AND s.CurrentQty > 0 ORDER BY w.WarehouseName, p.ProductName;"
                    Return conn.Query(Of ReportInventoryValuation)(sql, New With {.WarehouseID = warehouseId}).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading inventory valuation report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetInventoryValuation_Old(warehouseId As Integer) As List(Of ReportInventoryValuation)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportInventoryValuation)(
                        StoredProcedures.SP_REPORT_INVENTORYVALUATION,
                        New With {.WarehouseID = warehouseId},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading inventory valuation report: " & ex.Message, ex)
            End Try
        End Function

        ' 7. Slow Moving Stock
        Public Function GetSlowMovingStock(monthsInactive As Integer) As List(Of ReportSlowMovingStock)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim sql As String = "DECLARE @CutoffDate DATE = DATEADD(MONTH, -@MonthsInactive, GETDATE()); SELECT p.ProductID, ISNULL(p.Barcode, '') AS Barcode, ISNULL(p.ProductName, N'صنف غير معرف') AS ProductName, ISNULL(c.CatName, N'عام') AS CatName, ISNULL(u.UnitName, N'حبة') AS UnitName, ISNULL(SUM(s.CurrentQty), 0) AS CurrentTotalStock, ISNULL(p.PurchasePrice, 0) AS PurchasePrice, MAX(i.InvDate) AS LastSoldDate, ISNULL(DATEDIFF(DAY, MAX(i.InvDate), GETDATE()), 999) AS DaysSinceLastSale FROM [Inventory].[Products] p LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID LEFT JOIN [Inventory].[ProductStock] s ON p.ProductID = s.ProductID LEFT JOIN [Sales].[InvoiceDetails] d ON p.ProductID = d.ProductID LEFT JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID GROUP BY p.ProductID, p.Barcode, p.ProductName, c.CatName, u.UnitName, p.PurchasePrice HAVING ISNULL(SUM(s.CurrentQty), 0) > 0 AND (MAX(i.InvDate) IS NULL OR CAST(MAX(i.InvDate) AS DATE) <= @CutoffDate) ORDER BY DaysSinceLastSale DESC;"
                    Return conn.Query(Of ReportSlowMovingStock)(sql, New With {.MonthsInactive = monthsInactive}).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading slow moving stock report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetSlowMovingStock_Old(monthsInactive As Integer) As List(Of ReportSlowMovingStock)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportSlowMovingStock)(
                        StoredProcedures.SP_REPORT_SLOWMOVINGSTOCK,
                        New With {.MonthsInactive = monthsInactive},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading slow moving stock report: " & ex.Message, ex)
            End Try
        End Function

        ' 8. Stock Movement
        Public Function GetStockMovement(productId As Integer, warehouseId As Integer, startDate As DateTime, endDate As DateTime) As List(Of ReportStockMovement)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim sql As String = "SELECT Movement.InvID, Movement.TransactionDate, Movement.TransactionType, Movement.WarehouseName, Movement.PartnerName, Movement.CashierName, Movement.QtyIn, Movement.QtyOut, Movement.UnitPrice FROM (SELECT i.InvID, i.InvDate AS TransactionDate, N'فاتورة مشتريات' AS TransactionType, w.WarehouseName, ISNULL(p.PartnerName, N'مورد نقدي') AS PartnerName, ISNULL(u.FullName, ISNULL(u.Username, N'-')) AS CashierName, d.Quantity AS QtyIn, CAST(0 AS DECIMAL(18,3)) AS QtyOut, d.UnitPrice FROM [Sales].[InvoiceDetails] d INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID LEFT JOIN [Security].[Users] u ON i.UserID = u.UserID WHERE d.ProductID = @ProductID AND i.InvType = 'Purchase' AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID) AND i.IsPosted = 1 UNION ALL SELECT i.InvID, i.InvDate AS TransactionDate, N'فاتورة مبيعات' AS TransactionType, w.WarehouseName, ISNULL(p.PartnerName, N'عميل نقدي') AS PartnerName, ISNULL(u.FullName, ISNULL(u.Username, N'-')) AS CashierName, CAST(0 AS DECIMAL(18,3)) AS QtyIn, d.Quantity AS QtyOut, d.UnitPrice FROM [Sales].[InvoiceDetails] d INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID LEFT JOIN [Security].[Users] u ON i.UserID = u.UserID WHERE d.ProductID = @ProductID AND (i.InvType = 'Sales' OR i.InvType = 'Sale' OR i.InvType IS NULL) AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID) AND i.IsPosted = 1) AS Movement WHERE CAST(Movement.TransactionDate AS DATE) BETWEEN @StartDate AND @EndDate ORDER BY Movement.TransactionDate ASC, Movement.InvID ASC;"
                    Dim list = conn.Query(Of ReportStockMovement)(sql, New With {.ProductID = productId, .WarehouseID = warehouseId, .StartDate = startDate.Date, .EndDate = endDate.Date}).AsList()
                    Dim running As Decimal = 0
                    For Each item In list
                        running += (item.QtyIn - item.QtyOut)
                        item.RunningBalance = running
                    Next
                    list.Reverse()
                    Return list
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading stock movement report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetStockMovement_Old(productId As Integer, warehouseId As Integer, startDate As DateTime, endDate As DateTime) As List(Of ReportStockMovement)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportStockMovement)(
                        StoredProcedures.SP_REPORT_STOCKMOVEMENT,
                        New With {.ProductID = productId, .WarehouseID = warehouseId, .StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading stock movement report: " & ex.Message, ex)
            End Try
        End Function

        ' 9. Expenses Analysis
        Public Function GetExpensesAnalysis(startDate As DateTime, endDate As DateTime) As List(Of ReportExpenseAnalysis)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim sql As String = "SELECT ISNULL(a.AccountCode, 'EXP') AS AccountCode, a.AccountName, COUNT(d.EntryID) AS VoucherCount, ISNULL(SUM(d.DebitAmount - d.CreditAmount), 0) AS TotalExpense, MAX(d.EntryDate) AS LastExpenseDate FROM [Accounting].[JournalEntries] d INNER JOIN [Accounting].[ChartOfAccounts] a ON d.AccountID = a.AccountID WHERE CAST(d.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate AND a.AccountType = 'Expenses' GROUP BY a.AccountCode, a.AccountName HAVING ISNULL(SUM(d.DebitAmount - d.CreditAmount), 0) > 0 ORDER BY TotalExpense DESC;"
                    Return conn.Query(Of ReportExpenseAnalysis)(sql, New With {.StartDate = startDate.Date, .EndDate = endDate.Date}).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading expenses analysis report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetExpensesAnalysis_Old(startDate As DateTime, endDate As DateTime) As List(Of ReportExpenseAnalysis)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportExpenseAnalysis)(
                        StoredProcedures.SP_REPORT_EXPENSESANALYSIS,
                        New With {.StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading expenses analysis report: " & ex.Message, ex)
            End Try
        End Function

        ' 10. Quotation Status
        Public Function GetQuotationsStatus(status As String) As List(Of ReportQuotationStatus)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim sql As String = "SELECT q.QuoteID, p.PartnerName AS CustomerName, q.QuoteDate, q.ExpiryDate, q.IsActive, ISNULL((SELECT COUNT(*) FROM [Sales].[QuotationDetails] WHERE QuoteID = q.QuoteID), 0) AS ItemsCount, ISNULL((SELECT SUM(QuotedPrice) FROM [Sales].[QuotationDetails] WHERE QuoteID = q.QuoteID), 0) AS QuoteTotalValue, CASE WHEN q.IsActive = 0 THEN N'مغلق' WHEN q.ExpiryDate IS NOT NULL AND CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE) THEN N'منتهي الصلاحية' ELSE N'فعال (قيد الانتظار)' END AS QuoteStatus FROM [Sales].[Quotations] q INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID WHERE (@Status = 'All') OR (@Status = 'Active' AND q.IsActive = 1 AND (q.ExpiryDate IS NULL OR CAST(q.ExpiryDate AS DATE) >= CAST(GETDATE() AS DATE))) OR (@Status = 'Expired' AND (q.IsActive = 0 OR CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE))) ORDER BY q.QuoteDate DESC;"
                    Return conn.Query(Of ReportQuotationStatus)(sql, New With {.Status = status}).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading quotations status report: " & ex.Message, ex)
            End Try
        End Function

        Public Function Unused_GetQuotationsStatus_Old(status As String) As List(Of ReportQuotationStatus)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportQuotationStatus)(
                        StoredProcedures.SP_REPORT_QUOTATIONSSTATUS,
                        New With {.Status = status},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading quotations status report: " & ex.Message, ex)
            End Try
        End Function

        ' 11. Customer Sales Summary
        Public Function GetCustomerSalesSummary(startDate As DateTime, endDate As DateTime) As List(Of ReportCustomerSalesSummary)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportCustomerSalesSummary)(
                        StoredProcedures.SP_REPORT_CUSTOMERSALESSUMMARY,
                        New With {.StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading customer sales summary report: " & ex.Message, ex)
            End Try
        End Function

        ' 12. Customer Invoices Detail
        Public Function GetCustomerInvoicesDetail(partnerID As Integer, startDate As DateTime, endDate As DateTime) As List(Of ReportCustomerInvoiceDetail)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportCustomerInvoiceDetail)(
                        StoredProcedures.SP_REPORT_CUSTOMERINVOICESDETAIL,
                        New With {.PartnerID = partnerID, .StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading customer invoices detail report: " & ex.Message, ex)
            End Try
        End Function

        ' 13. Customer Product Sales
        Public Function GetCustomerProductSales(partnerID As Integer, startDate As DateTime, endDate As DateTime) As List(Of ReportCustomerProductSale)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportCustomerProductSale)(
                        StoredProcedures.SP_REPORT_CUSTOMERPRODUCTSALES,
                        New With {.PartnerID = partnerID, .StartDate = startDate, .EndDate = endDate},
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading customer product sales report: " & ex.Message, ex)
            End Try
        End Function

        ' 14. Wastage Report (تقرير الهالك)
        Public Function GetWastageReport(startDate As DateTime, endDate As DateTime,
                                         Optional warehouseID As Integer? = Nothing,
                                         Optional productID As Integer? = Nothing) As List(Of ReportWastageItem)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportWastageItem)(
                        StoredProcedures.SP_WASTAGE_REPORT,
                        New With {
                            .StartDate = startDate.Date,
                            .EndDate = endDate.Date,
                            .WarehouseID = If(warehouseID.HasValue, CObj(warehouseID.Value), CObj(DBNull.Value)),
                            .ProductID = If(productID.HasValue, CObj(productID.Value), CObj(DBNull.Value))
                        },
                        commandType:=CommandType.StoredProcedure
                    ).AsList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading wastage report: " & ex.Message, ex)
            End Try
        End Function

        ' 15. Warehouse / Branch Sales Report (تقرير مبيعات الفروع والمخازن)
        Public Function GetWarehouseSales(startDate As DateTime, endDate As DateTime,
                                          Optional warehouseID As Integer? = Nothing) As List(Of ReportWarehouseSales)
            Dim whIdParam As Integer = If(warehouseID.HasValue AndAlso warehouseID.Value > 0, warehouseID.Value, 0)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Try
                        Return conn.Query(Of ReportWarehouseSales)(
                            StoredProcedures.SP_REPORT_WAREHOUSESALES,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .WarehouseID = whIdParam
                            },
                            commandType:=CommandType.StoredProcedure
                        ).AsList()
                    Catch spEx As Exception
                        ' Fallback query directly on InvoiceHeader & Warehouses if SP is not yet deployed in DB
                        Dim sql As String = "
                        ;WITH InvoiceCosts AS (
                            SELECT 
                                d.InvID,
                                ISNULL(SUM(ISNULL(d.Quantity, 1) * ISNULL(d.CostPrice, ISNULL(p.PurchasePrice, 0))), 0) AS InvoiceCost
                            FROM [Sales].[InvoiceDetails] d
                            LEFT JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
                            GROUP BY d.InvID
                        ),
                        FilteredInvoices AS (
                            SELECT 
                                ISNULL(i.WarehouseID, 0) AS WarehouseID,
                                i.InvID,
                                ISNULL(i.TotalAmount, 0) AS TotalAmount,
                                ISNULL(i.Discount, 0) AS Discount,
                                ISNULL(i.NetAmount, 0) AS NetAmount,
                                ISNULL(i.PaidAmount, 0) AS PaidAmount,
                                ISNULL(i.Remainder, 0) AS Remainder,
                                ISNULL(ic.InvoiceCost, 0) AS InvoiceCost
                            FROM [Sales].[InvoiceHeader] i
                            LEFT JOIN InvoiceCosts ic ON i.InvID = ic.InvID
                            WHERE CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
                              AND (i.InvType = 'Sales' OR i.InvType = 'Sale' OR i.InvType IS NULL OR i.InvType = '' OR i.InvType = N'مبيعات' OR i.InvType NOT LIKE '%Purchase%')
                              AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
                        ),
                        WarehouseAgg AS (
                            SELECT 
                                ISNULL(w.WarehouseID, fi.WarehouseID) AS WarehouseID,
                                ISNULL(w.WarehouseName, N'المخزن / الفرع الرئيسي') AS WarehouseName,
                                COUNT(fi.InvID) AS InvoiceCount,
                                ISNULL(SUM(fi.TotalAmount), 0) AS TotalGrossSales,
                                ISNULL(SUM(fi.Discount), 0) AS TotalDiscounts,
                                ISNULL(SUM(fi.NetAmount), 0) AS TotalNetSales,
                                ISNULL(SUM(fi.PaidAmount), 0) AS TotalPaid,
                                ISNULL(SUM(fi.Remainder), 0) AS TotalRemainder,
                                ISNULL(SUM(fi.InvoiceCost), 0) AS TotalCost
                            FROM [Settings].[Warehouses] w
                            FULL OUTER JOIN FilteredInvoices fi ON w.WarehouseID = fi.WarehouseID
                            WHERE (@WarehouseID = 0 OR ISNULL(w.WarehouseID, fi.WarehouseID) = @WarehouseID)
                              AND (w.WarehouseID IS NOT NULL OR fi.InvID IS NOT NULL)
                            GROUP BY ISNULL(w.WarehouseID, fi.WarehouseID), ISNULL(w.WarehouseName, N'المخزن / الفرع الرئيسي')
                        ),
                        GrandTotal AS (
                            SELECT ISNULL(SUM(TotalNetSales), 0) AS AllWarehousesNetSales
                            FROM WarehouseAgg
                        )
                        SELECT 
                            wa.WarehouseID,
                            wa.WarehouseName,
                            wa.InvoiceCount,
                            wa.TotalGrossSales,
                            wa.TotalDiscounts,
                            wa.TotalNetSales,
                            wa.TotalPaid,
                            wa.TotalRemainder,
                            wa.TotalCost,
                            (wa.TotalNetSales - wa.TotalCost) AS NetProfit,
                            CASE WHEN wa.TotalNetSales > 0 
                                 THEN ((wa.TotalNetSales - wa.TotalCost) / wa.TotalNetSales) * 100 
                                 ELSE 0 END AS ProfitMarginPercent,
                            CASE WHEN gt.AllWarehousesNetSales > 0 
                                 THEN (wa.TotalNetSales / gt.AllWarehousesNetSales) * 100 
                                 ELSE 0 END AS SalesSharePercent
                        FROM WarehouseAgg wa
                        CROSS JOIN GrandTotal gt
                        ORDER BY wa.TotalNetSales DESC, wa.InvoiceCount DESC, wa.WarehouseID ASC;"

                        Return conn.Query(Of ReportWarehouseSales)(
                            sql,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .WarehouseID = whIdParam
                            }
                        ).AsList()
                    End Try
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading warehouse sales report: " & ex.Message, ex)
            End Try
        End Function

        ' 16. Purchase Invoices Report (تقرير فواتير المشتريات)
        Public Function GetPurchaseInvoicesReport(startDate As DateTime, endDate As DateTime,
                                                  Optional partnerID As Integer? = Nothing,
                                                  Optional warehouseID As Integer? = Nothing) As List(Of ReportPurchaseInvoice)
            Dim pIdParam As Integer = If(partnerID.HasValue AndAlso partnerID.Value > 0, partnerID.Value, 0)
            Dim whIdParam As Integer = If(warehouseID.HasValue AndAlso warehouseID.Value > 0, warehouseID.Value, 0)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Try
                        Return conn.Query(Of ReportPurchaseInvoice)(
                            StoredProcedures.SP_REPORT_PURCHASEINVOICES,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .PartnerID = pIdParam,
                                .WarehouseID = whIdParam
                            },
                            commandType:=CommandType.StoredProcedure
                        ).AsList()
                    Catch spEx As Exception
                        Dim sql As String = "
                        SELECT 
                            h.InvID,
                            h.InvDate,
                            ISNULL(h.ReferenceNo, N'-') AS ReferenceNo,
                            ISNULL(h.PartnerID, 0) AS PartnerID,
                            ISNULL(p.PartnerName, N'مورد نقدي') AS SupplierName,
                            ISNULL(p.Phone, N'-') AS SupplierPhone,
                            ISNULL(w.WarehouseName, N'المخزن الرئيسي') AS WarehouseName,
                            ISNULL(u.FullName, ISNULL(u.Username, N'-')) AS UserName,
                            ISNULL((SELECT COUNT(*) FROM [Sales].[InvoiceDetails] d WHERE d.InvID = h.InvID), 0) AS ItemsCount,
                            ISNULL(h.TotalAmount, 0) AS TotalAmount,
                            ISNULL(h.Discount, 0) AS Discount,
                            ISNULL(h.NetAmount, 0) AS NetAmount,
                            ISNULL(h.PaidAmount, 0) AS PaidAmount,
                            ISNULL(h.Remainder, 0) AS Remainder,
                            ISNULL(h.IsPosted, 0) AS IsPosted,
                            ISNULL(h.Notes, N'') AS Notes
                        FROM [Sales].[InvoiceHeader] h
                        LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
                        LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
                        LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
                        WHERE CAST(h.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
                          AND (h.InvType = 'Purchase' OR h.InvType = N'مشتريات')
                          AND (@PartnerID = 0 OR h.PartnerID = @PartnerID)
                          AND (@WarehouseID = 0 OR h.WarehouseID = @WarehouseID)
                        ORDER BY h.InvDate DESC, h.InvID DESC;"

                        Return conn.Query(Of ReportPurchaseInvoice)(
                            sql,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .PartnerID = pIdParam,
                                .WarehouseID = whIdParam
                            }
                        ).AsList()
                    End Try
                End Using
            Catch ex As Exception
                Throw New Exception("Error loading purchase invoices report: " & ex.Message, ex)
            End Try
        End Function

    End Class
End Namespace
