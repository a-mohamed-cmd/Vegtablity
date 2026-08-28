Imports System
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media.Animation
Imports System.Windows.Threading
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Views
    Partial Public Class HREndOfServicePage
        Inherits UserControl

        Private _isSidePanelCollapsed As Boolean = False
        Private _snackbarTimer As DispatcherTimer

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub HREndOfServicePage_DataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs) Handles Me.DataContextChanged
            Dim oldVm = TryCast(e.OldValue, HREndOfServiceViewModel)
            If oldVm IsNot Nothing Then
                RemoveHandler oldVm.RequestSnackbar, AddressOf ShowSnackbar
            End If

            Dim newVm = TryCast(e.NewValue, HREndOfServiceViewModel)
            If newVm IsNot Nothing Then
                AddHandler newVm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        Private Sub HREndOfServicePage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, HREndOfServiceViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Snackbar Notification System
        ' ══════════════════════════════════════════════════════

        Private Sub ShowSnackbar(message As String)
            If SnackbarBorder Is Nothing OrElse SnackbarText Is Nothing Then Return

            If message.Contains("❌") OrElse message.Contains("خطأ") Then
                SnackbarIcon.Text = "❌"
            ElseIf message.Contains("⚠️") OrElse message.Contains("تنبيه") Then
                SnackbarIcon.Text = "⚠️"
            ElseIf message.Contains("➕") OrElse message.Contains("جديد") Then
                SnackbarIcon.Text = "➕"
            ElseIf message.Contains("💾") OrElse message.Contains("حفظ") Then
                SnackbarIcon.Text = "💾"
            ElseIf message.Contains("🖨️") OrElse message.Contains("طباعة") Then
                SnackbarIcon.Text = "🖨️"
            Else
                SnackbarIcon.Text = "✅"
            End If

            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible

            Dim fadeIn As New DoubleAnimation With {
                .From = 0,
                .To = 1,
                .Duration = TimeSpan.FromSeconds(0.25)
            }
            SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)

            If _snackbarTimer Is Nothing Then
                _snackbarTimer = New DispatcherTimer()
                _snackbarTimer.Interval = TimeSpan.FromSeconds(3)
                AddHandler _snackbarTimer.Tick, AddressOf OnSnackbarTimerTick
            End If

            _snackbarTimer.Stop()
            _snackbarTimer.Start()
        End Sub

        Private Sub OnSnackbarTimerTick(sender As Object, e As EventArgs)
            If _snackbarTimer IsNot Nothing Then _snackbarTimer.Stop()
            If SnackbarBorder Is Nothing Then Return

            Dim fadeOut As New DoubleAnimation With {
                .From = 1,
                .To = 0,
                .Duration = TimeSpan.FromSeconds(0.3)
            }
            AddHandler fadeOut.Completed, Sub()
                                              SnackbarBorder.Visibility = Visibility.Collapsed
                                          End Sub
            SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Side Panel Toggle Animation
        ' ══════════════════════════════════════════════════════

        Private Sub ToggleSidePanel_Click(sender As Object, e As RoutedEventArgs)
            Dim targetWidth As Double = If(_isSidePanelCollapsed, 460, 0)
            Dim anim As New DoubleAnimation With {
                .To = targetWidth,
                .Duration = TimeSpan.FromSeconds(0.35),
                .EasingFunction = New CubicEase With {.EasingMode = EasingMode.EaseInOut}
            }

            If Not _isSidePanelCollapsed Then
                SidePanelBorder.Margin = New Thickness(0)
            Else
                SidePanelBorder.Margin = New Thickness(0, 0, 15, 0)
            End If

            SidePanelBorder.BeginAnimation(FrameworkElement.WidthProperty, anim)
            _isSidePanelCollapsed = Not _isSidePanelCollapsed
            BtnToggleSidePanel.Content = If(_isSidePanelCollapsed, "▶ فتح الحاسبة", "◀ طي الحاسبة")
        End Sub

        ' ══════════════════════════════════════════════════════
        '  SearchableDropdown Events — اختيار الموظف
        ' ══════════════════════════════════════════════════════

        Private Sub EmployeeDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, HREndOfServiceViewModel)
            If vm IsNot Nothing Then
                vm.FilterEmployees(e)
            End If
        End Sub

        Private Sub EmployeeDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Employee)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, HREndOfServiceViewModel)
            If vm IsNot Nothing Then
                vm.SelectedEmployee = selected
            End If
        End Sub

        Private Sub EmployeeDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New TraversalRequest(FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then
                ctrl.MoveFocus(req)
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Decimal and Financial Inputs Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub DecimalBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim inputChar = e.Text.Replace(",", ".")
            Dim currentText = tb.Text
            Dim selStart = tb.SelectionStart
            Dim selLen = tb.SelectionLength

            Dim newText = currentText.Substring(0, selStart) & inputChar & currentText.Substring(selStart + selLen)

            Dim isValid = Regex.IsMatch(newText, "^\d*\.?\d*$")
            If Not isValid Then
                e.Handled = True
            End If
        End Sub

        Private Sub DecimalBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            If e.Key = Key.Enter Then
                e.Handled = True
                Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                tb.MoveFocus(req)
                Return
            End If

            Dim isDotKey = (e.Key = Key.OemPeriod OrElse e.Key = Key.Decimal OrElse e.Key = Key.OemComma)
            If isDotKey Then
                Dim text = tb.Text
                Dim selStart = tb.SelectionStart
                Dim selLen = tb.SelectionLength
                Dim textWithoutSelection = text.Remove(selStart, selLen)

                If textWithoutSelection.Contains(".") Then
                    e.Handled = True
                Else
                    tb.Text = textWithoutSelection.Insert(selStart, ".")
                    tb.SelectionStart = selStart + 1
                    e.Handled = True
                End If
            End If
        End Sub

        Private Sub DecimalBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim raw = tb.Text.Trim().Replace(",", ".")
            Dim parsedVal As Decimal = 0

            If String.IsNullOrWhiteSpace(raw) Then
                parsedVal = 0
                tb.Text = "0"
            ElseIf Decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, parsedVal) OrElse
                   Decimal.TryParse(raw, NumberStyles.Any, CultureInfo.CurrentCulture, parsedVal) Then
                If parsedVal < 0 Then parsedVal = 0
                tb.Text = parsedVal.ToString("G29", CultureInfo.InvariantCulture)
            Else
                parsedVal = 0
                tb.Text = "0"
            End If

            Dim be = tb.GetBindingExpression(TextBox.TextProperty)
            If be IsNot Nothing Then
                be.UpdateSource()
            End If

            Dim vm = TryCast(Me.DataContext, HREndOfServiceViewModel)
            If vm IsNot Nothing Then
                vm.Recalculate(Nothing)
            End If
        End Sub
    End Class
End Namespace
