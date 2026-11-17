Imports System.Windows
Imports System.Windows.Media
Imports System.Windows.Media.Animation
Imports Vegtablity.Helpers
Imports Vegtablity.Services

Namespace Views
    Public Class DashboardWindow
        Inherits Window

        Private _globalSnackbarTimer As System.Windows.Threading.DispatcherTimer

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnLoaded
            AddHandler Me.Closed, AddressOf OnWindowClosed
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.DashboardViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If
            RemoveHandler SnackbarService.SnackbarRequested, AddressOf ShowGlobalSnackbar
            AddHandler SnackbarService.SnackbarRequested, AddressOf ShowGlobalSnackbar
            CheckUpdatesAsync()
        End Sub

        Private Sub OnWindowClosed(sender As Object, e As EventArgs)
            RemoveHandler SnackbarService.SnackbarRequested, AddressOf ShowGlobalSnackbar
        End Sub

        Private Async Sub CheckUpdatesAsync()
            Try
                Dim updateService As New AutoUpdateService()
                Dim updateInfo = Await updateService.CheckForUpdateAsync()
                If updateInfo IsNot Nothing AndAlso updateInfo.HasUpdate Then
                    Dim dialog As New UpdateAvailableDialog(updateInfo, updateService)
                    dialog.Owner = Me
                    dialog.ShowDialog()
                End If
            Catch ex As Exception
                System.Diagnostics.Debug.WriteLine("Dashboard update check error: " & ex.Message)
            End Try
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As System.ComponentModel.PropertyChangedEventArgs)
            If e.PropertyName = "IsSidebarExpanded" Then
                Dim vm = TryCast(Me.DataContext, ViewModels.DashboardViewModel)
                If vm IsNot Nothing Then
                    If vm.IsSidebarExpanded Then
                        Dim sb = TryCast(Me.Resources("ExpandSidebar"), System.Windows.Media.Animation.Storyboard)
                        If sb IsNot Nothing Then sb.Begin(Me)
                    Else
                        Dim sb = TryCast(Me.Resources("CollapseSidebar"), System.Windows.Media.Animation.Storyboard)
                        If sb IsNot Nothing Then sb.Begin(Me)
                    End If
                End If
            End If
        End Sub

        ''' <summary>Navigation stack for back-button support</summary>
        Private ReadOnly _backStack As New Stack(Of System.Windows.Controls.UserControl)()

        ''' <summary>Allows child pages to push a new page into the content area</summary>
        ''' <param name="page">Page to navigate to</param>
        ''' <param name="keepCurrentInStack">If True, current page is pushed onto the back stack</param>
        Public Sub NavigateTo(page As System.Windows.Controls.UserControl,
                              Optional keepCurrentInStack As Boolean = False)
            Dim vm = TryCast(Me.DataContext, ViewModels.DashboardViewModel)
            If vm IsNot Nothing Then
                If keepCurrentInStack AndAlso vm.CurrentPage IsNot Nothing Then
                    _backStack.Push(vm.CurrentPage)
                End If
                vm.CurrentPage = page
                vm.IsHomePage = False
            End If
        End Sub

        ''' <summary>Navigate back to the previous page in the stack</summary>
        Public Sub GoBack()
            Dim vm = TryCast(Me.DataContext, ViewModels.DashboardViewModel)
            If vm IsNot Nothing AndAlso _backStack.Count > 0 Then
                vm.CurrentPage = _backStack.Pop()
                vm.IsHomePage = False
            End If
        End Sub

        ''' <summary>Returns True if back navigation is possible</summary>
        Public ReadOnly Property CanGoBack As Boolean
            Get
                Return _backStack.Count > 0
            End Get
        End Property

        Private Sub Window_MouseDown(sender As Object, e As MouseButtonEventArgs) Handles Me.MouseDown
            If e.ChangedButton = MouseButton.Left Then
                Me.DragMove()
            End If
        End Sub

        Private Sub MinimizeBtn_Click(sender As Object, e As RoutedEventArgs)
            Me.WindowState = WindowState.Minimized
        End Sub

        Private Sub MaximizeBtn_Click(sender As Object, e As RoutedEventArgs)
            If Me.WindowState = WindowState.Maximized Then
                Me.WindowState = WindowState.Normal
            Else
                Me.WindowState = WindowState.Maximized
            End If
        End Sub

        Private Sub CloseBtn_Click(sender As Object, e As RoutedEventArgs)
            Application.Current.Shutdown()
        End Sub

        ' ══════════════════════════════════════════════════
        '  Stats Cards Toggle (إخفاء / إظهار الإحصائيات)
        ' ══════════════════════════════════════════════════
        Private _statsVisible As Boolean = False

        Private Sub ToggleStatsBtn_Click(sender As Object, e As RoutedEventArgs)
            If _statsVisible Then
                ' Collapse
                Dim sb = TryCast(Me.Resources("CollapseStats"), System.Windows.Media.Animation.Storyboard)
                If sb IsNot Nothing Then sb.Begin(Me)
            Else
                ' Expand
                StatsPanel.Visibility = Visibility.Visible
                Dim sb = TryCast(Me.Resources("ExpandStats"), System.Windows.Media.Animation.Storyboard)
                If sb IsNot Nothing Then sb.Begin(Me)
                _statsVisible = True
                UpdateStatsBtnLabel()
            End If
        End Sub

        Private Sub CollapseStats_Completed(sender As Object, e As EventArgs)
            StatsPanel.Visibility = Visibility.Collapsed
            _statsVisible = False
            UpdateStatsBtnLabel()
        End Sub

        Private Sub UpdateStatsBtnLabel()
            Dim lbl = TryCast(ToggleStatsBtn.Template.FindName("StatsBtnLabel", ToggleStatsBtn), System.Windows.Controls.TextBlock)
            If lbl IsNot Nothing Then
                lbl.Text = If(_statsVisible, "إخفاء الإحصائيات", "إظهار الإحصائيات")
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Global SnapMessage / Snackbar Overlay
        ' ══════════════════════════════════════════════════

        Public Sub ShowGlobalSnackbar(message As String, severity As SnackbarSeverity)
            Dispatcher.BeginInvoke(New Action(Sub()
                If GlobalSnackbarBorder Is Nothing OrElse GlobalSnackbarText Is Nothing Then Return

                GlobalSnackbarText.Text = message
                Dim bc As New BrushConverter()
                Select Case severity
                    Case SnackbarSeverity.[Error]
                        GlobalSnackbarBorder.Background = DirectCast(bc.ConvertFromString("#991B1B"), Brush)
                        GlobalSnackbarBorder.BorderBrush = DirectCast(bc.ConvertFromString("#F87171"), Brush)
                        If GlobalSnackbarIcon IsNot Nothing Then GlobalSnackbarIcon.Text = "⛔"
                    Case SnackbarSeverity.Warning
                        GlobalSnackbarBorder.Background = DirectCast(bc.ConvertFromString("#92400E"), Brush)
                        GlobalSnackbarBorder.BorderBrush = DirectCast(bc.ConvertFromString("#FBBF24"), Brush)
                        If GlobalSnackbarIcon IsNot Nothing Then GlobalSnackbarIcon.Text = "⚠️"
                    Case Else
                        GlobalSnackbarBorder.Background = DirectCast(bc.ConvertFromString("#065F46"), Brush)
                        GlobalSnackbarBorder.BorderBrush = DirectCast(bc.ConvertFromString("#34D399"), Brush)
                        If GlobalSnackbarIcon IsNot Nothing Then GlobalSnackbarIcon.Text = "✅"
                End Select

                GlobalSnackbarBorder.Visibility = Visibility.Visible

                Dim dur As New Duration(TimeSpan.FromMilliseconds(220))
                Dim ease As New CubicEase() With {.EasingMode = EasingMode.EaseOut}
                Dim fadeIn As New DoubleAnimation(0, 1, dur) With {.EasingFunction = ease}
                GlobalSnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)

                If GlobalSnackbarTranslate IsNot Nothing Then
                    Dim slideUp As New DoubleAnimation(24, 0, dur) With {.EasingFunction = ease}
                    GlobalSnackbarTranslate.BeginAnimation(TranslateTransform.YProperty, slideUp)
                End If

                If _globalSnackbarTimer Is Nothing Then
                    _globalSnackbarTimer = New System.Windows.Threading.DispatcherTimer()
                    AddHandler _globalSnackbarTimer.Tick, Sub(s, args)
                                                              _globalSnackbarTimer.Stop()
                                                              HideGlobalSnackbar()
                                                          End Sub
                End If
                _globalSnackbarTimer.Stop()
                _globalSnackbarTimer.Interval = TimeSpan.FromSeconds(If(severity = SnackbarSeverity.[Error], 7.0, If(severity = SnackbarSeverity.Warning, 5.0, 3.5)))
                _globalSnackbarTimer.Start()
            End Sub))
        End Sub

        Private Sub HideGlobalSnackbar()
            If GlobalSnackbarBorder Is Nothing Then Return
            Dim dur As New Duration(TimeSpan.FromMilliseconds(180))
            Dim fadeOut As New DoubleAnimation(0, dur)
            AddHandler fadeOut.Completed, Sub(s, e)
                                              If GlobalSnackbarBorder.Opacity <= 0.05 Then
                                                  GlobalSnackbarBorder.Visibility = Visibility.Collapsed
                                              End If
                                          End Sub
            GlobalSnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
        End Sub

        Private Sub BtnCloseGlobalSnackbar_Click(sender As Object, e As RoutedEventArgs)
            If _globalSnackbarTimer IsNot Nothing Then _globalSnackbarTimer.Stop()
            HideGlobalSnackbar()
        End Sub

    End Class
End Namespace
