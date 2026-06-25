Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Runtime.CompilerServices

Namespace Models
    Public Class StockTakeHeader
        Implements INotifyPropertyChanged

        Private _stockTakeID As Integer
        Public Property StockTakeID As Integer
            Get
                Return _stockTakeID
            End Get
            Set(value As Integer)
                _stockTakeID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _stockTakeDate As DateTime = DateTime.Now
        Public Property StockTakeDate As DateTime
            Get
                Return _stockTakeDate
            End Get
            Set(value As DateTime)
                _stockTakeDate = value
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

        Private _userName As String
        Public Property UserName As String
            Get
                Return _userName
            End Get
            Set(value As String)
                _userName = value
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

        Private _warehouseName As String
        Public Property WarehouseName As String
            Get
                Return _warehouseName
            End Get
            Set(value As String)
                _warehouseName = value
                OnPropertyChanged()
            End Set
        End Property

        Private _status As String = "Pending"
        Public Property Status As String
            Get
                Return _status
            End Get
            Set(value As String)
                _status = value
                OnPropertyChanged()
            End Set
        End Property

        Private _totalDifferenceValue As Decimal
        Public Property TotalDifferenceValue As Decimal
            Get
                Return _totalDifferenceValue
            End Get
            Set(value As Decimal)
                _totalDifferenceValue = value
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

        Private _approvedBy As Integer?
        Public Property ApprovedBy As Integer?
            Get
                Return _approvedBy
            End Get
            Set(value As Integer?)
                _approvedBy = value
                OnPropertyChanged()
            End Set
        End Property

        Private _approvedAt As DateTime?
        Public Property ApprovedAt As DateTime?
            Get
                Return _approvedAt
            End Get
            Set(value As DateTime?)
                _approvedAt = value
                OnPropertyChanged()
            End Set
        End Property

        Private _details As New ObservableCollection(Of StockTakeDetails)()
        Public Property Details As ObservableCollection(Of StockTakeDetails)
            Get
                Return _details
            End Get
            Set(value As ObservableCollection(Of StockTakeDetails))
                _details = value
                OnPropertyChanged()
            End Set
        End Property

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class

    Public Class StockTakeDetails
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

        Private _stockTakeID As Integer
        Public Property StockTakeID As Integer
            Get
                Return _stockTakeID
            End Get
            Set(value As Integer)
                _stockTakeID = value
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

        Private _systemQuantity As Decimal
        Public Property SystemQuantity As Decimal
            Get
                Return _systemQuantity
            End Get
            Set(value As Decimal)
                _systemQuantity = value
                OnPropertyChanged()
            End Set
        End Property

        Private _actualQuantity As Decimal
        Public Property ActualQuantity As Decimal
            Get
                Return _actualQuantity
            End Get
            Set(value As Decimal)
                _actualQuantity = value
                OnPropertyChanged()
                UpdateDifference()
            End Set
        End Property

        Private _differenceQuantity As Decimal
        Public Property DifferenceQuantity As Decimal
            Get
                Return _differenceQuantity
            End Get
            Set(value As Decimal)
                _differenceQuantity = value
                OnPropertyChanged()
            End Set
        End Property

        Private _costPrice As Decimal
        Public Property CostPrice As Decimal
            Get
                Return _costPrice
            End Get
            Set(value As Decimal)
                _costPrice = value
                OnPropertyChanged()
                UpdateDifference()
            End Set
        End Property

        Private _differenceValue As Decimal
        Public Property DifferenceValue As Decimal
            Get
                Return _differenceValue
            End Get
            Set(value As Decimal)
                _differenceValue = value
                OnPropertyChanged()
            End Set
        End Property

        Private Sub UpdateDifference()
            DifferenceQuantity = ActualQuantity - SystemQuantity
            DifferenceValue = DifferenceQuantity * CostPrice
        End Sub

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
