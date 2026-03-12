Imports System.Collections.ObjectModel
Imports System.ComponentModel

Namespace Models
    Public Class QuoteHeader
        Implements INotifyPropertyChanged

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

        Private _partnerID As Integer
        Public Property PartnerID As Integer
            Get
                Return _partnerID
            End Get
            Set(value As Integer)
                _partnerID = value
                OnPropertyChanged(NameOf(PartnerID))
            End Set
        End Property

        Private _quoteDate As DateTime = DateTime.Now
        Public Property QuoteDate As DateTime
            Get
                Return _quoteDate
            End Get
            Set(value As DateTime)
                _quoteDate = value
                OnPropertyChanged(NameOf(QuoteDate))
            End Set
        End Property

        Private _expiryDate As DateTime?
        Public Property ExpiryDate As DateTime?
            Get
                Return _expiryDate
            End Get
            Set(value As DateTime?)
                _expiryDate = value
                OnPropertyChanged(NameOf(ExpiryDate))
            End Set
        End Property

        Private _isActive As Boolean = True
        Public Property IsActive As Boolean
            Get
                Return _isActive
            End Get
            Set(value As Boolean)
                _isActive = value
                OnPropertyChanged(NameOf(IsActive))
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

        ' Read-only properties for UI
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

        Private _details As ObservableCollection(Of QuoteDetail)
        Public Property Details As ObservableCollection(Of QuoteDetail)
            Get
                Return _details
            End Get
            Set(value As ObservableCollection(Of QuoteDetail))
                _details = value
                OnPropertyChanged(NameOf(Details))
            End Set
        End Property

        Public Sub New()
            Details = New ObservableCollection(Of QuoteDetail)()
        End Sub

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged
        Protected Overridable Sub OnPropertyChanged(propertyName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub
    End Class
End Namespace
