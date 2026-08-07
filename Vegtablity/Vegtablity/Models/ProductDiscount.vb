Imports System.Collections.ObjectModel

Namespace Models
    Public Class ProductDiscount
        Public Property DiscountID As Integer
        Public Property DiscountName As String
        Public Property DiscountType As Byte ' 1: Percentage %, 2: Fixed Amount (KWD), 3: Bundle/Tier
        Public Property DiscountValue As Decimal
        Public Property MinQuantity As Decimal = 1.0D
        Public Property IsActive As Boolean = True
        Public Property CreatedDate As DateTime?
        Public Property ProductCount As Integer

        Public ReadOnly Property DiscountTypeFormatted As String
            Get
                Select Case DiscountType
                    Case 1
                        Return "نسبة مئوية (%)"
                    Case 2
                        Return "خصم مقطوع (مبلغ)"
                    Case 3
                        Return "باقة كميات (درجات)"
                    Case Else
                        Return "غير محدد"
                End Select
            End Get
        End Property

        Public ReadOnly Property DiscountValueFormatted As String
            Get
                If DiscountType = 1 Then
                    Return DiscountValue.ToString("N1") & " %"
                Else
                    Return DiscountValue.ToString("N3") & " د.ك"
                End If
            End Get
        End Property
    End Class

    Public Class ProductDiscountItemBinding
        Public Property ProductID As Integer
        Public Property ProductName As String
        Public Property Barcode As String
        Public Property ProductType As Integer ' 1: Normal, 2: Final Manufactured
        Public Property SalePrice As Decimal
        Public Property PurchasePrice As Decimal
        Public Property UnitName As String
        Public Property IsSelected As Boolean

        Public ReadOnly Property ProductTypeFormatted As String
            Get
                If ProductType = 2 Then
                    Return "صنف مصنّع"
                Else
                    Return "صنف عادي"
                End If
            End Get
        End Property
    End Class
End Namespace
