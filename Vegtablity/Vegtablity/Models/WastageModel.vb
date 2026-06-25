Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Runtime.CompilerServices

Namespace Models
    Public Class WastageHeader
        Implements INotifyPropertyChanged

        Private _wastageID As Integer
        Public Property WastageID As Integer
            Get
                Return _wastageID
            End Get
            Set(value As Integer)
                _wastageID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _warehouseID As Integer = 1
        Public Property WarehouseID As Integer
            Get
                Return _warehouseID
            End Get
            Set(value As Integer)
                _warehouseID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _wastageDate As DateTime = DateTime.Now
        Public Property WastageDate As DateTime
            Get
                Return _wastageDate
            End Get
            Set(value As DateTime)
                _wastageDate = value
                OnPropertyChanged()
            End Set
        End Property

        Private _userID As Integer
        Public Property UserID As Integer
            Get
                Return _userID
            End Get
            Set(value As Integer)
                _userID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _shiftID As Integer?
        Public Property ShiftID As Integer?
            Get
                Return _shiftID
            End Get
            Set(value As Integer?)
                _shiftID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _totalValue As Decimal
        Public Property TotalValue As Decimal
            Get
                Return _totalValue
            End Get
            Set(value As Decimal)
                _totalValue = value
                OnPropertyChanged()
            End Set
        End Property

        Private _notes As String
        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                _notes = value
                OnPropertyChanged()
            End Set
        End Property

        Private _isPosted As Boolean
        Public Property IsPosted As Boolean
            Get
                Return _isPosted
            End Get
            Set(value As Boolean)
                _isPosted = value
                OnPropertyChanged()
            End Set
        End Property

        Private _createdAt As DateTime
        Public Property CreatedAt As DateTime
            Get
                Return _createdAt
            End Get
            Set(value As DateTime)
                _createdAt = value
                OnPropertyChanged()
            End Set
        End Property

        ' UI Fields (display only, not persisted)
        Public Property UserName As String
        Public Property WarehouseName As String

        Private _details As New ObservableCollection(Of WastageDetails)()
        Public Property Details As ObservableCollection(Of WastageDetails)
            Get
                Return _details
            End Get
            Set(value As ObservableCollection(Of WastageDetails))
                _details = value
                OnPropertyChanged()
            End Set
        End Property


        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class

    Public Class WastageDetails
        Implements INotifyPropertyChanged

        Private _detailID As Integer
        Public Property DetailID As Integer
            Get
                Return _detailID
            End Get
            Set(value As Integer)
                _detailID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _productCode As String
        Public Property ProductCode As String
            Get
                Return _productCode
            End Get
            Set(value As String)
                _productCode = value
                OnPropertyChanged()
            End Set
        End Property

        Private _wastageID As Integer
        Public Property WastageID As Integer
            Get
                Return _wastageID
            End Get
            Set(value As Integer)
                _wastageID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _productID As Integer
        Public Property ProductID As Integer
            Get
                Return _productID
            End Get
            Set(value As Integer)
                _productID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _productName As String
        Public Property ProductName As String
            Get
                Return _productName
            End Get
            Set(value As String)
                _productName = value
                OnPropertyChanged()
            End Set
        End Property

        Private _quantity As Decimal
        Public Property Quantity As Decimal
            Get
                Return _quantity
            End Get
            Set(value As Decimal)
                _quantity = value
                OnPropertyChanged()
                UpdateTotalCost()
                OnPropertyChanged("BalanceAfter")
            End Set
        End Property

        Private _availableQuantity As Decimal
        Public Property AvailableQuantity As Decimal
            Get
                Return _availableQuantity
            End Get
            Set(value As Decimal)
                _availableQuantity = value
                OnPropertyChanged()
                OnPropertyChanged("BalanceAfter")
            End Set
        End Property

        Public ReadOnly Property BalanceAfter As Decimal
            Get
                Return AvailableQuantity - Quantity
            End Get
        End Property

        Private _costPrice As Decimal
        Public Property CostPrice As Decimal
            Get
                Return _costPrice
            End Get
            Set(value As Decimal)
                _costPrice = value
                OnPropertyChanged()
                UpdateTotalCost()
            End Set
        End Property

        Private _totalCost As Decimal
        Public Property TotalCost As Decimal
            Get
                Return _totalCost
            End Get
            Set(value As Decimal)
                _totalCost = value
                OnPropertyChanged()
            End Set
        End Property

        Private Sub UpdateTotalCost()
            TotalCost = Quantity * CostPrice
        End Sub

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
