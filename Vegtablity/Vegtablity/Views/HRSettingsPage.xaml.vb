Imports System
Imports System.Text.RegularExpressions
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media.Animation
Imports System.Windows.Threading
Imports Vegtablity.ViewModels

Namespace Views
    Partial Public Class HRSettingsPage
        Inherits UserControl

        Private _isSidePanelCollapsed As Boolean = False
        Private _snackbarTimer As DispatcherTimer

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub HRSettingsPage_DataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs) Handles Me.DataContextChanged
            Dim oldVm = TryCast(e.OldValue, HRSettingsViewModel)
            If oldVm IsNot Nothing Then
                RemoveHandler oldVm.RequestSnackbar, AddressOf ShowSnackbar
            End If

            Dim newVm = TryCast(e.NewValue, HRSettingsViewModel)
            If newVm IsNot Nothing Then
                AddHandler newVm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        Private Sub HRSettingsPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, HRSettingsViewModel)
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
            ElseIf message.Contains("🗑️") OrElse message.Contains("حذف") Then
                SnackbarIcon.Text = "🗑️"
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
            BtnToggleSidePanel.Content = If(_isSidePanelCollapsed, "▶ فتح المحرر", "◀ طي المحرر")
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Number Box Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub NumberBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        Private Sub NumberBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            e.Handled = Not Regex.IsMatch(e.Text, "^\d+$")
        End Sub

        Private Sub NumberBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            If e.Key = Key.Enter Then
                e.Handled = True
                Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                tb.MoveFocus(req)
            End If
        End Sub
    End Class
End Namespace
