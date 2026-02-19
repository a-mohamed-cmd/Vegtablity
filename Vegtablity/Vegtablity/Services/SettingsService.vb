Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class SettingsService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' ===== Units (الوحدات) =====

        Public Function GetAllUnits() As List(Of Unit)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Unit)(
                    Helpers.StoredProcedures.SP_UNIT_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function SaveUnit(unit As Unit) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_UNIT_SAVE,
                    New With {unit.UnitID, unit.UnitName},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteUnit(unitID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_UNIT_DELETE,
                    New With {.UnitID = unitID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ===== Categories (التصنيفات) =====

        Public Function GetAllCategories() As List(Of Category)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Category)(
                    Helpers.StoredProcedures.SP_CATEGORY_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function SaveCategory(cat As Category) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_CATEGORY_SAVE,
                    New With {cat.CatID, cat.CatName},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteCategory(catID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_CATEGORY_DELETE,
                    New With {.CatID = catID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ===== Warehouses (المخازن) =====

        Public Function GetAllWarehouses() As List(Of Warehouse)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Warehouse)(
                    Helpers.StoredProcedures.SP_WAREHOUSE_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function SaveWarehouse(wh As Warehouse) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_WAREHOUSE_SAVE,
                    New With {wh.WarehouseID, wh.WarehouseName, wh.Address, wh.KeeperName},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteWarehouse(whID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_WAREHOUSE_DELETE,
                    New With {.WarehouseID = whID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace
