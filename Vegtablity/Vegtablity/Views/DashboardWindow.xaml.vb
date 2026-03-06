Imports System.Windows

Namespace Views
    Public Class DashboardWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
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
    End Class
End Namespace
