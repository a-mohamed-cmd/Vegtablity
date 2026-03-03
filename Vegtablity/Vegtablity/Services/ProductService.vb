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
    End Class
End Namespace
