Imports Dapper
Imports System.Data
Imports Vegtablity.Models

Namespace Services
    Public Class SettingsService
        Private ReadOnly _dbHelper As New DatabaseHelper()

        Public Function GetCompanyInfo() As CompanyInfo
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim info = conn.Query(Of CompanyInfo)(
                    Helpers.StoredProcedures.SP_COMPANY_SETTINGS_GET,
                    commandType:=CommandType.StoredProcedure
                ).FirstOrDefault()
                Return info
            End Using
        End Function

        Public Sub SaveCompanyInfo(info As CompanyInfo)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_COMPANY_SETTINGS_SAVE,
                    New With {
                        .CompanyName = info.CompanyName,
                        .Address = info.Address,
                        .Phone = info.Phone,
                        .Email = info.Email,
                        .Logo = info.Logo,
                        .CurrencySymbol = info.CurrencySymbol,
                        .UnifiedPartnerSearch = info.UnifiedPartnerSearch,
                        .UseDetailedInvoiceDesign = info.UseDetailedInvoiceDesign,
                        .UseCustomInvoiceDesign = info.UseCustomInvoiceDesign,
                        .ProductionMode = info.ProductionMode,
                        .EnableDailyOrders = info.EnableDailyOrders,
                        .DeliverySystemMode = info.DeliverySystemMode
                    },
                    commandType:=CommandType.StoredProcedure
                )
            End Using
        End Sub

        ' === Units ===
        Public Function GetAllUnits() As IEnumerable(Of Unit)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Unit)(Helpers.StoredProcedures.SP_UNIT_GETALL, commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub SaveUnit(u As Unit)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_UNIT_SAVE, New With {.UnitID = u.UnitID, .UnitName = u.UnitName}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteUnit(unitID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_UNIT_DELETE, New With {.UnitID = unitID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' === Categories ===
        Public Function GetAllCategories() As IEnumerable(Of Category)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Category)(Helpers.StoredProcedures.SP_CATEGORY_GETALL, commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub SaveCategory(c As Category)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_CATEGORY_SAVE, New With {.CatID = c.CatID, .CatName = c.CatName}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteCategory(catID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_CATEGORY_DELETE, New With {.CatID = catID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' === Warehouses ===
        Public Function GetAllWarehouses() As IEnumerable(Of Warehouse)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Warehouse)(Helpers.StoredProcedures.SP_WAREHOUSE_GETALL, commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub SaveWarehouse(w As Warehouse)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_WAREHOUSE_SAVE, New With {
                    .WarehouseID = w.WarehouseID,
                    .WarehouseName = w.WarehouseName,
                    .Address = w.Address,
                    .KeeperName = w.KeeperName,
                    .AccountID = w.AccountID
                }, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteWarehouse(warehouseID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_WAREHOUSE_DELETE, New With {.WarehouseID = warehouseID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

    End Class
End Namespace
