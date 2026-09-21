Imports System
Imports Vegtablity.ViewModels

Namespace Models.HR
    Public Class EmployeeLeave
        Inherits BaseViewModel

        Private _leaveID As Integer
        Public Property LeaveID As Integer
            Get
                Return _leaveID
            End Get
            Set(value As Integer)
                SetProperty(_leaveID, value)
            End Set
        End Property

        Private _employeeID As Integer
        Public Property EmployeeID As Integer
            Get
                Return _employeeID
            End Get
            Set(value As Integer)
                SetProperty(_employeeID, value)
            End Set
        End Property

        Private _employeeCode As String
        Public Property EmployeeCode As String
            Get
                Return _employeeCode
            End Get
            Set(value As String)
                SetProperty(_employeeCode, value)
            End Set
        End Property

        Private _employeeName As String
        Public Property EmployeeName As String
            Get
                Return _employeeName
            End Get
            Set(value As String)
                SetProperty(_employeeName, value)
            End Set
        End Property

        Private _department As String
        Public Property Department As String
            Get
                Return _department
            End Get
            Set(value As String)
                SetProperty(_department, value)
            End Set
        End Property

        Private _leaveTypeID As Integer
        Public Property LeaveTypeID As Integer
            Get
                Return _leaveTypeID
            End Get
            Set(value As Integer)
                SetProperty(_leaveTypeID, value)
            End Set
        End Property

        Private _leaveTypeName As String
        Public Property LeaveTypeName As String
            Get
                Return _leaveTypeName
            End Get
            Set(value As String)
                SetProperty(_leaveTypeName, value)
            End Set
        End Property

        Private _startDate As DateTime = DateTime.Today
        Public Property StartDate As DateTime
            Get
                Return _startDate
            End Get
            Set(value As DateTime)
                SetProperty(_startDate, value)
            End Set
        End Property

        Private _endDate As DateTime = DateTime.Today.AddDays(7)
        Public Property EndDate As DateTime
            Get
                Return _endDate
            End Get
            Set(value As DateTime)
                SetProperty(_endDate, value)
            End Set
        End Property

        Private _daysCount As Integer = 7
        Public Property DaysCount As Integer
            Get
                Return _daysCount
            End Get
            Set(value As Integer)
                SetProperty(_daysCount, value)
            End Set
        End Property

        Private _reason As String
        Public Property Reason As String
            Get
                Return _reason
            End Get
            Set(value As String)
                SetProperty(_reason, value)
            End Set
        End Property

        Private _status As String = "Approved" ' Pending, Approved, Rejected, Completed
        Public Property Status As String
            Get
                Return _status
            End Get
            Set(value As String)
                SetProperty(_status, value)
            End Set
        End Property

        Private _expectedReturnDate As DateTime = DateTime.Today.AddDays(8)
        Public Property ExpectedReturnDate As DateTime
            Get
                Return _expectedReturnDate
            End Get
            Set(value As DateTime)
                SetProperty(_expectedReturnDate, value)
            End Set
        End Property

        Private _actualReturnDate As DateTime?
        Public Property ActualReturnDate As DateTime?
            Get
                Return _actualReturnDate
            End Get
            Set(value As DateTime?)
                SetProperty(_actualReturnDate, value)
            End Set
        End Property

        Private _resumptionDate As DateTime?
        Public Property ResumptionDate As DateTime?
            Get
                Return _resumptionDate
            End Get
            Set(value As DateTime?)
                SetProperty(_resumptionDate, value)
            End Set
        End Property

        Private _delayDays As Integer = 0
        Public Property DelayDays As Integer
            Get
                Return _delayDays
            End Get
            Set(value As Integer)
                SetProperty(_delayDays, value)
            End Set
        End Property

        Private _resumptionNotes As String
        Public Property ResumptionNotes As String
            Get
                Return _resumptionNotes
            End Get
            Set(value As String)
                SetProperty(_resumptionNotes, value)
            End Set
        End Property

        Private _approvedBy As String
        Public Property ApprovedBy As String
            Get
                Return _approvedBy
            End Get
            Set(value As String)
                SetProperty(_approvedBy, value)
            End Set
        End Property

        Private _createdAt As DateTime = DateTime.Now
        Public Property CreatedAt As DateTime
            Get
                Return _createdAt
            End Get
            Set(value As DateTime)
                SetProperty(_createdAt, value)
            End Set
        End Property
    End Class
End Namespace
