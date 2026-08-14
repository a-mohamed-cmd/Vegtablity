Imports System.Collections.ObjectModel
Imports System.ComponentModel

Namespace Models
    Public Class InvoiceHeader
        Implements INotifyPropertyChanged

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

        Private _invType As String
        Public Property InvType As String
            Get
                Return _invType
            End Get
            Set(value As String)
                _invType = value
                OnPropertyChanged(NameOf(InvType))
            End Set
        End Property

        Private _invDate As DateTime = DateTime.Now
        Public Property InvDate As DateTime
            Get
                Return _invDate
            End Get
            Set(value As DateTime)
                _invDate = value
                OnPropertyChanged(NameOf(InvDate))
            End Set
        End Property

        Private _partnerID As Integer?
        Public Property PartnerID As Integer?
            Get
                Return _partnerID
            End Get
            Set(value As Integer?)
                _partnerID = value
                OnPropertyChanged(NameOf(PartnerID))
            End Set
        End Property

        Private _warehouseID As Integer?
        Public Property WarehouseID As Integer?
            Get
                Return _warehouseID
            End Get
            Set(value As Integer?)
                _warehouseID = value
                OnPropertyChanged(NameOf(WarehouseID))
            End Set
        End Property

        Private _totalAmount As Decimal
        Public Property TotalAmount As Decimal
            Get
                Return _totalAmount
            End Get
            Set(value As Decimal)
                _totalAmount = value
                OnPropertyChanged(NameOf(TotalAmount))
                CalculateNetAmount()
            End Set
        End Property

        Private _discount As Decimal
        Public Property Discount As Decimal
            Get
                Return _discount
            End Get
            Set(value As Decimal)
                _discount = value
                OnPropertyChanged(NameOf(Discount))
                CalculateNetAmount()
            End Set
        End Property

        Private _netAmount As Decimal
        Public Property NetAmount As Decimal
            Get
                Return _netAmount
            End Get
            Set(value As Decimal)
                _netAmount = value
                OnPropertyChanged(NameOf(NetAmount))
                CalculateRemainder()
            End Set
        End Property

        Private _paidAmount As Decimal
        Public Property PaidAmount As Decimal
            Get
                Return _paidAmount
            End Get
            Set(value As Decimal)
                _paidAmount = value
                OnPropertyChanged(NameOf(PaidAmount))
                CalculateRemainder()
            End Set
        End Property

        Private _remainder As Decimal
        Public Property Remainder As Decimal
            Get
                Return _remainder
            End Get
            Set(value As Decimal)
                _remainder = value
                OnPropertyChanged(NameOf(Remainder))
            End Set
        End Property

        Private _userID As Integer?
        Public Property UserID As Integer?
            Get
                Return _userID
            End Get
            Set(value As Integer?)
                _userID = value
                OnPropertyChanged(NameOf(UserID))
            End Set
        End Property

        Private _notes As String
        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                _notes = value
                OnPropertyChanged(NameOf(Notes))
            End Set
        End Property

        Private _accountCode As String
        Public Property AccountCode As String
            Get
                Return _accountCode
            End Get
            Set(value As String)
                _accountCode = value
                OnPropertyChanged(NameOf(AccountCode))
            End Set
        End Property

        Private _paymentAccountID As Integer?
        Public Property PaymentAccountID As Integer?  ' حساب طريقة الدفع (11xx)
            Get
                Return _paymentAccountID
            End Get
            Set(value As Integer?)
                _paymentAccountID = value
                OnPropertyChanged(NameOf(PaymentAccountID))
            End Set
        End Property

        Private _shiftID As Integer?
        Public Property ShiftID As Integer?
            Get
                Return _shiftID
            End Get
            Set(value As Integer?)
                _shiftID = value
                OnPropertyChanged(NameOf(ShiftID))
            End Set
        End Property

        Private _referenceNo As String
        Public Property ReferenceNo As String
            Get
                Return _referenceNo
            End Get
            Set(value As String)
                _referenceNo = value
                OnPropertyChanged(NameOf(ReferenceNo))
            End Set
        End Property

        Private _createdAt As DateTime
        Public Property CreatedAt As DateTime
            Get
                Return _createdAt
            End Get
            Set(value As DateTime)
                _createdAt = value
                OnPropertyChanged(NameOf(CreatedAt))
            End Set
        End Property

        Private _isPosted As Boolean
        Public Property IsPosted As Boolean
            Get
                Return _isPosted
            End Get
            Set(value As Boolean)
                _isPosted = value
                OnPropertyChanged(NameOf(IsPosted))
            End Set
        End Property

        ' Read-only properties for UI display (from JOINs)
        Private _partnerName As String
        Public Property PartnerName As String
            Get
                Return _partnerName
            End Get
            Set(value As String)
                _partnerName = value
                OnPropertyChanged(NameOf(PartnerName))
            End Set
        End Property

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

        Private _userName As String
        Public Property UserName As String
            Get
                Return _userName
            End Get
            Set(value As String)
                _userName = value
                OnPropertyChanged(NameOf(UserName))
            End Set
        End Property

        ' Master-Detail Relationship
        Private _details As ObservableCollection(Of InvoiceDetail)
        Public Property Details As ObservableCollection(Of InvoiceDetail)
            Get
                Return _details
            End Get
            Set(value As ObservableCollection(Of InvoiceDetail))
                _details = value
                OnPropertyChanged(NameOf(Details))
            End Set
        End Property

        Public Sub New()
            Details = New ObservableCollection(Of InvoiceDetail)()
        End Sub

        Private Sub CalculateNetAmount()
            NetAmount = TotalAmount - Discount
        End Sub

        Private Sub CalculateRemainder()
            Remainder = NetAmount - PaidAmount
        End Sub

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Overridable Sub OnPropertyChanged(propertyName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
