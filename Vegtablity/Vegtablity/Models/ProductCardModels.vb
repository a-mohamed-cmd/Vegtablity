Imports System.ComponentModel

Namespace Models

''' <summary>
''' يمثل ملخص الرصيد والتكلفة وحركة الصنف
''' </summary>
Public Class ProductCardSummary
    Implements INotifyPropertyChanged

    Private _balance As Decimal
    Public Property Balance As Decimal
        Get
            Return _balance
        End Get
        Set(value As Decimal)
            _balance = value
            OnPropertyChanged(NameOf(Balance))
        End Set
    End Property

    Private _avgCost As Decimal
    Public Property AvgCost As Decimal
        Get
            Return _avgCost
        End Get
        Set(value As Decimal)
            _avgCost = value
            OnPropertyChanged(NameOf(AvgCost))
        End Set
    End Property

    Private _totalInQty As Decimal
    Public Property TotalInQty As Decimal
        Get
            Return _totalInQty
        End Get
        Set(value As Decimal)
            _totalInQty = value
            OnPropertyChanged(NameOf(TotalInQty))
        End Set
    End Property

    Private _totalInValue As Decimal
    Public Property TotalInValue As Decimal
        Get
            Return _totalInValue
        End Get
        Set(value As Decimal)
            _totalInValue = value
            OnPropertyChanged(NameOf(TotalInValue))
        End Set
    End Property

    Private _totalOutQty As Decimal
    Public Property TotalOutQty As Decimal
        Get
            Return _totalOutQty
        End Get
        Set(value As Decimal)
            _totalOutQty = value
            OnPropertyChanged(NameOf(TotalOutQty))
        End Set
    End Property

    Private _totalOutValue As Decimal
    Public Property TotalOutValue As Decimal
        Get
            Return _totalOutValue
        End Get
        Set(value As Decimal)
            _totalOutValue = value
            OnPropertyChanged(NameOf(TotalOutValue))
        End Set
    End Property

    Private _lastPurchasePrice As Decimal
    Public Property LastPurchasePrice As Decimal
        Get
            Return _lastPurchasePrice
        End Get
        Set(value As Decimal)
            _lastPurchasePrice = value
            OnPropertyChanged(NameOf(LastPurchasePrice))
        End Set
    End Property

    Private _profitRate As Decimal
    Public Property ProfitRate As Decimal
        Get
            Return _profitRate
        End Get
        Set(value As Decimal)
            _profitRate = value
            OnPropertyChanged(NameOf(ProfitRate))
        End Set
    End Property

    Private _alertQty As Decimal
    Public Property AlertQty As Decimal
        Get
            Return _alertQty
        End Get
        Set(value As Decimal)
            _alertQty = value
            OnPropertyChanged(NameOf(AlertQty))
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

    Private _salePrice As Decimal
    Public Property SalePrice As Decimal
        Get
            Return _salePrice
        End Get
        Set(value As Decimal)
            _salePrice = value
            OnPropertyChanged(NameOf(SalePrice))
        End Set
    End Property

    Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
    Protected Overridable Sub OnPropertyChanged(propertyName As String)
        RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
    End Sub
End Class

''' <summary>
''' يمثل سطر حركة (فاتورة) للصنف المحدد
''' </summary>
Public Class ProductMovement
    Public Property InvID As Integer
    Public Property ReferenceNo As String
    Public Property InvDate As DateTime
    Public Property InvType As String        ' 'Purchase' | 'Sales' (NVARCHAR in DB)
    Public Property InvTypeName As String    ' Arabic label from SQL
    Public Property MovementDirection As String  ' 'IN' | 'OUT' from SQL
    Public Property Quantity As Decimal
    Public Property UnitPrice As Decimal
    Public Property TotalPrice As Decimal
    Public Property PartnerName As String
    Public Property TotalCount As Integer    ' COUNT(*) OVER() - إجمالي الصفوف في الفلتر الحالي
End Class

''' <summary>
''' يمثل نقطة بيانات واحدة على الرسم البياني
''' </summary>
Public Class ChartDataPoint
    Public Property MovementDate As DateTime
    Public Property DailyInQty As Decimal
    Public Property DailyOutQty As Decimal
    Public Property NetDayMovement As Decimal
End Class

''' <summary>
''' يمثل رصيد الصنف في مستودع معين
''' </summary>
Public Class WarehouseStock
    Implements INotifyPropertyChanged

    Private _warehouseName As String
    Public Property WarehouseName As String
        Get
            Return _warehouseName
        End Get
        Set(value As String)
            _warehouseName = value
            OnPropertyChanged(NameOf(WarehouseName))
        End Set
    End Property

    Private _currentQty As Decimal
    Public Property CurrentQty As Decimal
        Get
            Return _currentQty
        End Get
        Set(value As Decimal)
            _currentQty = value
            OnPropertyChanged(NameOf(CurrentQty))
        End Set
    End Property

    Private _alertQty As Decimal
    Public Property AlertQty As Decimal
        Get
            Return _alertQty
        End Get
        Set(value As Decimal)
            _alertQty = value
            OnPropertyChanged(NameOf(AlertQty))
        End Set
    End Property

    Private _isLowStock As Boolean
    Public Property IsLowStock As Boolean
        Get
            Return _isLowStock
        End Get
        Set(value As Boolean)
            _isLowStock = value
            OnPropertyChanged(NameOf(IsLowStock))
        End Set
    End Property

    Private _incomingQty As Decimal
    Public Property IncomingQty As Decimal
        Get
            Return _incomingQty
        End Get
        Set(value As Decimal)
            _incomingQty = value
            OnPropertyChanged(NameOf(IncomingQty))
        End Set
    End Property

    Private _outgoingQty As Decimal
    Public Property OutgoingQty As Decimal
        Get
            Return _outgoingQty
        End Get
        Set(value As Decimal)
            _outgoingQty = value
            OnPropertyChanged(NameOf(OutgoingQty))
        End Set
    End Property

    Private _wastageQty As Decimal
    Public Property WastageQty As Decimal
        Get
            Return _wastageQty
        End Get
        Set(value As Decimal)
            _wastageQty = value
            OnPropertyChanged(NameOf(WastageQty))
        End Set
    End Property

    Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
    Protected Overridable Sub OnPropertyChanged(propertyName As String)
        RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
    End Sub
End Class

End Namespace
