Imports System
Imports System.ComponentModel

Namespace Models.HR
    Public Class PayrollSettings
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _settingID As Integer = 1
        Private _standardMonthlyDays As Integer = 30
        Private _dailyWorkHours As Decimal = 8.0D
        Private _overtimeHourMultiplier As Decimal = 1.5D
        Private _overtimeDayMultiplier As Decimal = 1.5D
        Private _calculationBasis As String = "BasicOnly"
        Private _enableDelayDeduction As Boolean = True
        Private _delayGracePeriodMinutes As Integer = 0
        Private _absenceDayMultiplier As Decimal = 1.0D
        Private _notes As String = ""
        Private _updatedAt As DateTime = DateTime.Now
        Private _updatedBy As String = "System"

        Public Property SettingID As Integer
            Get
                Return _settingID
            End Get
            Set(value As Integer)
                If _settingID <> value Then
                    _settingID = value
                    OnPropertyChanged(NameOf(SettingID))
                End If
            End Set
        End Property

        Public Property StandardMonthlyDays As Integer
            Get
                Return _standardMonthlyDays
            End Get
            Set(value As Integer)
                If _standardMonthlyDays <> value Then
                    _standardMonthlyDays = value
                    OnPropertyChanged(NameOf(StandardMonthlyDays))
                    OnPropertyChanged(NameOf(MonthlyWorkHours))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property DailyWorkHours As Decimal
            Get
                Return _dailyWorkHours
            End Get
            Set(value As Decimal)
                If _dailyWorkHours <> value Then
                    _dailyWorkHours = value
                    OnPropertyChanged(NameOf(DailyWorkHours))
                    OnPropertyChanged(NameOf(MonthlyWorkHours))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public ReadOnly Property MonthlyWorkHours As Decimal
            Get
                Return Math.Round(_standardMonthlyDays * _dailyWorkHours, 2)
            End Get
        End Property

        Public Property OvertimeHourMultiplier As Decimal
            Get
                Return _overtimeHourMultiplier
            End Get
            Set(value As Decimal)
                If _overtimeHourMultiplier <> value Then
                    _overtimeHourMultiplier = value
                    OnPropertyChanged(NameOf(OvertimeHourMultiplier))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property OvertimeDayMultiplier As Decimal
            Get
                Return _overtimeDayMultiplier
            End Get
            Set(value As Decimal)
                If _overtimeDayMultiplier <> value Then
                    _overtimeDayMultiplier = value
                    OnPropertyChanged(NameOf(OvertimeDayMultiplier))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property CalculationBasis As String
            Get
                Return If(String.IsNullOrEmpty(_calculationBasis), "BasicOnly", _calculationBasis)
            End Get
            Set(value As String)
                If _calculationBasis <> value Then
                    _calculationBasis = value
                    OnPropertyChanged(NameOf(CalculationBasis))
                    OnPropertyChanged(NameOf(CalculationBasisDisplay))
                    OnPropertyChanged(NameOf(IsBasisBasicOnly))
                    OnPropertyChanged(NameOf(IsBasisGrossTotal))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property IsBasisBasicOnly As Boolean
            Get
                Return CalculationBasis = "BasicOnly"
            End Get
            Set(value As Boolean)
                If value Then
                    CalculationBasis = "BasicOnly"
                End If
            End Set
        End Property

        Public Property IsBasisGrossTotal As Boolean
            Get
                Return CalculationBasis = "GrossTotal"
            End Get
            Set(value As Boolean)
                If value Then
                    CalculationBasis = "GrossTotal"
                End If
            End Set
        End Property

        Public ReadOnly Property CalculationBasisDisplay As String
            Get
                Return If(CalculationBasis = "GrossTotal", "الراتب الإجمالي (الأساسي + البدلات)", "الراتب الأساسي فقط")
            End Get
        End Property

        Public Property EnableDelayDeduction As Boolean
            Get
                Return _enableDelayDeduction
            End Get
            Set(value As Boolean)
                If _enableDelayDeduction <> value Then
                    _enableDelayDeduction = value
                    OnPropertyChanged(NameOf(EnableDelayDeduction))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property DelayGracePeriodMinutes As Integer
            Get
                Return _delayGracePeriodMinutes
            End Get
            Set(value As Integer)
                If _delayGracePeriodMinutes <> value Then
                    _delayGracePeriodMinutes = value
                    OnPropertyChanged(NameOf(DelayGracePeriodMinutes))
                    OnPropertyChanged(NameOf(SummaryText))
                End If
            End Set
        End Property

        Public Property AbsenceDayMultiplier As Decimal
            Get
                Return _absenceDayMultiplier
            End Get
            Set(value As Decimal)
                If _absenceDayMultiplier <> value Then
                    _absenceDayMultiplier = value
                    OnPropertyChanged(NameOf(AbsenceDayMultiplier))
                    OnPropertyChanged(NameOf(SummaryText))
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

        Public Property UpdatedAt As DateTime
            Get
                Return _updatedAt
            End Get
            Set(value As DateTime)
                If _updatedAt <> value Then
                    _updatedAt = value
                    OnPropertyChanged(NameOf(UpdatedAt))
                End If
            End Set
        End Property

        Public Property UpdatedBy As String
            Get
                Return _updatedBy
            End Get
            Set(value As String)
                If _updatedBy <> value Then
                    _updatedBy = value
                    OnPropertyChanged(NameOf(UpdatedBy))
                End If
            End Set
        End Property

        Public ReadOnly Property SummaryText As String
            Get
                Dim basisText = If(CalculationBasis = "GrossTotal", "الإجمالي (الأساسي+البدلات)", "الأساسي فقط")
                Dim delayText = If(EnableDelayDeduction, $"مفعل (سماح {DelayGracePeriodMinutes} د)", "معطل")
                Return $"أيام العمل: {StandardMonthlyDays} يوم | ساعات اليوم: {DailyWorkHours} س ({MonthlyWorkHours} س/شهر) | وعاء الاحتساب: {basisText} | مضاعف الساعات الإضافية: {OvertimeHourMultiplier}x | مضاعف الأيام الإضافية: {OvertimeDayMultiplier}x | مضاعف الغياب: {AbsenceDayMultiplier}x | خصم التأخير: {delayText}"
            End Get
        End Property

        Public Function Clone() As PayrollSettings
            Return New PayrollSettings With {
                .SettingID = Me.SettingID,
                .StandardMonthlyDays = Me.StandardMonthlyDays,
                .DailyWorkHours = Me.DailyWorkHours,
                .OvertimeHourMultiplier = Me.OvertimeHourMultiplier,
                .OvertimeDayMultiplier = Me.OvertimeDayMultiplier,
                .CalculationBasis = Me.CalculationBasis,
                .EnableDelayDeduction = Me.EnableDelayDeduction,
                .DelayGracePeriodMinutes = Me.DelayGracePeriodMinutes,
                .AbsenceDayMultiplier = Me.AbsenceDayMultiplier,
                .Notes = Me.Notes,
                .UpdatedAt = Me.UpdatedAt,
                .UpdatedBy = Me.UpdatedBy
            }
        End Function
    End Class
End Namespace
