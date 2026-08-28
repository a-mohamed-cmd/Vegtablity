Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media.Animation
Imports System.Windows.Threading
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Views
    Partial Public Class HRLeavesPage
        Inherits UserControl

        Private _isSidePanelCollapsed As Boolean = False
        Private _snackbarTimer As DispatcherTimer

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub HRLeavesPage_DataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs) Handles Me.DataContextChanged
            Dim oldVm = TryCast(e.OldValue, HRLeavesViewModel)
            If oldVm IsNot Nothing Then
                RemoveHandler oldVm.RequestSnackbar, AddressOf ShowSnackbar
            End If

            Dim newVm = TryCast(e.NewValue, HRLeavesViewModel)
            If newVm IsNot Nothing Then
                AddHandler newVm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        Private Sub HRLeavesPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, HRLeavesViewModel)
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

            If message.Contains("🏖️") OrElse message.Contains("إجازة") Then
                SnackbarIcon.Text = "🏖️"
            ElseIf message.Contains("🏢") OrElse message.Contains("مباشرة") Then
                SnackbarIcon.Text = "🏢"
            ElseIf message.Contains("❌") OrElse message.Contains("خطأ") Then
                SnackbarIcon.Text = "❌"
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
            Dim targetWidth As Double = If(_isSidePanelCollapsed, 400, 0)
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
            BtnToggleSidePanel.Content = If(_isSidePanelCollapsed, "▶ فتح النماذج", "◀ طي النماذج")
        End Sub

        ' ══════════════════════════════════════════════════════
        '  SearchableDropdown Events — اختيار الموظف
        ' ══════════════════════════════════════════════════════

        Private Sub EmployeeDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, HRLeavesViewModel)
            If vm IsNot Nothing Then
                vm.FilterEmployees(e)
            End If
        End Sub

        Private Sub EmployeeDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Employee)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, HRLeavesViewModel)
            If vm IsNot Nothing Then
                vm.SelectedEmployeeForLeave = selected
            End If
        End Sub

        Private Sub EmployeeDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New TraversalRequest(FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then
                ctrl.MoveFocus(req)
            End If
        End Sub
    End Class
End Namespace
