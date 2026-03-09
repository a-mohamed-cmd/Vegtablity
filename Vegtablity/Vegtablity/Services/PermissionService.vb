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

        Public Function GetPermissionsForForm(roleID As Integer, formName As String) As Models.RolePermission
            Try
                Dim allPerms = GetPermissionsForRole(roleID)
                Dim formPerm = allPerms.FirstOrDefault(Function(p) p.FormName = formName)
                
                If formPerm IsNot Nothing Then
                    Return formPerm
                Else
                    Return New Models.RolePermission With {
                        .RoleID = roleID,
                        .FormName = formName,
                        .CanView = False,
                        .CanAdd = False,
                        .CanEdit = False,
                        .CanDelete = False,
                        .CanPrint = False
                    }
                End If
            Catch ex As Exception
                Return New Models.RolePermission()
            End Try
        End Function

        Public Function CanViewForm(roleID As Integer, formName As String) As Boolean
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
