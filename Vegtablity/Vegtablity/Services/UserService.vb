Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class UserService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function Login(username As String, passwordHash As String) As User
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of User)(
                    Helpers.StoredProcedures.SP_USER_LOGIN,
                    New With {.Username = username, .PasswordHash = passwordHash},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function
    End Class
End Namespace
