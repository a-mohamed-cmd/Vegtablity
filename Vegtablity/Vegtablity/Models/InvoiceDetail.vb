Imports System.ComponentModel

Namespace Models
    Public Class InvoiceDetail
        Implements INotifyPropertyChanged

        Private _detID As Integer
        Public Property DetID As Integer
            Get
                Return _detID
            End Get
            Set(value As Integer)
                _detID = value
                OnPropertyChanged(NameOf(DetID))
            End Set
        End Property

        Private _invID As Integer
        Public Property InvID As Integer
            Get
                Return _invID
            End Get
            Set(value As Integer)
                _invID = value
                OnPropertyChanged(NameOf(InvID))
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

        Private _unitPrice As Decimal
        Public Property UnitPrice As Decimal
            Get
                Return _unitPrice
            End Get
            Set(value As Decimal)
                _unitPrice = value
                OnPropertyChanged(NameOf(UnitPrice))
                CalculateTotal()
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
                CalculateTotal()
            End Set
        End Property

        Private _totalPrice As Decimal
        Public Property TotalPrice As Decimal
            Get
                Return _totalPrice
            End Get
            Set(value As Decimal)
                _totalPrice = value
                OnPropertyChanged(NameOf(TotalPrice))
            End Set
        End Property

        Private _costPrice As Decimal
        Public Property CostPrice As Decimal
            Get
                Return _costPrice
            End Get
            Set(value As Decimal)
                _costPrice = value
                OnPropertyChanged(NameOf(CostPrice))
            End Set
        End Property

        ' Read-only properties for UI display (from JOINs)
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

        Private Sub CalculateTotal()
            TotalPrice = UnitPrice * Quantity
        End Sub

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Overridable Sub OnPropertyChanged(propertyName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
