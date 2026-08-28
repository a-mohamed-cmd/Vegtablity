Imports System
Imports System.Text.RegularExpressions
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Data
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class PayrollRowControl
        Inherits UserControl

        Public Shared ReadOnly IsLockedProperty As DependencyProperty = DependencyProperty.Register(
            "IsLocked", GetType(Boolean), GetType(PayrollRowControl),
            New PropertyMetadata(False, AddressOf OnIsLockedChanged))

        Public Property IsLocked As Boolean
            Get
                Return CBool(GetValue(IsLockedProperty))
            End Get
            Set(value As Boolean)
                SetValue(IsLockedProperty, value)
            End Set
        End Property

        Private Shared Sub OnIsLockedChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, PayrollRowControl)
            If ctrl IsNot Nothing Then
                ctrl.ApplyLockState(CBool(e.NewValue))
            End If
        End Sub

        Public Sub New()
            InitializeComponent()
            AddHandler Loaded, Sub(s, e) ApplyLockState(IsLocked)
        End Sub

        Public Sub ApplyLockState(locked As Boolean)
            If TxtBasicSalary Is Nothing Then Return

            TxtBasicSalary.IsReadOnly = locked
            TxtOvertimeHours.IsReadOnly = locked
            TxtOvertimeAmount.IsReadOnly = locked
            TxtDeductionDays.IsReadOnly = locked
            TxtDeductionAmount.IsReadOnly = locked
            TxtAdvancesDeductions.IsReadOnly = locked

            CmbPaymentStatus.IsEnabled = Not locked
            BtnSaveRow.IsEnabled = Not locked
            BtnSaveRow.Opacity = If(locked, 0.35, 1.0)
            BtnSaveRow.ToolTip = If(locked, "المسير معتمد - لا يمكن تعديل هذا السطر", "حفظ تعديلات هذا الموظف (Enter)")

            Dim readOnlyBg As New SolidColorBrush(Color.FromRgb(248, 250, 252))
            Dim editBg As Brush = Brushes.White
            Dim currentBg = If(locked, readOnlyBg, editBg)

            TxtBasicSalary.Background = currentBg
            TxtOvertimeHours.Background = currentBg
            TxtOvertimeAmount.Background = currentBg
            TxtDeductionDays.Background = currentBg
            TxtDeductionAmount.Background = currentBg
            TxtAdvancesDeductions.Background = currentBg
        End Sub

        Private Sub SaveRow_Click(sender As Object, e As RoutedEventArgs)
            If IsLocked Then Return

            CommitActiveTextBox()
            Dim detail = TryCast(Me.DataContext, PayrollDetail)
            If detail Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm IsNot Nothing AndAlso vm.SaveDetailCommand IsNot Nothing Then
                vm.SaveDetailCommand.Execute(detail)
            End If
        End Sub

        Private Sub PrintPayslip_Click(sender As Object, e As RoutedEventArgs)
            Dim detail = TryCast(Me.DataContext, PayrollDetail)
            If detail Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm IsNot Nothing AndAlso vm.PrintPayslipCommand IsNot Nothing Then
                vm.PrintPayslipCommand.Execute(detail)
            End If
        End Sub

        Private Function FindParentViewModel() As HRPayrollViewModel
            Dim current As DependencyObject = Me
            While current IsNot Nothing
                If TypeOf current Is FrameworkElement Then
                    Dim fe = DirectCast(current, FrameworkElement)
                    Dim vm = TryCast(fe.DataContext, HRPayrollViewModel)
                    If vm IsNot Nothing Then Return vm
                End If
                current = VisualTreeHelper.GetParent(current)
            End While
            Return Nothing
        End Function

        Private Sub NumericBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            If IsLocked Then
                e.Handled = True
                Return
            End If

            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim newText = tb.Text.Substring(0, tb.SelectionStart) & e.Text & tb.Text.Substring(tb.SelectionStart + tb.SelectionLength)
            e.Handled = Not Regex.IsMatch(newText, "^\d*\.?\d*$")
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Enter Key Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub InputBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter OrElse e.Key = Key.Return Then
                e.Handled = True

                ' Commit current binding
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim be = BindingOperations.GetBindingExpression(tb, TextBox.TextProperty)
                    If be IsNot Nothing Then be.UpdateSource()
                End If

                ' If locked, do not allow trigger save
                If IsLocked Then
                    Dim currentEl = TryCast(sender, UIElement)
                    If currentEl IsNot Nothing Then
                        currentEl.MoveFocus(New TraversalRequest(FocusNavigationDirection.Next))
                    End If
                    Return
                End If

                ' Navigate to next logical cell in row
                If sender Is TxtBasicSalary Then
                    TxtOvertimeHours.Focus()
                    TxtOvertimeHours.SelectAll()
                ElseIf sender Is TxtOvertimeHours Then
                    TxtOvertimeAmount.Focus()
                    TxtOvertimeAmount.SelectAll()
                ElseIf sender Is TxtOvertimeAmount Then
                    TxtDeductionDays.Focus()
                    TxtDeductionDays.SelectAll()
                ElseIf sender Is TxtDeductionDays Then
                    TxtDeductionAmount.Focus()
                    TxtDeductionAmount.SelectAll()
                ElseIf sender Is TxtDeductionAmount Then
                    TxtAdvancesDeductions.Focus()
                    TxtAdvancesDeductions.SelectAll()
                ElseIf sender Is TxtAdvancesDeductions Then
                    CmbPaymentStatus.Focus()
                ElseIf sender Is CmbPaymentStatus Then
                    BtnSaveRow.Focus()
                ElseIf sender Is BtnSaveRow Then
                    SaveRow_Click(sender, New RoutedEventArgs())
                Else
                    ' Fallback standard forward traversal
                    Dim current = TryCast(sender, UIElement)
                    If current IsNot Nothing Then
                        current.MoveFocus(New TraversalRequest(FocusNavigationDirection.Next))
                    End If
                End If
            End If
        End Sub

        Private Sub CommitActiveTextBox()
            Dim focused = TryCast(Keyboard.FocusedElement, TextBox)
            If focused IsNot Nothing Then
                Dim be = BindingOperations.GetBindingExpression(focused, TextBox.TextProperty)
                If be IsNot Nothing Then be.UpdateSource()
            End If
        End Sub
    End Class
End Namespace
