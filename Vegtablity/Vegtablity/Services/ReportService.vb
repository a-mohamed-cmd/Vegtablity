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
        Public Function GetUnpaidInvoicesAging(asOfDate As DateTime?) As List(Of ReportUnpaidInvoice)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of ReportUnpaidInvoice)(
                        StoredProcedures.SP_REPORT_UNPAIDINVOICESAGING,
                        New With {.AsOfDate = asOfDate},
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

    End Class
End Namespace
