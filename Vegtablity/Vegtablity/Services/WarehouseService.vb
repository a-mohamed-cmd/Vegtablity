Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class WarehouseService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllWarehouses() As List(Of Warehouse)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Warehouse)(
                    Helpers.StoredProcedures.SP_WAREHOUSE_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function
    End Class
End Namespace
