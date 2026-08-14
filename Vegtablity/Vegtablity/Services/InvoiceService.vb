Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports System.Collections.ObjectModel

Namespace Services
    Public Class InvoiceService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllInvoices(invType As String) As List(Of InvoiceHeader)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of InvoiceHeader)(
                    Helpers.StoredProcedures.SP_INVOICE_GETALL,
                    New With {.InvType = invType},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetInvoiceByID(invID As Integer) As InvoiceHeader
            Using conn As IDbConnection = _dbHelper.GetConnection()
                ' 1. Get Header
                Dim header = conn.QueryFirstOrDefault(Of InvoiceHeader)(
                    Helpers.StoredProcedures.SP_INVOICE_GETBYID,
                    New With {.InvID = invID},
                    commandType:=CommandType.StoredProcedure)

                If header IsNot Nothing Then
                    ' 2. Get Details
                    Dim details = conn.Query(Of InvoiceDetail)(
                        Helpers.StoredProcedures.SP_INVOICEDETAIL_GETBYINVID,
                        New With {.InvID = invID},
                        commandType:=CommandType.StoredProcedure).AsList()

                    header.Details = New ObservableCollection(Of InvoiceDetail)(details)
                End If

                Return header
            End Using
        End Function

        Public Function SaveInvoice(header As InvoiceHeader) As Integer
            Try
                ' Convert details to XML for high-performance batch saving
                Dim detailsXml As String = ConvertDetailsToXml(header.Details)

                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@InvID", header.InvID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                    p.Add("@InvType", header.InvType)
                    p.Add("@InvDate", header.InvDate)
                    p.Add("@PartnerID", header.PartnerID)
                    p.Add("@WarehouseID", header.WarehouseID)
                    p.Add("@TotalAmount", header.TotalAmount)
                    p.Add("@Discount", header.Discount)
                    p.Add("@NetAmount", header.NetAmount)
                    p.Add("@PaidAmount", header.PaidAmount)
                    p.Add("@Remainder", header.Remainder)
                    p.Add("@UserID", header.UserID)
                    p.Add("@Notes", header.Notes)
                    p.Add("@IsPosted", header.IsPosted)
                    p.Add("@ReferenceNo", header.ReferenceNo)
                    p.Add("@PaymentAccountID", header.PaymentAccountID)
                    p.Add("@ShiftID", header.ShiftID, dbType:=DbType.Int32)
                    p.Add("@DetailsXml", detailsXml, dbType:=DbType.Xml)

                    ' استخدام الإجراء الجديد _XML لتجنب التعارض مع النسخة القديمة
                    conn.Execute(Helpers.StoredProcedures.SP_INVOICE_SAVE_XML, p, commandType:=CommandType.StoredProcedure)
                    Return p.Get(Of Integer)("@InvID")
                End Using
            Catch ex As Exception
                Dim errorMsg = "فشل حفظ الفاتورة بنظام XML: " & ex.Message
                If ex.InnerException IsNot Nothing Then
                    errorMsg &= vbCrLf & "التفاصيل: " & ex.InnerException.Message
                End If
                Throw New Exception(errorMsg, ex)
            End Try
        End Function

        Private Function ConvertDetailsToXml(details As IEnumerable(Of InvoiceDetail)) As String
            Dim sb As New Text.StringBuilder()
            sb.Append("<Details>")
            For Each d In details
                If d.ProductID > 0 Then
                    sb.AppendFormat("<Item ProductID=""{0}"" UnitPrice=""{1}"" Quantity=""{2}"" TotalPrice=""{3}"" CostPrice=""{4}"" />",
                                    d.ProductID, 
                                    d.UnitPrice.ToString("F3", System.Globalization.CultureInfo.InvariantCulture), 
                                    d.Quantity.ToString("F3", System.Globalization.CultureInfo.InvariantCulture),
                                    d.TotalPrice.ToString("F3", System.Globalization.CultureInfo.InvariantCulture), 
                                    d.CostPrice.ToString("F3", System.Globalization.CultureInfo.InvariantCulture))
                End If
            Next
            sb.Append("</Details>")
            Return sb.ToString()
        End Function

        Public Sub DeleteInvoice(invID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_INVOICE_DELETE,
                    New With {.InvID = invID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ''' <summary>Returns paged filtered invoice list plus total count for the dashboard.</summary>
        Public Function GetFilteredInvoices(
                Optional invType As String = Nothing,
                Optional dateFrom As Date? = Nothing,
                Optional dateTo As Date? = Nothing,
                Optional isPosted As Boolean? = Nothing,
                Optional searchText As String = Nothing,
                Optional pageNumber As Integer = 0,
                Optional pageSize As Integer = 20) As (Items As List(Of InvoiceListItem), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Using multi = conn.QueryMultiple(
                        Helpers.StoredProcedures.SP_INVOICE_GET_FILTERED,
                        New With {
                            .InvType    = invType,
                            .DateFrom   = dateFrom,
                            .DateTo     = dateTo,
                            .IsPosted   = isPosted,
                            .SearchText = searchText,
                            .PageNumber = pageNumber,
                            .PageSize   = pageSize
                        },
                        commandType:=CommandType.StoredProcedure)
                    Dim items = multi.Read(Of InvoiceListItem)().ToList()
                    Dim total = multi.ReadSingle(Of Integer)()
                    Return (items, total)
                End Using
            End Using
        End Function

        ''' <summary>Returns KPI summary stats for dashboard cards.</summary>
        Public Function GetDashboardStats(
                Optional dateFrom As Date? = Nothing,
                Optional dateTo As Date? = Nothing) As DashboardStats
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QuerySingleOrDefault(Of DashboardStats)(
                    Helpers.StoredProcedures.SP_INVOICE_GET_DASHBOARD_STATS,
                    New With {.DateFrom = dateFrom, .DateTo = dateTo},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        ''' <summary>Adds a payment to a posted invoice and creates the journal entry.</summary>
        Public Function AddPayment(invID As Integer, amount As Decimal, paymentAccountID As Integer, userID As Integer) As Boolean
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim result = conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_INVOICE_ADD_PAYMENT,
                    New With {
                        .InvID            = invID,
                        .PaymentAmount    = amount,
                        .PaymentAccountID = paymentAccountID,
                        .UserID           = userID
                    },
                    commandType:=CommandType.StoredProcedure)
                Return result = 1
            End Using
        End Function

        ''' <summary>Loads a full InvoiceHeader with its Details from DB (for open-in-form).</summary>
        Public Function LoadInvoiceForEdit(invID As Integer) As Models.InvoiceHeader
            Using conn As IDbConnection = _dbHelper.GetConnection()
                ' Load header
                Dim header = conn.QuerySingleOrDefault(Of Models.InvoiceHeader)(
                    Helpers.StoredProcedures.SP_INVOICE_GETBYID,
                    New With {.InvID = invID},
                    commandType:=CommandType.StoredProcedure)
                If header Is Nothing Then Return Nothing

                ' Load details
                Dim details = conn.Query(Of Models.InvoiceDetail)(
                    Helpers.StoredProcedures.SP_INVOICEDETAILS_GETBYINVID,
                    New With {.InvID = invID},
                    commandType:=CommandType.StoredProcedure).ToList()

                header.Details = New System.Collections.ObjectModel.ObservableCollection(Of Models.InvoiceDetail)(details)
                Return header
            End Using
        End Function
        Public Function GetInvoicesPaged(pageNumber As Integer, pageSize As Integer, Optional invType As String = "Sales", Optional searchText As String = Nothing) As PagedResult(Of InvoiceHeader)
            Dim result As New PagedResult(Of InvoiceHeader)()
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)
                    p.Add("@InvType", invType)
                    p.Add("@SearchText", searchText)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_INVOICE_GETPAGED, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of InvoiceHeader)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Handle or log
            End Try
            Return result
        End Function

        ''' <summary>
        ''' ترحيل فاتورة:
        ''' → يقوم بتغيير الحالة إلى IsPosted = 1
        ''' → الـ SQL Trigger يتكفل بتحديث المخزون والقيود المحاسبية آلياً
        ''' </summary>
        Public Sub PostInvoice(invID As Integer, userID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_INVOICE_POST,
                    New With {.InvID = invID, .UserID = userID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ''' <summary>
        ''' إلغاء ترحيل فاتورة مرحّلة:
        ''' → يقوم بتغيير الحالة إلى IsPosted = 0
        ''' → الـ SQL Trigger يتكفل بعكس حركة المخزون وحذف القيود المحاسبية آلياً
        ''' </summary>
        Public Sub UnpostInvoice(invID As Integer, userID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_INVOICE_UNPOST,
                    New With {.InvID = invID, .UserID = userID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
        ''' <summary>
        ''' يجلب بيانات الفاتورة المخصصة للطباعة من الإجراء المخزن sp_Report_InvoicePrint
        ''' </summary>
        Public Function GetInvoiceForReport(invID As Integer) As Models.InvoiceReportData
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_REPORT_INVOICE_PRINT, New With {.InvID = invID}, commandType:=CommandType.StoredProcedure)
                    Dim result As New Models.InvoiceReportData()
                    result.Header = multi.Read(Of Models.InvoiceReportHeader)().FirstOrDefault()
                    result.Details = multi.Read(Of Models.InvoiceReportItem)().ToList()
                    Return result
                End Using
            End Using
        End Function
    End Class
End Namespace

