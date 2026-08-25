Imports System.ComponentModel
Imports Vegtablity.ViewModels

Namespace Models
    Public Class PurchaseQuoteDetail
        Inherits BaseViewModel

        Private _detailID As Integer
        Private _purchaseQuoteID As Integer
        Private _productID As Integer
        Private _productName As String
        Private _barcode As String
        Private _unitName As String
        Private _quantity As Decimal = 1
        Private _unitPrice As Decimal
        Private _isUnmatched As Boolean = False

        Public Property DetailID As Integer
            Get
                Return _detailID
            End Get
            Set(value As Integer)
                SetProperty(_detailID, value)
            End Set
        End Property

        Public Property PurchaseQuoteID As Integer
            Get
                Return _purchaseQuoteID
            End Get
            Set(value As Integer)
                SetProperty(_purchaseQuoteID, value)
            End Set
        End Property

        Public Property ProductID As Integer
            Get
                Return _productID
            End Get
            Set(value As Integer)
                SetProperty(_productID, value)
            End Set
        End Property

        Public Property ProductName As String
            Get
                Return _productName
            End Get
            Set(value As String)
                SetProperty(_productName, value)
            End Set
        End Property

        Public Property Barcode As String
            Get
                Return _barcode
            End Get
            Set(value As String)
                SetProperty(_barcode, value)
            End Set
        End Property

        Public Property UnitName As String
            Get
                Return _unitName
            End Get
            Set(value As String)
                SetProperty(_unitName, value)
            End Set
        End Property

        Public Property Quantity As Decimal
            Get
                Return _quantity
            End Get
            Set(value As Decimal)
                SetProperty(_quantity, value)
            End Set
        End Property

        Public Property UnitPrice As Decimal
            Get
                Return _unitPrice
            End Get
            Set(value As Decimal)
                SetProperty(_unitPrice, value)
                OnPropertyChanged(NameOf(QuotedPrice))
            End Set
        End Property

        ''' <summary>
        ''' Alias for UnitPrice to support unified QuoteItemRowControl binding
        ''' </summary>
        Public Property QuotedPrice As Decimal
            Get
                Return _unitPrice
            End Get
            Set(value As Decimal)
                UnitPrice = value
            End Set
        End Property

        ''' <summary>
        ''' Used during Excel import to mark items where barcode wasn't found in DB
        ''' </summary>
        Public Property IsUnmatched As Boolean
            Get
                Return _isUnmatched
            End Get
            Set(value As Boolean)
                SetProperty(_isUnmatched, value)
            End Set
        End Property

        ''' <summary>
        ''' Total for this row
        ''' </summary>
        Public ReadOnly Property Total As Decimal
            Get
                Return Quantity * UnitPrice
            End Get
        End Property

        ' Trigger Total update when Qty or Price changes
        Protected Overrides Sub OnPropertyChanged(<System.Runtime.CompilerServices.CallerMemberName> Optional propertyName As String = Nothing)
            MyBase.OnPropertyChanged(propertyName)
            If propertyName = NameOf(Quantity) OrElse propertyName = NameOf(UnitPrice) Then
                OnPropertyChanged(NameOf(Total))
            End If
        End Sub
    End Class
End Namespace
