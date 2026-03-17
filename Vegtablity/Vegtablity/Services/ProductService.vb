Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class ProductService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllProducts() As List(Of Product)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function SearchProducts(searchText As String) As List(Of Product)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_SEARCH,
                    New With {.SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetProductsPaged(pageNumber As Integer, pageSize As Integer, Optional searchText As String = Nothing) As PagedResult(Of Product)
            Dim result As New PagedResult(Of Product)()
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)
                    p.Add("@SearchText", searchText)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_PRODUCT_GETPAGED, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of Product)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Fallback or log error
            End Try
            Return result
        End Function
    End Class
End Namespace
