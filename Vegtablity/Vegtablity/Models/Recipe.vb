Imports System
Imports Vegtablity.ViewModels

Namespace Models
    Public Class Recipe
        Public Property RecipeID As Integer
        Public Property ProductID As Integer
        Public Property ProductName As String
        Public Property Barcode As String
        Public Property ProductType As Integer
        Public Property TotalCost As Decimal
        Public Property Notes As String
        Public Property CreatedDate As DateTime
        Public Property IngredientsCount As Integer
        Public Property Details As List(Of RecipeDetail)

        Public Sub New()
            Details = New List(Of RecipeDetail)()
        End Sub
    End Class

    Public Class RecipeDetail
        Inherits BaseViewModel

        Private _recipeDetailID As Integer
        Public Property RecipeDetailID As Integer
            Get
                Return _recipeDetailID
            End Get
            Set(value As Integer)
                SetProperty(_recipeDetailID, value)
            End Set
        End Property

        Private _recipeID As Integer
        Public Property RecipeID As Integer
            Get
                Return _recipeID
            End Get
            Set(value As Integer)
                SetProperty(_recipeID, value)
            End Set
        End Property

        Private _ingredientProductID As Integer
        Public Property IngredientProductID As Integer
            Get
                Return _ingredientProductID
            End Get
            Set(value As Integer)
                SetProperty(_ingredientProductID, value)
            End Set
        End Property

        Private _ingredientName As String
        Public Property IngredientName As String
            Get
                Return _ingredientName
            End Get
            Set(value As String)
                SetProperty(_ingredientName, value)
            End Set
        End Property

        Private _ingredientBarcode As String
        Public Property IngredientBarcode As String
            Get
                Return _ingredientBarcode
            End Get
            Set(value As String)
                SetProperty(_ingredientBarcode, value)
            End Set
        End Property

        Private _ingredientType As Integer
        Public Property IngredientType As Integer
            Get
                Return _ingredientType
            End Get
            Set(value As Integer)
                SetProperty(_ingredientType, value)
            End Set
        End Property

        Private _unitName As String
        Public Property UnitName As String
            Get
                Return _unitName
            End Get
            Set(value As String)
                SetProperty(_unitName, value)
            End Set
        End Property

        Private _qty As Decimal = 1
        Public Property Qty As Decimal
            Get
                Return _qty
            End Get
            Set(value As Decimal)
                If SetProperty(_qty, value) Then
                    RecalculateLineCost()
                End If
            End Set
        End Property

        Private _unitCost As Decimal
        Public Property UnitCost As Decimal
            Get
                Return _unitCost
            End Get
            Set(value As Decimal)
                If SetProperty(_unitCost, value) Then
                    RecalculateLineCost()
                End If
            End Set
        End Property

        Private _lineCost As Decimal
        Public Property LineCost As Decimal
            Get
                Return _lineCost
            End Get
            Set(value As Decimal)
                SetProperty(_lineCost, value)
            End Set
        End Property

        Private Sub RecalculateLineCost()
            LineCost = Qty * UnitCost
        End Sub
    End Class
End Namespace

