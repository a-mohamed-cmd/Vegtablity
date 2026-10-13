Imports System
Imports System.ComponentModel

Namespace Models.HR
    Public Class PayrollDetail
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Public Shared Property CurrentSettings As PayrollSettings

        Private Function GetCalculationBase() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing AndAlso 
               (String.Equals(s.CalculationBasis, "GrossTotal", StringComparison.OrdinalIgnoreCase) OrElse 
                String.Equals(s.CalculationBasis, "BasicAndAllowances", StringComparison.OrdinalIgnoreCase)) Then
                Return _basicSalary + TotalAllowances
            End If
            Return _basicSalary
        End Function

        Private Function GetStandardMonthlyDays() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing AndAlso s.StandardMonthlyDays > 0 Then
                Return CDec(s.StandardMonthlyDays)
            End If
            Return 30.0D
        End Function

        Private Function GetMonthlyWorkHours() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing Then
                Dim days = If(s.StandardMonthlyDays > 0, CDec(s.StandardMonthlyDays), 30.0D)
                Dim dailyHours = If(s.DailyWorkHours > 0, s.DailyWorkHours, 8.0D)
                Return days * dailyHours
            End If
            Return 240.0D
        End Function

        Private Function GetOvertimeHourMultiplier() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing AndAlso s.OvertimeHourMultiplier > 0 Then
                Return s.OvertimeHourMultiplier
            End If
            Return 1.5D
        End Function

        Private Function GetOvertimeDayMultiplier() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing AndAlso s.OvertimeDayMultiplier > 0 Then
                Return s.OvertimeDayMultiplier
            End If
            Return 1.5D
        End Function

        Private Function GetAbsenceDayMultiplier() As Decimal
            Dim s = CurrentSettings
            If s IsNot Nothing AndAlso s.AbsenceDayMultiplier > 0 Then
                Return s.AbsenceDayMultiplier
            End If
            Return 1.0D
        End Function

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
                    Recalculate()
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
                    If value > 0 Then
                        Dim baseSalary = GetCalculationBase()
                        If baseSalary > 0 Then
                            Dim hourlyWage = baseSalary / GetMonthlyWorkHours()
                            _overtimeAmount = Math.Round(hourlyWage * value * GetOvertimeHourMultiplier(), 3)
                            OnPropertyChanged(NameOf(OvertimeAmount))
                        End If
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
                    If value > 0 Then
                        Dim baseSalary = GetCalculationBase()
                        If baseSalary > 0 Then
                            Dim dailyWage = baseSalary / GetStandardMonthlyDays()
                            _overtimeAmount = Math.Round(dailyWage * value * GetOvertimeDayMultiplier(), 3)
                            OnPropertyChanged(NameOf(OvertimeAmount))
                        End If
                    ElseIf value = 0 Then
                        _overtimeAmount = 0
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
                    If value > 0 Then
                        Dim baseSalary = GetCalculationBase()
                        If baseSalary > 0 Then
                            Dim dailyWage = baseSalary / GetStandardMonthlyDays()
                            _deductionAmount = Math.Round(dailyWage * value * GetAbsenceDayMultiplier(), 3)
                            OnPropertyChanged(NameOf(DeductionAmount))
                        End If
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
            If autoDeriveFromBasic Then
                Dim baseSalary = GetCalculationBase()
                If baseSalary > 0 Then
                    If _overtimeHours > 0 Then
                        Dim hourlyWage = baseSalary / GetMonthlyWorkHours()
                        _overtimeAmount = Math.Round(hourlyWage * _overtimeHours * GetOvertimeHourMultiplier(), 3)
                        OnPropertyChanged(NameOf(OvertimeAmount))
                    End If
                    If _deductionDays > 0 Then
                        Dim dailyWage = baseSalary / GetStandardMonthlyDays()
                        _deductionAmount = Math.Round(dailyWage * _deductionDays * GetAbsenceDayMultiplier(), 3)
                        OnPropertyChanged(NameOf(DeductionAmount))
                    End If
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
