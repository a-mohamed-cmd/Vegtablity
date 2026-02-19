Imports System.Windows

Namespace Views
    Public Class UserManagementWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub TitleBar_MouseDown(sender As Object, e As MouseButtonEventArgs)
            If e.ChangedButton = MouseButton.Left Then
                Me.DragMove()
            End If
        End Sub

        Private Sub CloseBtn_Click(sender As Object, e As RoutedEventArgs)
            Me.Close()
        End Sub
    End Class
End Namespace
