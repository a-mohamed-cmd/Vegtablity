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
    
        ''' <summary>الكود + الاسم — يُستخدم في قوائم البحث</summary>
        Public ReadOnly Property DisplayText As String
            Get
                Return $"{AccountCode}  —  {AccountName}"
            End Get
        End Property

        Public Overrides Function ToString() As String
            Return $"{AccountCode} - {AccountName}"
        End Function
End Class
End Namespace
