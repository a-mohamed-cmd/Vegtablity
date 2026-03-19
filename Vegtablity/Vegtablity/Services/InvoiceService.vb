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
            Using conn As IDbConnection = _dbHelper.GetConnection()
                If conn.State = ConnectionState.Closed Then conn.Open()
                
                Using tx = conn.BeginTransaction()
                    Try
                        ' 1. Save Header
                        Dim newInvID = conn.ExecuteScalar(Of Integer)(
                            Helpers.StoredProcedures.SP_INVOICE_SAVE,
                            New With {
                                .InvID = header.InvID,
                                .InvType = header.InvType,
                                .InvDate = header.InvDate,
                                .PartnerID = header.PartnerID,
                                .WarehouseID = header.WarehouseID,
                                .TotalAmount = header.TotalAmount,
                                .Discount = header.Discount,
                                .NetAmount = header.NetAmount,
                                .PaidAmount = header.PaidAmount,
                                .Remainder = header.Remainder,
                                .UserID = header.UserID,
                                .Notes = header.Notes,
                                .IsPosted = header.IsPosted,
                                .ReferenceNo = header.ReferenceNo,
                                .PaymentAccountID = header.PaymentAccountID
                            },
                            commandType:=CommandType.StoredProcedure,
                            transaction:=tx)

                        header.InvID = newInvID

                        ' 2. Delete existing details (clean slate for updates)
                        conn.Execute(
                            Helpers.StoredProcedures.SP_INVOICEDETAIL_DELETEBYINVID,
                            New With {.InvID = newInvID},
                            commandType:=CommandType.StoredProcedure,
                            transaction:=tx)

                        ' 3. Insert new details
                        For Each detail In header.Details
                            detail.InvID = newInvID
                            conn.Execute(
                                Helpers.StoredProcedures.SP_INVOICEDETAIL_SAVE,
                                New With {
                                    .InvID = detail.InvID,
                                    .ProductID = detail.ProductID,
                                    .UnitPrice = detail.UnitPrice,
                                    .Quantity = detail.Quantity,
                                    .TotalPrice = detail.TotalPrice,
                                    .CostPrice = detail.CostPrice
                                },
                                commandType:=CommandType.StoredProcedure,
                                transaction:=tx)
                        Next

                        tx.Commit()
                        Return newInvID
                    Catch ex As Exception
                        tx.Rollback()
                        Dim errorMsg = "فشل حفظ الفاتورة: " & ex.Message
                        If ex.InnerException IsNot Nothing Then
                            errorMsg &= vbCrLf & "التفاصيل: " & ex.InnerException.Message
                        End If
                        Throw New Exception(errorMsg, ex)
                    End Try
                End Using
            End Using
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
        ''' إلغاء ترحيل فاتورة مرحّلة:
        ''' → يعكس حركة المخزون
        ''' → يحذف القيود المحاسبية
        ''' → يُعيد IsPosted = 0
        ''' بعدها المستخدم يعدّل ويُرحّل من جديد بالطريقة المعتادة.
        ''' </summary>
        Public Sub UnpostInvoice(invID As Integer, userID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_INVOICE_UNPOST,
                    New With {.InvID = invID, .UserID = userID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace

