Imports System.Data
Imports System.Xml.Linq
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class RecipeService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllRecipes() As List(Of Recipe)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Recipe)(
                    Helpers.StoredProcedures.SP_RECIPE_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetRecipesPaged(pageNumber As Integer, pageSize As Integer) As (Data As List(Of Recipe), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageNumber", pageNumber)
                p.Add("@PageSize", pageSize)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_RECIPE_GETALL, p, commandType:=CommandType.StoredProcedure)
                    Dim totalCount = multi.Read(Of Integer)().FirstOrDefault()
                    Dim data = multi.Read(Of Recipe)().ToList()
                    Return (data, totalCount)
                End Using
            End Using
        End Function

        Public Function GetRecipeByProduct(productID As Integer, Optional warehouseID As Integer? = Nothing) As Recipe
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@ProductID", productID)
                p.Add("@WarehouseID", warehouseID)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_RECIPE_GETBYPRODUCT, p, commandType:=CommandType.StoredProcedure)
                    Dim recipeHeader = multi.Read(Of Recipe)().FirstOrDefault()
                    If recipeHeader IsNot Nothing Then
                        recipeHeader.Details = multi.Read(Of RecipeDetail)().ToList()
                    End If
                    Return recipeHeader
                End Using
            End Using
        End Function

        Public Function SaveRecipe(productID As Integer, notes As String, details As List(Of RecipeDetail), Optional warehouseID As Integer? = Nothing) As Integer
            ' Construct XML format: <Details><Detail><IngredientProductID>1</IngredientProductID><Qty>0.5</Qty><Cost>10</Cost></Detail></Details>
            Dim xmlDoc As New XElement("Details",
                From d In details
                Select New XElement("Detail",
                    New XElement("IngredientProductID", d.IngredientProductID),
                    New XElement("Qty", d.Qty),
                    New XElement("Cost", d.UnitCost)
                )
            )

            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@ProductID", productID)
                p.Add("@Notes", notes)
                p.Add("@DetailsXML", xmlDoc.ToString())
                p.Add("@WarehouseID", warehouseID)

                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_RECIPE_SAVE_XML,
                    p,
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteRecipe(recipeID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_RECIPE_DELETE,
                    New With {.RecipeID = recipeID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace
