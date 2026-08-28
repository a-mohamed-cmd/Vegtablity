Imports System
Imports System.ComponentModel

Namespace Models.HR
    Public Class PayrollDetail
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _basicSalary As Decimal = 0
        Private _housingAllowance As Decimal = 0
        Private _transportAllowance As Decimal = 0
        Private _otherAllowances As Decimal = 0
        Private _workingDays As Integer = 30
        Private _absentDays As Integer = 0
        Private _overtimeHours As Decimal = 0
        Private _overtimeAmount As Decimal = 0
        Private _overtimeDays As Decimal = 0
        Private _deductionDays As Decimal = 0
        Private _deductionAmount As Decimal = 0
        Private _delayDeductions As Decimal = 0
        Private _advancesDeductions As Decimal = 0
        Private _netSalary As Decimal = 0
        Private _paymentStatus As String = "Unpaid"
        Private _notes As String

        Public Property PayrollDetailID As Integer
        Public Property BatchID As Integer
        Public Property EmployeeID As Integer
        Public Property EmployeeCode As String
        Public Property EmployeeName As String
        Public Property Department As String
        Public Property JobTitle As String

        Public Property BasicSalary As Decimal
            Get
                Return _basicSalary
            End Get
            Set(value As Decimal)
                If _basicSalary <> value Then
                    _basicSalary = value
                    OnPropertyChanged(NameOf(BasicSalary))
                    RecalculateSmart(autoDeriveFromBasic:=True)
                End If
            End Set
        End Property

        Public Property HousingAllowance As Decimal
            Get
                Return _housingAllowance
            End Get
            Set(value As Decimal)
                If _housingAllowance <> value Then
                    _housingAllowance = value
                    OnPropertyChanged(NameOf(HousingAllowance))
                    OnPropertyChanged(NameOf(TotalAllowances))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property TransportAllowance As Decimal
            Get
                Return _transportAllowance
            End Get
            Set(value As Decimal)
                If _transportAllowance <> value Then
                    _transportAllowance = value
                    OnPropertyChanged(NameOf(TransportAllowance))
                    OnPropertyChanged(NameOf(TotalAllowances))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property OtherAllowances As Decimal
            Get
                Return _otherAllowances
            End Get
            Set(value As Decimal)
                If _otherAllowances <> value Then
                    _otherAllowances = value
                    OnPropertyChanged(NameOf(OtherAllowances))
                    OnPropertyChanged(NameOf(TotalAllowances))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property WorkingDays As Integer
            Get
                Return _workingDays
            End Get
            Set(value As Integer)
                If _workingDays <> value Then
                    _workingDays = value
                    OnPropertyChanged(NameOf(WorkingDays))
                End If
            End Set
        End Property

        Public Property AbsentDays As Integer
            Get
                Return _absentDays
            End Get
            Set(value As Integer)
                If _absentDays <> value Then
                    _absentDays = value
                    OnPropertyChanged(NameOf(AbsentDays))
                End If
            End Set
        End Property

        Public Property OvertimeHours As Decimal
            Get
                Return _overtimeHours
            End Get
            Set(value As Decimal)
                If _overtimeHours <> value Then
                    _overtimeHours = value
                    OnPropertyChanged(NameOf(OvertimeHours))
                    ' Smart calculate OvertimeAmount: (BasicSalary / 30 / 8) * OvertimeHours * 1.5
                    If _basicSalary > 0 AndAlso value > 0 Then
                        Dim hourlyWage = _basicSalary / 240.0D
                        _overtimeAmount = Math.Round(hourlyWage * value * 1.5D, 3)
                        OnPropertyChanged(NameOf(OvertimeAmount))
                    ElseIf value = 0 Then
                        _overtimeAmount = 0
                        OnPropertyChanged(NameOf(OvertimeAmount))
                    End If
                    Recalculate()
                End If
            End Set
        End Property

        Public Property OvertimeAmount As Decimal
            Get
                Return _overtimeAmount
            End Get
            Set(value As Decimal)
                If _overtimeAmount <> value Then
                    _overtimeAmount = value
                    OnPropertyChanged(NameOf(OvertimeAmount))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property OvertimeDays As Decimal
            Get
                Return _overtimeDays
            End Get
            Set(value As Decimal)
                If _overtimeDays <> value Then
                    _overtimeDays = value
                    OnPropertyChanged(NameOf(OvertimeDays))
                    If _basicSalary > 0 AndAlso value > 0 Then
                        Dim dailyWage = _basicSalary / 30.0D
                        _overtimeAmount = Math.Round(dailyWage * value * 1.5D, 3)
                        OnPropertyChanged(NameOf(OvertimeAmount))
                    End If
                    Recalculate()
                End If
            End Set
        End Property

        Public Property DeductionDays As Decimal
            Get
                Return _deductionDays
            End Get
            Set(value As Decimal)
                If _deductionDays <> value Then
                    _deductionDays = value
                    OnPropertyChanged(NameOf(DeductionDays))
                    ' Smart calculate DeductionAmount: (BasicSalary / 30) * DeductionDays
                    If _basicSalary > 0 AndAlso value > 0 Then
                        Dim dailyWage = _basicSalary / 30.0D
                        _deductionAmount = Math.Round(dailyWage * value, 3)
                        OnPropertyChanged(NameOf(DeductionAmount))
                    ElseIf value = 0 Then
                        _deductionAmount = 0
                        OnPropertyChanged(NameOf(DeductionAmount))
                    End If
                    Recalculate()
                End If
            End Set
        End Property

        Public Property DeductionAmount As Decimal
            Get
                Return _deductionAmount
            End Get
            Set(value As Decimal)
                If _deductionAmount <> value Then
                    _deductionAmount = value
                    OnPropertyChanged(NameOf(DeductionAmount))
                    OnPropertyChanged(NameOf(TotalDeductions))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property DelayDeductions As Decimal
            Get
                Return _delayDeductions
            End Get
            Set(value As Decimal)
                If _delayDeductions <> value Then
                    _delayDeductions = value
                    OnPropertyChanged(NameOf(DelayDeductions))
                    OnPropertyChanged(NameOf(TotalDeductions))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property AdvancesDeductions As Decimal
            Get
                Return _advancesDeductions
            End Get
            Set(value As Decimal)
                If _advancesDeductions <> value Then
                    _advancesDeductions = value
                    OnPropertyChanged(NameOf(AdvancesDeductions))
                    OnPropertyChanged(NameOf(TotalDeductions))
                    Recalculate()
                End If
            End Set
        End Property

        Public Property NetSalary As Decimal
            Get
                Return _netSalary
            End Get
            Set(value As Decimal)
                If _netSalary <> value Then
                    _netSalary = value
                    OnPropertyChanged(NameOf(NetSalary))
                End If
            End Set
        End Property

        Public Property PaymentStatus As String
            Get
                Return _paymentStatus
            End Get
            Set(value As String)
                If _paymentStatus <> value Then
                    _paymentStatus = value
                    OnPropertyChanged(NameOf(PaymentStatus))
                End If
            End Set
        End Property

        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                If _notes <> value Then
                    _notes = value
                    OnPropertyChanged(NameOf(Notes))
                End If
            End Set
        End Property

        Public ReadOnly Property TotalAllowances As Decimal
            Get
                Return _housingAllowance + _transportAllowance + _otherAllowances
            End Get
        End Property

        Public ReadOnly Property TotalDeductions As Decimal
            Get
                Return _deductionAmount + _delayDeductions + _advancesDeductions
            End Get
        End Property

        Public Sub RecalculateSmart(Optional autoDeriveFromBasic As Boolean = False)
            If autoDeriveFromBasic AndAlso _basicSalary > 0 Then
                If _overtimeHours > 0 Then
                    Dim hourlyWage = _basicSalary / 240.0D
                    _overtimeAmount = Math.Round(hourlyWage * _overtimeHours * 1.5D, 3)
                    OnPropertyChanged(NameOf(OvertimeAmount))
                End If
                If _deductionDays > 0 Then
                    Dim dailyWage = _basicSalary / 30.0D
                    _deductionAmount = Math.Round(dailyWage * _deductionDays, 3)
                    OnPropertyChanged(NameOf(DeductionAmount))
                End If
            End If

            Recalculate()
        End Sub

        Public Sub Recalculate()
            Dim net = (_basicSalary + TotalAllowances + _overtimeAmount) - TotalDeductions
            NetSalary = Math.Round(net, 3)
            OnPropertyChanged(NameOf(TotalAllowances))
            OnPropertyChanged(NameOf(TotalDeductions))
        End Sub
    End Class
End Namespace
