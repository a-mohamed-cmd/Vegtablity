Imports System
Imports System.ComponentModel

Namespace Models.HR
    Public Class EndOfServiceSettlement
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Protected Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _settlementId As Integer
        Private _employeeId As Integer
        Private _employeeCode As String
        Private _employeeName As String
        Private _department As String
        Private _hireDate As DateTime
        Private _endDate As DateTime = DateTime.Today
        Private _serviceYears As Integer = 0
        Private _serviceMonths As Integer = 0
        Private _serviceDays As Integer = 0
        Private _departureReason As String = "Termination"
        Private _lastBasicSalary As Decimal = 0
        Private _lastAllowances As Decimal = 0
        Private _indemnityAmount As Decimal = 0
        Private _unpaidLeaveBalanceDays As Decimal = 0
        Private _unpaidLeaveCompensation As Decimal = 0
        Private _otherEntitlements As Decimal = 0
        Private _deductionsLoans As Decimal = 0
        Private _netSettlementAmount As Decimal = 0
        Private _status As String = "Approved"
        Private _notes As String
        Private _approvedBy As String
        Private _createdAt As DateTime = DateTime.Now

        Public Property SettlementID As Integer
            Get
                Return _settlementId
            End Get
            Set(value As Integer)
                _settlementId = value
                OnPropertyChanged(NameOf(SettlementID))
            End Set
        End Property

        Public Property EmployeeID As Integer
            Get
                Return _employeeId
            End Get
            Set(value As Integer)
                _employeeId = value
                OnPropertyChanged(NameOf(EmployeeID))
            End Set
        End Property

        Public Property EmployeeCode As String
            Get
                Return _employeeCode
            End Get
            Set(value As String)
                _employeeCode = value
                OnPropertyChanged(NameOf(EmployeeCode))
            End Set
        End Property

        Public Property EmployeeName As String
            Get
                Return _employeeName
            End Get
            Set(value As String)
                _employeeName = value
                OnPropertyChanged(NameOf(EmployeeName))
            End Set
        End Property

        Public Property Department As String
            Get
                Return _department
            End Get
            Set(value As String)
                _department = value
                OnPropertyChanged(NameOf(Department))
            End Set
        End Property

        Public Property HireDate As DateTime
            Get
                Return _hireDate
            End Get
            Set(value As DateTime)
                _hireDate = value
                OnPropertyChanged(NameOf(HireDate))
                Calculate()
            End Set
        End Property

        Public Property EndDate As DateTime
            Get
                Return _endDate
            End Get
            Set(value As DateTime)
                _endDate = value
                OnPropertyChanged(NameOf(EndDate))
                Calculate()
            End Set
        End Property

        Public Property ServiceYears As Integer
            Get
                Return _serviceYears
            End Get
            Set(value As Integer)
                _serviceYears = value
                OnPropertyChanged(NameOf(ServiceYears))
                OnPropertyChanged(NameOf(DurationDescription))
            End Set
        End Property

        Public Property ServiceMonths As Integer
            Get
                Return _serviceMonths
            End Get
            Set(value As Integer)
                _serviceMonths = value
                OnPropertyChanged(NameOf(ServiceMonths))
                OnPropertyChanged(NameOf(DurationDescription))
            End Set
        End Property

        Public Property ServiceDays As Integer
            Get
                Return _serviceDays
            End Get
            Set(value As Integer)
                _serviceDays = value
                OnPropertyChanged(NameOf(ServiceDays))
                OnPropertyChanged(NameOf(DurationDescription))
            End Set
        End Property

        Public Property DepartureReason As String
            Get
                Return _departureReason
            End Get
            Set(value As String)
                _departureReason = value
                OnPropertyChanged(NameOf(DepartureReason))
                Calculate()
            End Set
        End Property

        Public Property LastBasicSalary As Decimal
            Get
                Return _lastBasicSalary
            End Get
            Set(value As Decimal)
                _lastBasicSalary = value
                OnPropertyChanged(NameOf(LastBasicSalary))
                Calculate()
            End Set
        End Property

        Public Property LastAllowances As Decimal
            Get
                Return _lastAllowances
            End Get
            Set(value As Decimal)
                _lastAllowances = value
                OnPropertyChanged(NameOf(LastAllowances))
                Calculate()
            End Set
        End Property

        Public Property IndemnityAmount As Decimal
            Get
                Return _indemnityAmount
            End Get
            Set(value As Decimal)
                _indemnityAmount = value
                OnPropertyChanged(NameOf(IndemnityAmount))
            End Set
        End Property

        Public Property UnpaidLeaveBalanceDays As Decimal
            Get
                Return _unpaidLeaveBalanceDays
            End Get
            Set(value As Decimal)
                _unpaidLeaveBalanceDays = value
                OnPropertyChanged(NameOf(UnpaidLeaveBalanceDays))
                Calculate()
            End Set
        End Property

        Public Property UnpaidLeaveCompensation As Decimal
            Get
                Return _unpaidLeaveCompensation
            End Get
            Set(value As Decimal)
                _unpaidLeaveCompensation = value
                OnPropertyChanged(NameOf(UnpaidLeaveCompensation))
            End Set
        End Property

        Public Property OtherEntitlements As Decimal
            Get
                Return _otherEntitlements
            End Get
            Set(value As Decimal)
                _otherEntitlements = value
                OnPropertyChanged(NameOf(OtherEntitlements))
                Calculate()
            End Set
        End Property

        Public Property DeductionsLoans As Decimal
            Get
                Return _deductionsLoans
            End Get
            Set(value As Decimal)
                _deductionsLoans = value
                OnPropertyChanged(NameOf(DeductionsLoans))
                Calculate()
            End Set
        End Property

        Public Property NetSettlementAmount As Decimal
            Get
                Return _netSettlementAmount
            End Get
            Set(value As Decimal)
                _netSettlementAmount = value
                OnPropertyChanged(NameOf(NetSettlementAmount))
            End Set
        End Property

        Public Property Status As String
            Get
                Return _status
            End Get
            Set(value As String)
                _status = value
                OnPropertyChanged(NameOf(Status))
            End Set
        End Property

        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                _notes = value
                OnPropertyChanged(NameOf(Notes))
            End Set
        End Property

        Public Property ApprovedBy As String
            Get
                Return _approvedBy
            End Get
            Set(value As String)
                _approvedBy = value
                OnPropertyChanged(NameOf(ApprovedBy))
            End Set
        End Property

        Public Property CreatedAt As DateTime
            Get
                Return _createdAt
            End Get
            Set(value As DateTime)
                _createdAt = value
                OnPropertyChanged(NameOf(CreatedAt))
            End Set
        End Property

        Public ReadOnly Property DurationDescription As String
            Get
                Return $"{ServiceYears} سنة، {ServiceMonths} شهر، {ServiceDays} يوم"
            End Get
        End Property

        Public Sub Calculate()
            Dim totalSalary As Decimal = LastBasicSalary + LastAllowances
            Dim totalDays As Double = Math.Max(0, (EndDate - HireDate).TotalDays)
            Dim decYears As Double = totalDays / 365.25

            _serviceYears = CInt(Math.Floor(decYears))
            Dim remDays As Double = totalDays Mod 365.25
            _serviceMonths = CInt(Math.Floor(remDays / 30.4375))
            _serviceDays = CInt(Math.Floor(remDays Mod 30.4375))

            ' Labor law indemnity calculation:
            Dim fullIndemnity As Decimal = 0
            If decYears <= 5 Then
                fullIndemnity = CDec(decYears * (CDbl(totalSalary) * 0.5))
            Else
                fullIndemnity = CDec((5 * (CDbl(totalSalary) * 0.5)) + ((decYears - 5) * CDbl(totalSalary)))
            End If

            ' Resignation factor:
            Dim factor As Decimal = 1.0D
            If DepartureReason = "Resignation" Then
                If decYears < 3 Then
                    factor = 0.0D
                ElseIf decYears < 5 Then
                    factor = CDec(1.0 / 3.0)
                ElseIf decYears < 10 Then
                    factor = CDec(2.0 / 3.0)
                Else
                    factor = 1.0D
                End If
            End If

            IndemnityAmount = Math.Round(fullIndemnity * factor, 3)
            UnpaidLeaveCompensation = Math.Round((totalSalary / 30.0D) * UnpaidLeaveBalanceDays, 3)
            NetSettlementAmount = Math.Max(0, IndemnityAmount + UnpaidLeaveCompensation + OtherEntitlements - DeductionsLoans)

            OnPropertyChanged(NameOf(ServiceYears))
            OnPropertyChanged(NameOf(ServiceMonths))
            OnPropertyChanged(NameOf(ServiceDays))
            OnPropertyChanged(NameOf(DurationDescription))
            OnPropertyChanged(NameOf(IndemnityAmount))
            OnPropertyChanged(NameOf(UnpaidLeaveCompensation))
            OnPropertyChanged(NameOf(NetSettlementAmount))
        End Sub
    End Class
End Namespace
