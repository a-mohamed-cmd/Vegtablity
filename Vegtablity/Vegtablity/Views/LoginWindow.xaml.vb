Imports System.ComponentModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Services
Imports Vegtablity.ViewModels

Namespace Views
    Public Class LoginWindow
        Inherits Window

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnLoaded
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            
            Dim vm = TryCast(Me.DataContext, INotifyPropertyChanged)
            If vm IsNot Nothing Then
                AddHandler vm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            Dim oldVm = TryCast(e.OldValue, INotifyPropertyChanged)
            If oldVm IsNot Nothing Then
                RemoveHandler oldVm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If

            Dim newVm = TryCast(e.NewValue, INotifyPropertyChanged)
            If newVm IsNot Nothing Then
                AddHandler newVm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(LoginViewModel.ChangeSuccessMessage) Then
                Dim vm = TryCast(Me.DataContext, LoginViewModel)
                If vm IsNot Nothing AndAlso Not String.IsNullOrEmpty(vm.ChangeSuccessMessage) Then
                    txtOldPassword.Password = String.Empty
                    txtNewPassword.Password = String.Empty
                    txtConfirmPassword.Password = String.Empty
                End If
            End If
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

        Private Sub btnSubmitChangePassword_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, LoginViewModel)
            If vm IsNot Nothing Then
                vm.ExecuteChangePassword(txtOldPassword.Password, txtNewPassword.Password, txtConfirmPassword.Password)
            End If
        End Sub

        Private Sub OnBackToLoginClicked(sender As Object, e As MouseButtonEventArgs)
            txtOldPassword.Password = String.Empty
            txtNewPassword.Password = String.Empty
            txtConfirmPassword.Password = String.Empty
            Dim vm = TryCast(Me.DataContext, LoginViewModel)
            If vm IsNot Nothing Then
                vm.SwitchToLoginCommand.Execute(Nothing)
            End If
        End Sub
    End Class
End Namespace
