Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports System.Collections.ObjectModel

Namespace Services
    Public Class OrderService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetDailyOrders(deliveryDate As DateTime) As List(Of DailyOrder)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim formattedDate = deliveryDate.ToString("yyyy-MM-dd")
                    Return conn.Query(Of DailyOrder)(
                        Helpers.StoredProcedures.SP_TEMPORDER_GETDAILYDELIVERIES,
                        New With {.DeliveryDate = formattedDate},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of DailyOrder)()
            End Try
        End Function

        Public Function GetInvoiceDetails(invID As Integer) As List(Of InvoiceDetail)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of InvoiceDetail)(
                        Helpers.StoredProcedures.SP_INVOICEDETAIL_GETBYINVID,
                        New With {.InvID = invID},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of InvoiceDetail)()
            End Try
        End Function
    End Class
End Namespace
