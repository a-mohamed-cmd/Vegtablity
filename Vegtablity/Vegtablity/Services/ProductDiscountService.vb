Imports Dapper
Imports System.Data
Imports System.Xml.Linq
Imports Vegtablity.Models

Namespace Services
    Public Class ProductDiscountService
        Private ReadOnly _dbHelper As New DatabaseHelper()

        Public Function GetAllDiscounts() As IEnumerable(Of ProductDiscount)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of ProductDiscount)(
                    Helpers.StoredProcedures.SP_PRODUCTDISCOUNTS_GETALL,
                    commandType:=CommandType.StoredProcedure
                )
            End Using
        End Function

        Public Function GetProductsForDiscounts() As IEnumerable(Of ProductDiscountItemBinding)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of ProductDiscountItemBinding)(
                    Helpers.StoredProcedures.SP_PRODUCTS_GETFORDISCOUNTS,
                    commandType:=CommandType.StoredProcedure
                )
            End Using
        End Function

        Public Function GetAttachedProductIDs(discountID As Integer) As IEnumerable(Of Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Integer)(
                    Helpers.StoredProcedures.SP_PRODUCTDISCOUNTS_GETPRODUCTIDS,
                    New With {.DiscountID = discountID},
                    commandType:=CommandType.StoredProcedure
                )
            End Using
        End Function

        Public Function SaveDiscount(discount As ProductDiscount, selectedProductIDs As IEnumerable(Of Integer)) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                ' Build XML payload of selected ProductIDs
                Dim xmlPayload As String = Nothing
                If selectedProductIDs IsNot Nothing AndAlso selectedProductIDs.Any() Then
                    Dim xmlDoc As New XElement("Products",
                        selectedProductIDs.Select(Function(pid) New XElement("Product", New XAttribute("ProductID", pid)))
                    )
                    xmlPayload = xmlDoc.ToString()
                End If

                Dim p As New DynamicParameters()
                p.Add("@DiscountID", discount.DiscountID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                p.Add("@DiscountName", discount.DiscountName)
                p.Add("@DiscountType", discount.DiscountType)
                p.Add("@DiscountValue", discount.DiscountValue)
                p.Add("@MinQuantity", discount.MinQuantity)
                p.Add("@IsActive", discount.IsActive)
                p.Add("@ProductIDsXml", xmlPayload, dbType:=DbType.Xml)

                conn.Execute(Helpers.StoredProcedures.SP_PRODUCTDISCOUNTS_SAVE_XML, p, commandType:=CommandType.StoredProcedure)
                Return p.Get(Of Integer)("@DiscountID")
            End Using
        End Function

        Public Sub DeleteDiscount(discountID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PRODUCTDISCOUNTS_DELETE,
                    New With {.DiscountID = discountID},
                    commandType:=CommandType.StoredProcedure
                )
            End Using
        End Sub
    End Class
End Namespace
