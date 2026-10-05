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

        Public Function ChangePassword(username As String, oldPassword As String, newPassword As String) As ChangePasswordResult
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim res = conn.QueryFirstOrDefault(Of ChangePasswordResult)(
                    Helpers.StoredProcedures.SP_USER_CHANGE_PASSWORD,
                    New With {
                        .Username = username,
                        .OldPasswordHash = oldPassword,
                        .NewPasswordHash = newPassword
                    },
                    commandType:=CommandType.StoredProcedure)

                If res IsNot Nothing Then
                    Return res
                Else
                    Return New ChangePasswordResult With {.StatusCode = 0, .Message = "تعذر الاتصال بقاعدة البيانات."}
                End If
            End Using
        End Function
    End Class

    Public Class ChangePasswordResult
        Public Property StatusCode As Integer
        Public Property Message As String
        Public ReadOnly Property Success As Boolean
            Get
                Return StatusCode = 1
            End Get
        End Property
    End Class
End Namespace
