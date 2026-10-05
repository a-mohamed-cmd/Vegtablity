Imports System
Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HRAttendanceViewModel
        Inherits BaseViewModel

        Private ReadOnly _hrService As New HRService()

        Private _attendanceDate As DateTime = DateTime.Today
        Public Property AttendanceDate As DateTime
            Get
                Return _attendanceDate
            End Get
            Set(value As DateTime)
                If SetProperty(_attendanceDate, value) Then
                    LoadAttendance()
                End If
            End Set
        End Property

        Public Property AttendanceRecords As ObservableCollection(Of AttendanceRecord)
        Public Property EmployeesOnLeave As ObservableCollection(Of EmployeeLeave)

        Private _hasEmployeesOnLeave As Boolean = False
        Public Property HasEmployeesOnLeave As Boolean
            Get
                Return _hasEmployeesOnLeave
            End Get
            Set(value As Boolean)
                SetProperty(_hasEmployeesOnLeave, value)
            End Set
        End Property

        Private _employeesOnLeaveSummary As String
        Public Property EmployeesOnLeaveSummary As String
            Get
                Return _employeesOnLeaveSummary
            End Get
            Set(value As String)
                SetProperty(_employeesOnLeaveSummary, value)
            End Set
        End Property

        Public Property SaveAttendanceCommand As ICommand
        Public Property SaveSingleRecordCommand As ICommand
        Public Property FillAllPresentCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Event RequestSnackbar As Action(Of String)

        Public Sub New()
            AttendanceRecords = New ObservableCollection(Of AttendanceRecord)()
            EmployeesOnLeave = New ObservableCollection(Of EmployeeLeave)()
            SaveAttendanceCommand = New RelayCommand(AddressOf SaveAttendance)
            SaveSingleRecordCommand = New RelayCommand(AddressOf SaveSingleRecord)
            FillAllPresentCommand = New RelayCommand(AddressOf FillAllPresent)
            RefreshCommand = New RelayCommand(Sub() LoadAttendance())

            LoadPermissions("HRAttendance")
            LoadAttendance()
        End Sub

        Public Sub LoadAttendance()
            Try
                ' 1. جلب الموظفين المؤهلين لتسجيل الحضور (تم استبعاد من هم في إجازة حتى مباشرة العمل)
                Dim list = _hrService.GetAttendanceByDate(AttendanceDate)
                AttendanceRecords.Clear()
                For Each item In list
                    AttendanceRecords.Add(item)
                Next

                ' 2. جلب الموظفين المستبعدين لوجودهم في إجازة حالياً
                Dim onLeaveList = _hrService.GetEmployeesOnLeaveByDate(AttendanceDate)
                EmployeesOnLeave.Clear()
                For Each l In onLeaveList
                    EmployeesOnLeave.Add(l)
                Next

                HasEmployeesOnLeave = EmployeesOnLeave.Any()
                If HasEmployeesOnLeave Then
                    Dim names = String.Join("، ", EmployeesOnLeave.Select(Function(x) $"{x.EmployeeName} ({x.LeaveTypeName})"))
                    EmployeesOnLeaveSummary = $"🏖️ يوجد {EmployeesOnLeave.Count} موظف في إجازة حالياً (مستبعدون من كشف الحضور حتى تسجيل مباشرة العمل): {names}"
                Else
                    EmployeesOnLeaveSummary = String.Empty
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب سجل الحضور: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Public Sub SaveSingleRecord(parameter As Object)
            Dim rec = TryCast(parameter, AttendanceRecord)
            If rec Is Nothing Then Return
            Try
                rec.AttendanceDate = AttendanceDate.Date
                _hrService.SaveAttendanceRecord(rec)
                RaiseEvent RequestSnackbar($"💾 تم حفظ وتعديل حضور الموظف {rec.EmployeeName} بنجاح!")
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الحضور: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub SaveAttendance(parameter As Object)
            Try
                For Each rec In AttendanceRecords
                    rec.AttendanceDate = AttendanceDate.Date
                    _hrService.SaveAttendanceRecord(rec)
                Next
                RaiseEvent RequestSnackbar("💾 تم حفظ وتحديث سجل الحضور والغياب وساعات الإضافي بنجاح 👌")
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الحضور: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub FillAllPresent(parameter As Object)
            For Each rec In AttendanceRecords
                rec.Status = "Present"
                rec.WorkHours = 8.0D
                rec.DelayMinutes = 0
                rec.AbsenceDeductionDays = 0.0D
            Next
            RaiseEvent RequestSnackbar("⚡ تم تعيين جميع الموظفين حاضرين (8 ساعات عمل) بنجاح")
        End Sub
    End Class
End Namespace
