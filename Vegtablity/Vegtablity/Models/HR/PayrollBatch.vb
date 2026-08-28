Imports System
Imports System.Collections.ObjectModel
Imports System.ComponentModel

Namespace Models.HR
    Public Class PayrollBatch
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _totalBasic As Decimal = 0
        Private _totalAllowances As Decimal = 0
        Private _totalOvertime As Decimal = 0
        Private _totalDeductions As Decimal = 0
        Private _totalNetSalary As Decimal = 0
        Private _status As String = "Draft"

        Public Property BatchID As Integer
        Public Property Month As Integer
        Public Property Year As Integer
        Public Property BatchDate As DateTime = DateTime.Today

        Public Property TotalBasic As Decimal
            Get
                Return _totalBasic
            End Get
            Set(value As Decimal)
                If _totalBasic <> value Then
                    _totalBasic = value
                    OnPropertyChanged(NameOf(TotalBasic))
                End If
            End Set
        End Property

        Public Property TotalAllowances As Decimal
            Get
                Return _totalAllowances
            End Get
            Set(value As Decimal)
                If _totalAllowances <> value Then
                    _totalAllowances = value
                    OnPropertyChanged(NameOf(TotalAllowances))
                End If
            End Set
        End Property

        Public Property TotalOvertime As Decimal
            Get
                Return _totalOvertime
            End Get
            Set(value As Decimal)
                If _totalOvertime <> value Then
                    _totalOvertime = value
                    OnPropertyChanged(NameOf(TotalOvertime))
                End If
            End Set
        End Property

        Public Property TotalDeductions As Decimal
            Get
                Return _totalDeductions
            End Get
            Set(value As Decimal)
                If _totalDeductions <> value Then
                    _totalDeductions = value
                    OnPropertyChanged(NameOf(TotalDeductions))
                End If
            End Set
        End Property

        Public Property TotalNetSalary As Decimal
            Get
                Return _totalNetSalary
            End Get
            Set(value As Decimal)
                If _totalNetSalary <> value Then
                    _totalNetSalary = value
                    OnPropertyChanged(NameOf(TotalNetSalary))
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
                    OnPropertyChanged(NameOf(IsApproved))
                    OnPropertyChanged(NameOf(IsEditable))
                End If
            End Set
        End Property

        Public ReadOnly Property IsApproved As Boolean
            Get
                Return String.Equals(Status, "Approved", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property IsEditable As Boolean
            Get
                Return Not IsApproved
            End Get
        End Property

        Public Property ApprovedBy As String
        Public Property ApprovedAt As DateTime?
        Public Property JournalID As Integer?
        Public Property Notes As String
        Public Property Details As ObservableCollection(Of PayrollDetail)

        Public ReadOnly Property DisplayTitle As String
            Get
                Return $"مسير رواتب شهر {Month:D2} / {Year}"
            End Get
        End Property

        Public Sub New()
            Details = New ObservableCollection(Of PayrollDetail)()
            Month = DateTime.Today.Month
            Year = DateTime.Today.Year
        End Sub

        Public Sub RecalculateTotals()
            If Details Is Nothing Then Return
            TotalBasic = Details.Sum(Function(d) d.BasicSalary)
            TotalAllowances = Details.Sum(Function(d) d.TotalAllowances)
            TotalOvertime = Details.Sum(Function(d) d.OvertimeAmount)
            TotalDeductions = Details.Sum(Function(d) d.TotalDeductions)
            TotalNetSalary = Details.Sum(Function(d) d.NetSalary)
        End Sub
    End Class
End Namespace
