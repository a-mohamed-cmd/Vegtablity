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
                                .ReferenceNo = header.ReferenceNo
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
    End Class
End Namespace
