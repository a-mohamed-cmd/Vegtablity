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

    Public Class TrialBalanceItem
        Public Property AccountID As Integer
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property AccountType As String
        
        ' Net Balances
        Public Property OpeningBalance As Decimal
        Public Property EndingBalance As Decimal

        ' Movements
        Public Property PeriodDebit As Decimal
        Public Property PeriodCredit As Decimal
        
        ' Keep for Detailed view compatibility
        Public Property OpeningDebit As Decimal
        Public Property OpeningCredit As Decimal
        Public Property EndingDebit As Decimal
        Public Property EndingCredit As Decimal
    End Class

    Public Class TrialBalanceReport
        Public Property StartDate As DateTime
        Public Property EndDate As DateTime
        Public Property Items As New List(Of TrialBalanceItem)

        Public ReadOnly Property TotalOpeningBalance As Decimal
            Get
                Return Items.Sum(Function(i) i.OpeningBalance)
            End Get
        End Property

        Public ReadOnly Property TotalEndingBalance As Decimal
            Get
                Return Items.Sum(Function(i) i.EndingBalance)
            End Get
        End Property
        
        Public ReadOnly Property TotalOpeningDebit As Decimal
            Get
                Return Items.Sum(Function(i) i.OpeningDebit)
            End Get
        End Property

        Public ReadOnly Property TotalOpeningCredit As Decimal
            Get
                Return Items.Sum(Function(i) i.OpeningCredit)
            End Get
        End Property

        Public ReadOnly Property TotalPeriodDebit As Decimal
            Get
                Return Items.Sum(Function(i) i.PeriodDebit)
            End Get
        End Property

        Public ReadOnly Property TotalPeriodCredit As Decimal
            Get
                Return Items.Sum(Function(i) i.PeriodCredit)
            End Get
        End Property

        Public ReadOnly Property TotalEndingDebit As Decimal
            Get
                Return Items.Sum(Function(i) i.EndingDebit)
            End Get
        End Property

        Public ReadOnly Property TotalEndingCredit As Decimal
            Get
                Return Items.Sum(Function(i) i.EndingCredit)
            End Get
        End Property
    End Class
    Public Class FinancialReportItem
        Public Property AccountID As Integer
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property AccountType As String
        Public Property Balance As Decimal
    End Class

    Public Class FinancialReport
        Public Property Title As String
        Public Property StartDate As DateTime?
        Public Property EndDate As DateTime
        Public Property Items As New List(Of FinancialReportItem)

        Public ReadOnly Property TotalBalance As Decimal
            Get
                ' For P&L, this represents Net Profit/Loss if Rev and Exp are passed
                ' For Balance Sheet, this should be 0 if balanced
                Return Items.Sum(Function(i) i.Balance)
            End Get
        End Property
    End Class
End Namespace
