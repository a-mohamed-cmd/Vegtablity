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

        Public Property SaveAttendanceCommand As ICommand
        Public Property FillAllPresentCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Event RequestSnackbar As Action(Of String)

        Public Sub New()
            AttendanceRecords = New ObservableCollection(Of AttendanceRecord)()
            SaveAttendanceCommand = New RelayCommand(AddressOf SaveAttendance)
            FillAllPresentCommand = New RelayCommand(AddressOf FillAllPresent)
            RefreshCommand = New RelayCommand(Sub() LoadAttendance())

            LoadPermissions("HRAttendance")
            LoadAttendance()
        End Sub

        Public Sub LoadAttendance()
            Try
                Dim list = _hrService.GetAttendanceByDate(AttendanceDate)
                AttendanceRecords.Clear()
                For Each item In list
                    AttendanceRecords.Add(item)
                Next
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب سجل الحضور: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub SaveAttendance(parameter As Object)
            Try
                For Each rec In AttendanceRecords
                    rec.AttendanceDate = AttendanceDate
                    _hrService.SaveAttendanceRecord(rec)
                Next
                RaiseEvent RequestSnackbar("💾 تم حفظ سجل الحضور والغياب وساعات الإضافي بنجاح 👌")
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
