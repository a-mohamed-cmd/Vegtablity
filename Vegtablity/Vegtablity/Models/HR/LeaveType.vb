Namespace Models.HR
    Public Class LeaveType
        Public Property LeaveTypeID As Integer
        Public Property TypeName As String
        Public Property AnnualDaysAllowance As Integer = 30
        Public Property IsPaid As Boolean = True
        Public Property RequiresApproval As Boolean = True
    End Class
End Namespace
