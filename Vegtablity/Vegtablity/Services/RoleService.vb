Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class RoleService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' ===== Roles =====

        Public Function GetAllRoles() As List(Of Role)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Role)(
                    Helpers.StoredProcedures.SP_ROLE_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function AddRole(role As Role) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_ROLE_ADD,
                    New With {role.RoleName, role.Description},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub UpdateRole(role As Role)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_ROLE_UPDATE,
                    New With {role.RoleID, role.RoleName, role.Description},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteRole(roleID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_ROLE_DELETE,
                    New With {.RoleID = roleID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ===== Permissions =====

        Public Function GetPermissionsForRole(roleID As Integer) As List(Of RolePermission)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of RolePermission)(
                    Helpers.StoredProcedures.SP_PERMISSION_GETBYROLE,
                    New With {.RoleID = roleID},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Sub SavePermission(perm As RolePermission)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PERMISSION_SAVE,
                    New With {perm.PermID, perm.RoleID, perm.FormName, perm.CanAdd, perm.CanEdit, perm.CanDelete, perm.CanView, perm.CanPrint},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeletePermission(permID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PERMISSION_DELETE,
                    New With {.PermID = permID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace
