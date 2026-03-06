Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class InventoryService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetStockByProduct(productID As Integer, warehouseID As Integer) As Decimal
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Decimal)(
                    Helpers.StoredProcedures.SP_STOCK_GETBYPRODUCT,
                    New With {.ProductID = productID, .WarehouseID = warehouseID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        ''' <summary>Returns the weighted average cost price for a product in a specific warehouse.</summary>
        Public Function GetAvgCostByProduct(productID As Integer, warehouseID As Integer) As Decimal
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim sql = "SELECT ISNULL(AvgCostPrice, 0) FROM [Inventory].[ProductStock] WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID"
                Return conn.ExecuteScalar(Of Decimal)(sql, New With {.ProductID = productID, .WarehouseID = warehouseID})
            End Using
        End Function

        Public Function GetAllProducts() As List(Of Product)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetProductByID(productID As Integer) As Product
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_GETBYID,
                    New With {.ProductID = productID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Function SaveProduct(p As Product) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_PRODUCT_SAVE,
                    New With {p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode, p.CategoryID, p.UnitID, p.PurchasePrice, p.SalePrice, p.AlertQty},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteProduct(productID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PRODUCT_DELETE,
                    New With {.ProductID = productID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function SearchProducts(searchText As String) As List(Of Product)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_SEARCH,
                    New With {.SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

#Region "Product Card Methods"
        Public Function GetProductCardSummary(productID As Integer) As ProductCardSummary
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of ProductCardSummary)(
                    Helpers.StoredProcedures.SP_PRODUCTCARD_GETSUMMARY,
                    New With {.ProductID = productID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Function GetProductMovements(productID As Integer, filterType As String,
                                            Optional pageNumber As Integer = 1,
                                            Optional pageSize As Integer = 15) As List(Of ProductMovement)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of ProductMovement)(
                    Helpers.StoredProcedures.SP_PRODUCTCARD_GETMOVEMENTS,
                    New With {.ProductID = productID, .FilterType = filterType,
                              .PageNumber = pageNumber, .PageSize = pageSize},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetProductChartData(productID As Integer,
                                            Optional monthsBack As Integer = 12) As List(Of ChartDataPoint)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of ChartDataPoint)(
                    Helpers.StoredProcedures.SP_PRODUCTCARD_GETCHARTDATA,
                    New With {.ProductID = productID, .MonthsBack = monthsBack},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function
#End Region
    End Class
End Namespace
