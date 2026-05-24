Imports System.ComponentModel
Imports System.Runtime.CompilerServices

Namespace ViewModels
    Public Class BaseViewModel
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Protected Overridable Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub

        Protected Function SetProperty(Of T)(ByRef field As T, value As T, <CallerMemberName> Optional propertyName As String = Nothing) As Boolean
            If EqualityComparer(Of T).Default.Equals(field, value) Then Return False
            field = value
            OnPropertyChanged(propertyName)
            Return True
        End Function

        ' --- Global Permissions ---
        Private _currentPermissions As Models.RolePermission
        Public Property CurrentPermissions As Models.RolePermission
            Get
                Return _currentPermissions
            End Get
            Set(value As Models.RolePermission)
                SetProperty(_currentPermissions, value)
            End Set
        End Property

        Public Sub LoadPermissions(formName As String)
            Dim permService As New Services.PermissionService()
            If Services.Session.CurrentUser IsNot Nothing Then
                CurrentPermissions = permService.GetPermissionsForForm(Services.Session.CurrentUser.RoleID, formName)
            End If
        End Sub
    End Class
End Namespace
