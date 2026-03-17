Imports System.Windows

Namespace Views
    Public Class LicenseWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub LicenseWindow_Loaded(ByVal sender As Object, ByVal e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.LicenseViewModel)
            If vm IsNot Nothing Then
                vm.CheckLicense()
            End If
        End Sub
    End Class
End Namespace
