Namespace Models
    Public Class AccountStatementReport
        Public Property OpeningBalance As Decimal
        Public Property Transactions As New List(Of AccountStatementItem)
        
        Public ReadOnly Property TotalDebit As Decimal
            Get
                Return Transactions.Sum(Function(x) x.DebitAmount)
            End Get
        End Property

        Public ReadOnly Property TotalCredit As Decimal
            Get
                Return Transactions.Sum(Function(x) x.CreditAmount)
            End Get
        End Property

        Public ReadOnly Property EndingBalance As Decimal
            Get
                If Transactions.Count > 0 Then
                    Return Transactions.Last().Balance
                Else
                    Return OpeningBalance
                End If
            End Get
        End Property
    End Class

    Public Class AccountStatementItem
        Public Property EntryID As Integer
        Public Property EntryNo As Integer
        Public Property EntryDate As DateTime
        Public Property ReferenceType As String
        Public Property ReferenceID As Integer
        Public Property Description As String
        Public Property DebitAmount As Decimal
        Public Property CreditAmount As Decimal
        Public Property Balance As Decimal
    End Class
End Namespace
