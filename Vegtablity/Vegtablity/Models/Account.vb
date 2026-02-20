Namespace Models
    Public Class Account
        Public Property AccountID As Integer
        Public Property AccountCode As String
        Public Property AccountName As String
        Public Property ParentAccountID As Integer?
        Public Property ParentAccountName As String     ' من JOIN
        Public Property AccountType As String            ' Assets, Liabilities, Expenses, Revenue
        Public Property AccountLevel As Integer
        Public Property IsTransactional As Boolean       ' هل يقبل قيود مباشرة
    End Class
End Namespace
