Imports System
Imports System.ComponentModel

Namespace Models.HR
    Public Class AttendanceRecord
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _workHours As Decimal = 8.0D
        Private _overtimeHours As Decimal = 0.0D
        Private _overtimeDays As Decimal = 0.0D
        Private _delayMinutes As Integer = 0
        Private _absenceDeductionDays As Decimal = 0.0D
        Private _status As String = "Present"
        Private _notes As String

        Public Property AttendanceID As Integer
        Public Property EmployeeID As Integer
        Public Property EmployeeCode As String
        Public Property EmployeeName As String
        Public Property Department As String
        Public Property JobTitle As String
        Public Property AttendanceDate As DateTime = DateTime.Today
        Public Property CheckIn As TimeSpan?
        Public Property CheckOut As TimeSpan?

        Public Property WorkHours As Decimal
            Get
                Return _workHours
            End Get
            Set(value As Decimal)
                If _workHours <> value Then
                    _workHours = value
                    OnPropertyChanged(NameOf(WorkHours))
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
                End If
            End Set
        End Property

        Public Property DelayMinutes As Integer
            Get
                Return _delayMinutes
            End Get
            Set(value As Integer)
                If _delayMinutes <> value Then
                    _delayMinutes = value
                    OnPropertyChanged(NameOf(DelayMinutes))
                End If
            End Set
        End Property

        Public Property AbsenceDeductionDays As Decimal
            Get
                Return _absenceDeductionDays
            End Get
            Set(value As Decimal)
                If _absenceDeductionDays <> value Then
                    _absenceDeductionDays = value
                    OnPropertyChanged(NameOf(AbsenceDeductionDays))
                End If
            End Set
        End Property

        Public Property Status As String
            Get
                Return _status
            End Get
            Set(value As String)
                If _status <> value Then
                    _status = value
                    OnPropertyChanged(NameOf(Status))
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
    End Class
End Namespace
