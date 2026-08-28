Imports System
Imports System.Text.RegularExpressions
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models.HR

Namespace Controls
    Partial Public Class AttendanceRowControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            AddHandler Me.Loaded, AddressOf OnLoaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            UpdateRowStyling()
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            UpdateRowStyling()
        End Sub

        Public Sub UpdateRowStyling()
            Dim record = TryCast(Me.DataContext, AttendanceRecord)
            If record Is Nothing OrElse MainRowBorder Is Nothing Then Return

            Select Case record.Status
                Case "Present"
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(255, 255, 255))
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240))
                Case "Absent"
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(254, 242, 242)) '#FEF2F2
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(254, 202, 202)) '#FECACA
                Case "Late"
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(255, 251, 235)) '#FFFBEB
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138)) '#FDE68A
                Case "Leave"
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(239, 246, 255)) '#EFF6FF
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(191, 219, 254)) '#BFDBFE
                Case "Holiday"
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(250, 245, 255)) '#FAF5FF
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(233, 213, 255)) '#E9D5FF
                Case Else
                    MainRowBorder.Background = New SolidColorBrush(Color.FromRgb(255, 255, 255))
                    MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240))
            End Select
        End Sub

        Private Sub CmbStatus_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim record = TryCast(Me.DataContext, AttendanceRecord)
            If record IsNot Nothing AndAlso CmbStatus.SelectedValue IsNot Nothing Then
                Dim val = CStr(CmbStatus.SelectedValue)
                record.Status = val

                ' Smart auto-adjustment
                If val = "Absent" Then
                    If record.WorkHours = 8 Then record.WorkHours = 0
                    If record.AbsenceDeductionDays = 0 Then record.AbsenceDeductionDays = 1.0D
                ElseIf val = "Present" Then
                    If record.WorkHours = 0 Then record.WorkHours = 8.0D
                    record.AbsenceDeductionDays = 0.0D
                End If
            End If
            UpdateRowStyling()
        End Sub

        Private Sub SetPresent_Click(sender As Object, e As RoutedEventArgs)
            Dim record = TryCast(Me.DataContext, AttendanceRecord)
            If record Is Nothing Then Return
            record.Status = "Present"
            record.WorkHours = 8.0D
            record.DelayMinutes = 0
            record.AbsenceDeductionDays = 0.0D
            UpdateRowStyling()
        End Sub

        Private Sub SetAbsent_Click(sender As Object, e As RoutedEventArgs)
            Dim record = TryCast(Me.DataContext, AttendanceRecord)
            If record Is Nothing Then Return
            record.Status = "Absent"
            record.WorkHours = 0.0D
            record.AbsenceDeductionDays = 1.0D
            UpdateRowStyling()
        End Sub

        Private Sub NumericBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim newText = tb.Text.Substring(0, tb.SelectionStart) & e.Text & tb.Text.Substring(tb.SelectionStart + tb.SelectionLength)
            e.Handled = Not Regex.IsMatch(newText, "^\d*\.?\d*$")
        End Sub

        Private Sub IntegerBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            e.Handled = Not Regex.IsMatch(e.Text, "^\d+$")
        End Sub
    End Class
End Namespace
