Imports System

Namespace Models.HR
    Public Class EmployeeLeave
        Public Property LeaveID As Integer
        Public Property EmployeeID As Integer
        Public Property EmployeeCode As String
        Public Property EmployeeName As String
        Public Property Department As String
        Public Property LeaveTypeID As Integer
        Public Property LeaveTypeName As String
        Public Property StartDate As DateTime = DateTime.Today
        Public Property EndDate As DateTime = DateTime.Today.AddDays(7)
        Public Property DaysCount As Integer = 7
        Public Property Reason As String
        Public Property Status As String = "Approved" ' Pending, Approved, Rejected, Completed
        Public Property ExpectedReturnDate As DateTime = DateTime.Today.AddDays(8)
        Public Property ActualReturnDate As DateTime?
        Public Property ResumptionDate As DateTime?
        Public Property DelayDays As Integer = 0
        Public Property ResumptionNotes As String
        Public Property ApprovedBy As String
        Public Property CreatedAt As DateTime = DateTime.Now
    End Class
End Namespace
