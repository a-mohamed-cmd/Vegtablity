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
                Return conn.ExecuteScalar(Of Decimal)(
                    Helpers.StoredProcedures.SP_INVENTORY_GETAVGCOSTByPRODUCT,
                    New With {.ProductID = productID, .WarehouseID = warehouseID},
                    commandType:=CommandType.StoredProcedure)
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
                    New With {p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode, p.CategoryID, p.UnitID, p.PurchasePrice, p.SalePrice, p.AlertQty, p.ProductType},
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

        Public Function QuickAddProduct(barcode As String, productName As String, purchasePrice As Decimal, salePrice As Decimal) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_PRODUCT_QUICKADD,
                    New With {
                        .Barcode = barcode,
                        .ProductName = productName,
                        .PurchasePrice = purchasePrice,
                        .SalePrice = salePrice
                    },
                    commandType:=CommandType.StoredProcedure)
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
                ' Handle or log
            End Try
            Return result
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

        Public Function GetProductStockByWarehouse(productID As Integer) As List(Of WarehouseStock)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of WarehouseStock)(
                    Helpers.StoredProcedures.SP_PRODUCTCARD_GETSTOCKBYWAREHOUSE,
                    New With {.ProductID = productID},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Sub UpdateProductQuickDetails(productID As Integer, productName As String, barcode As String, salePrice As Decimal)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PRODUCTCARD_UPDATEQUICKDETAILS,
                    New With {
                        .ProductID = productID,
                        .ProductName = productName,
                        .Barcode = barcode,
                        .SalePrice = salePrice
                    },
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
#End Region
    End Class
End Namespace
