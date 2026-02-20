Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class InventoryService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' ===== Products (الأصناف) =====

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

        Public Function GetProductByBarcode(barcode As String) As Product
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of Product)(
                    Helpers.StoredProcedures.SP_PRODUCT_GETBYBARCODE,
                    New With {.Barcode = barcode},
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
    End Class
End Namespace
