Imports System.Collections.ObjectModel

Namespace Models
    Public Class DailyOrder
        Inherits ViewModels.BaseViewModel

        Public Property InvID As Integer
        Public Property CustomerName As String
        Public Property Phone As String
        Public Property Address As String
        Public Property DeliveryDate As DateTime
        Public Property DeliveryTime As String
        Public Property Notes As String
        Public Property NetAmount As Decimal
        Public Property PaidAmount As Decimal
        Public Property Remainder As Decimal
        Public Property InvType As String

        Public Property Details As New ObservableCollection(Of InvoiceDetail)()

        Private _isExpanded As Boolean = False
        Public Property IsExpanded As Boolean
            Get
                Return _isExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isExpanded, value)
            End Set
        End Property

        Public ReadOnly Property PaymentStatus As String
            Get
                If Remainder <= 0 Then
                    Return "مسدد"
                Else
                    Return "آجل"
                End If
            End Get
        End Property

        Public ReadOnly Property IsPastDue As Boolean
            Get
                If DeliveryDate.Date < DateTime.Today Then
                    Return True
                ElseIf DeliveryDate.Date > DateTime.Today Then
                    Return False
                Else
                    If String.IsNullOrWhiteSpace(DeliveryTime) Then Return False
                    Try
                        Dim parts = DeliveryTime.Split(":"c)
                        If parts.Length >= 2 Then
                            Dim hr = Integer.Parse(parts(0))
                            Dim mn = Integer.Parse(parts(1))
                            Dim targetTime = DateTime.Today.AddHours(hr).AddMinutes(mn)
                            Return DateTime.Now > targetTime
                        End If
                    Catch
                        ' ignore
                    End Try
                    Return False
                End If
            End Get
        End Property
    End Class
End Namespace
