Namespace Models
    Public Class Product
        Public Property ProductID As Integer
        Public Property ProductName As String
        Public Property ProductNameEn As String
        Public Property Barcode As String
        Public Property CategoryID As Integer
        Public Property CatName As String          ' JOIN from Categories
        Public Property UnitID As Integer
        Public Property UnitName As String          ' JOIN from Units
        Public Property PurchasePrice As Decimal
        Public Property SalePrice As Decimal
        Public Property AlertQty As Decimal
        Public Property IsActive As Boolean
    End Class
End Namespace
