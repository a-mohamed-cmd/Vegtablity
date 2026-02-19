Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class UserManagementService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllUsers() As List(Of User)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of User)(
                    Helpers.StoredProcedures.SP_USER_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function AddUser(user As User, passwordHash As String) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_USER_ADD,
                    New With {
                        user.RoleID,
                        user.Username,
                        .PasswordHash = passwordHash,
                        user.FullName,
                        user.IsActive
                    },
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub UpdateUser(user As User)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_USER_UPDATE,
                    New With {user.UserID, user.RoleID, user.Username, user.FullName, user.IsActive},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub ResetPassword(userID As Integer, newPasswordHash As String)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_USER_RESETPASSWORD,
                    New With {.UserID = userID, .NewPasswordHash = newPasswordHash},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteUser(userID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_USER_DELETE,
                    New With {.UserID = userID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub
    End Class
End Namespace
