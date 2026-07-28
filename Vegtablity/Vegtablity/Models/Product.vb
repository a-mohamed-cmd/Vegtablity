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
        Public Property ProductType As Integer = 1

        Public ReadOnly Property ProductTypeName As String
            Get
                Select Case ProductType
                    Case 0
                        Return "مادة خام"
                    Case 1
                        Return "صنف عادي"
                    Case 2
                        Return "منتج مصنع"
                    Case 3
                        Return "منتج وسيط"
                    Case Else
                        Return "صنف عادي"
                End Select
            End Get
        End Property

        Public ReadOnly Property SearchText As String
            Get
                If String.IsNullOrWhiteSpace(Barcode) Then Return ProductName
                Return $"{ProductName} - {Barcode}"
            End Get
        End Property
    End Class
    Public Class ProductPricingInfo
        Public Property ProductID        As Integer
        Public Property Barcode          As String
        Public Property ProductName      As String
        Public Property UnitName         As String
        Public Property DefaultSalePrice As Decimal
        Public Property CostPrice        As Decimal
        Public Property QuotedPrice      As Decimal?
    End Class
End Namespace
