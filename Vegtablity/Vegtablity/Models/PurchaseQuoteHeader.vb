Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports Vegtablity.ViewModels

Namespace Models
    Public Class PurchaseQuoteHeader
        Inherits BaseViewModel

        Private _purchaseQuoteID As Integer
        Private _partnerID As Integer
        Private _partnerName As String
        Private _quoteDate As DateTime = DateTime.Now
        Private _expiryDate As DateTime?
        Private _notes As String
        Private _details As ObservableCollection(Of PurchaseQuoteDetail)

        Public Property PurchaseQuoteID As Integer
            Get
                Return _purchaseQuoteID
            End Get
            Set(value As Integer)
                SetProperty(_purchaseQuoteID, value)
            End Set
        End Property

        Public Property PartnerID As Integer
            Get
                Return _partnerID
            End Get
            Set(value As Integer)
                SetProperty(_partnerID, value)
            End Set
        End Property

        Public Property PartnerName As String
            Get
                Return _partnerName
            End Get
            Set(value As String)
                SetProperty(_partnerName, value)
            End Set
        End Property

        Public Property QuoteDate As DateTime
            Get
                Return _quoteDate
            End Get
            Set(value As DateTime)
                SetProperty(_quoteDate, value)
            End Set
        End Property

        Public Property ExpiryDate As DateTime?
            Get
                Return _expiryDate
            End Get
            Set(value As DateTime?)
                SetProperty(_expiryDate, value)
            End Set
        End Property

        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                SetProperty(_notes, value)
            End Set
        End Property

        Public Property Details As ObservableCollection(Of PurchaseQuoteDetail)
            Get
                Return _details
            End Get
            Set(value As ObservableCollection(Of PurchaseQuoteDetail))
                SetProperty(_details, value)
            End Set
        End Property

        Public Sub New()
            Details = New ObservableCollection(Of PurchaseQuoteDetail)()
        End Sub
    End Class
End Namespace
