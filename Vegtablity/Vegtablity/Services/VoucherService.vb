Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class VoucherService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllVouchers(voucherType As String) As List(Of Voucher)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Voucher)(
                    Helpers.StoredProcedures.SP_VOUCHER_GETALL,
                    New With {.VoucherType = voucherType},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetPagedVouchers(voucherType As String, pageIndex As Integer, pageSize As Integer, searchText As String, ByRef totalCount As Integer) As List(Of Voucher)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@VoucherType", voucherType)
                    p.Add("@PageIndex", pageIndex)
                    p.Add("@PageSize", pageSize)
                    p.Add("@SearchText", If(String.IsNullOrWhiteSpace(searchText), Nothing, searchText.Trim()))
                    p.Add("@TotalCount", dbType:=DbType.Int32, direction:=ParameterDirection.Output)

                    Dim result = conn.Query(Of Voucher)(
                        Helpers.StoredProcedures.SP_VOUCHER_GETPAGED,
                        p,
                        commandType:=CommandType.StoredProcedure).AsList()

                    totalCount = p.Get(Of Integer)("@TotalCount")
                    Return result
                End Using
            Catch ex As Exception
                ' Fallback in-memory paging for older DB instances without migration 41
                Dim fullList As List(Of Voucher)
                If Not String.IsNullOrWhiteSpace(searchText) Then
                    fullList = SearchVouchers(voucherType, searchText)
                Else
                    fullList = GetAllVouchers(voucherType)
                End If
                totalCount = If(fullList IsNot Nothing, fullList.Count, 0)
                If fullList Is Nothing Then Return New List(Of Voucher)()
                Return fullList.Skip((pageIndex - 1) * pageSize).Take(pageSize).ToList()
            End Try
        End Function

        Public Function GetVoucherByID(voucherID As Integer) As Voucher
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of Voucher)(
                    Helpers.StoredProcedures.SP_VOUCHER_GETBYID,
                    New With {.VoucherID = voucherID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Function SaveVoucher(v As Voucher) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_VOUCHER_SAVE,
                    New With {v.VoucherID, v.VoucherType, v.VoucherDate, v.PartnerID, v.AccountID,
                              v.Amount, v.Description, v.PaymentMethod, v.UserID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteVoucher(voucherID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_VOUCHER_DELETE,
                    New With {.VoucherID = voucherID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function SearchVouchers(voucherType As String, searchText As String) As List(Of Voucher)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Voucher)(
                    Helpers.StoredProcedures.SP_VOUCHER_SEARCH,
                    New With {.VoucherType = voucherType, .SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Sub PostVoucher(voucherID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_VOUCHER_POST,
                    New With {.VoucherID = voucherID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub UnpostVoucher(voucherID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_VOUCHER_UNPOST,
                    New With {.VoucherID = voucherID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace
