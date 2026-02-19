Imports System.Windows

Namespace Views
    Public Class LoginWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub Window_MouseDown(sender As Object, e As MouseButtonEventArgs) Handles Me.MouseDown
            If e.ChangedButton = MouseButton.Left Then
                Me.DragMove()
            End If
        End Sub
    End Class
End Namespace
