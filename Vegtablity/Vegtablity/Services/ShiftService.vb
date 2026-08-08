Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class ShiftService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllShifts() As List(Of Shift)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of Shift)(
                        Helpers.StoredProcedures.SP_SHIFT_GETALL,
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of Shift)()
            End Try
        End Function

        Public Function GetShiftSummary(shiftID As Integer) As Shift
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.QueryFirstOrDefault(Of Shift)(
                        Helpers.StoredProcedures.SP_SHIFT_GETSUMMARY,
                        New With {.ShiftID = shiftID},
                        commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Return Nothing
            End Try
        End Function

        Public Function GetShiftVouchers(shiftID As Integer) As List(Of Voucher)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of Voucher)(
                        Helpers.StoredProcedures.SP_SHIFT_GETVOUCHERS,
                        New With {.ShiftID = shiftID},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of Voucher)()
            End Try
        End Function

        Public Function GetShiftInvoices(shiftID As Integer, invType As String) As List(Of InvoiceHeader)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of InvoiceHeader)(
                        Helpers.StoredProcedures.SP_INVOICE_GETALL_POS,
                        New With {.InvType = invType, .ShiftID = shiftID},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of InvoiceHeader)()
            End Try
        End Function

        Public Function GetShiftPaymentMethodTotals(shiftID As Integer) As List(Of PaymentMethodSummary)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of PaymentMethodSummary)(
                        Helpers.StoredProcedures.SP_SHIFT_GETPAYMENTMETHODTOTALS,
                        New With {.ShiftID = shiftID},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of PaymentMethodSummary)()
            End Try
        End Function
    End Class
End Namespace
