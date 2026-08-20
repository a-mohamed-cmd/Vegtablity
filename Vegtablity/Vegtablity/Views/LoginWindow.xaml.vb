Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Services

Namespace Views
    Public Class LoginWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnLoaded
        End Sub

        Private Async Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            Try
                Dim updateService As New AutoUpdateService()
                Dim updateInfo = Await updateService.CheckForUpdateAsync()
                If updateInfo IsNot Nothing AndAlso updateInfo.HasUpdate Then
                    Dim dialog As New UpdateAvailableDialog(updateInfo, updateService)
                    dialog.Owner = Me
                    dialog.ShowDialog()
                End If
            Catch ex As Exception
                System.Diagnostics.Debug.WriteLine("Update check error: " & ex.Message)
            End Try
        End Sub

        Private Sub Window_MouseDown(sender As Object, e As MouseButtonEventArgs) Handles Me.MouseDown
            If e.ChangedButton = MouseButton.Left Then
                Me.DragMove()
            End If
        End Sub
    End Class
End Namespace
