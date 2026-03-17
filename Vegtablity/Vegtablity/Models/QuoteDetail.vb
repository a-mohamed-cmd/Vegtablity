Imports System.ComponentModel

Namespace Models
    Public Class QuoteDetail
        Implements INotifyPropertyChanged

        Private _quoteDetailID As Integer
        Public Property QuoteDetailID As Integer
            Get
                Return _quoteDetailID
            End Get
            Set(value As Integer)
                _quoteDetailID = value
                OnPropertyChanged(NameOf(QuoteDetailID))
            End Set
        End Property

        Private _quoteID As Integer
        Public Property QuoteID As Integer
            Get
                Return _quoteID
            End Get
            Set(value As Integer)
                _quoteID = value
                OnPropertyChanged(NameOf(QuoteID))
            End Set
        End Property

        Private _productID As Integer
        Public Property ProductID As Integer
            Get
                Return _productID
            End Get
            Set(value As Integer)
                _productID = value
                OnPropertyChanged(NameOf(ProductID))
            End Set
        End Property

        Private _quotedPrice As Decimal
        Public Property QuotedPrice As Decimal
            Get
                Return _quotedPrice
            End Get
            Set(value As Decimal)
                _quotedPrice = value
                OnPropertyChanged(NameOf(QuotedPrice))
            End Set
        End Property

        Private _quantity As Decimal = 1
        Public Property Quantity As Decimal
            Get
                Return _quantity
            End Get
            Set(value As Decimal)
                _quantity = value
                OnPropertyChanged(NameOf(Quantity))
            End Set
        End Property

        ' Read-only properties for UI
        Private _productName As String
        Public Property ProductName As String
            Get
                Return _productName
            End Get
            Set(value As String)
                _productName = value
                OnPropertyChanged(NameOf(ProductName))
            End Set
        End Property

        Private _barcode As String
        Public Property Barcode As String
            Get
                Return _barcode
            End Get
            Set(value As String)
                _barcode = value
                OnPropertyChanged(NameOf(Barcode))
            End Set
        End Property

        Private _unitName As String
        Public Property UnitName As String
            Get
                Return _unitName
            End Get
            Set(value As String)
                _unitName = value
                OnPropertyChanged(NameOf(UnitName))
            End Set
        End Property


        ''' <summary>True when imported from Excel but no matching product was found in the database.</summary>
        Private _isUnmatched As Boolean
        Public Property IsUnmatched As Boolean
            Get
                Return _isUnmatched
            End Get
            Set(value As Boolean)
                _isUnmatched = value
                OnPropertyChanged(NameOf(IsUnmatched))
            End Set
        End Property

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Overridable Sub OnPropertyChanged(propertyName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
