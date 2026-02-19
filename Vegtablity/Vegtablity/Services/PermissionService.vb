Imports System.Data
Imports Dapper

Namespace Services
    Public Class PermissionService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetPermissionsForRole(roleID As Integer) As List(Of Models.RolePermission)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of Models.RolePermission)(
                        Helpers.StoredProcedures.SP_PERMISSION_GETBYROLE,
                        New With {.RoleID = roleID},
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of Models.RolePermission)()
            End Try
        End Function

        Public Function CanViewForm(roleID As Integer, formName As String) As Boolean
            ' Admin always has access
            If Session.CurrentUser IsNot Nothing AndAlso Session.CurrentUser.RoleName = "Admin" Then
                Return True
            End If

            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim result = conn.QueryFirstOrDefault(Of Boolean?)(
                        Helpers.StoredProcedures.SP_PERMISSION_CANVIEW,
                        New With {.RoleID = roleID, .FormName = formName},
                        commandType:=CommandType.StoredProcedure)
                    Return result.HasValue AndAlso result.Value
                End Using
            Catch ex As Exception
                Return False
            End Try
        End Function
    End Class
End Namespace
