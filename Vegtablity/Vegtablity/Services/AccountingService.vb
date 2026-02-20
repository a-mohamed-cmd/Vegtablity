Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class AccountingService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllAccounts() As List(Of Account)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Account)(
                    Helpers.StoredProcedures.SP_ACCOUNT_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetAccountByID(accountID As Integer) As Account
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of Account)(
                    Helpers.StoredProcedures.SP_ACCOUNT_GETBYID,
                    New With {.AccountID = accountID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Function SaveAccount(a As Account) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_ACCOUNT_SAVE,
                    New With {a.AccountID, a.AccountCode, a.AccountName, a.ParentAccountID, a.AccountType, a.AccountLevel, a.IsTransactional},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeleteAccount(accountID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_ACCOUNT_DELETE,
                    New With {.AccountID = accountID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function SearchAccounts(searchText As String) As List(Of Account)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Account)(
                    Helpers.StoredProcedures.SP_ACCOUNT_SEARCH,
                    New With {.SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetParentAccounts() As List(Of Account)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Account)(
                    Helpers.StoredProcedures.SP_ACCOUNT_GETPARENTS,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function
    End Class
End Namespace
