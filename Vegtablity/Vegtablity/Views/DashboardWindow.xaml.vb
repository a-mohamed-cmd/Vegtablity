Imports System.Windows

Namespace Views
    Public Class DashboardWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
        End Sub

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
