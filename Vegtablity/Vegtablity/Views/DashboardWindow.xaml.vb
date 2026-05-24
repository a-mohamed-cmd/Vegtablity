Imports System.Windows

Namespace Views
    Public Class DashboardWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnLoaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.DashboardViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If
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

    End Class
End Namespace
