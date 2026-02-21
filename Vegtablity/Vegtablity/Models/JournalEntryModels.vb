Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Runtime.CompilerServices

Namespace Models
    Public Class JournalHeader
        Public Property JID As Integer
        Public Property JournalNo As Integer
        Public Property JDate As DateTime = DateTime.Now
        Public Property Description As String
        Public Property UserID As Integer?
        Public Property IsPosted As Boolean
        Public Property TotalAmount As Decimal
        Public Property ReferenceType As String = "Manual"
        Public Property ReferenceID As Integer?

        ' UI Support
        Public Property UserName As String
        Public Property Details As New ObservableCollection(Of JournalDetail)
    End Class

    Public Class JournalDetail
        Implements INotifyPropertyChanged

        Public Property JDID As Integer
        Public Property JID As Integer
        Private _accountID As Integer
        Public Property AccountID As Integer
            Get
                Return _accountID
            End Get
            Set(value As Integer)
                _accountID = value
                OnPropertyChanged()
            End Set
        End Property
        
        Private _debit As Decimal
        Public Property Debit As Decimal
            Get
                Return _debit
            End Get
            Set(value As Decimal)
                _debit = value
                ' mutually exclusive logic
                If _debit > 0 Then _credit = 0
                OnPropertyChanged()
                OnPropertyChanged(NameOf(Credit))
            End Set
        End Property

        Private _credit As Decimal
        Public Property Credit As Decimal
            Get
                Return _credit
            End Get
            Set(value As Decimal)
                _credit = value
                ' mutually exclusive logic
                If _credit > 0 Then _debit = 0
                OnPropertyChanged()
                OnPropertyChanged(NameOf(Debit))
            End Set
        End Property

        Public Property Notes As String

        Private _accountName As String
        Public Property AccountName As String
            Get
                Return _accountName
            End Get
            Set(value As String)
                _accountName = value
                OnPropertyChanged()
            End Set
        End Property

        Private _accountCode As String
        Public Property AccountCode As String
            Get
                Return _accountCode
            End Get
            Set(value As String)
                _accountCode = value
                OnPropertyChanged()
            End Set
        End Property

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
