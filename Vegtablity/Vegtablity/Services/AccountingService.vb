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
        Public Function GetAccountStatement(accountID As Integer, startDate As Date, endDate As Date) As AccountStatementReport
            Dim report As New AccountStatementReport()
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Using multi = conn.QueryMultiple(
                    Helpers.StoredProcedures.SP_REPORT_ACCOUNTSTATEMENT,
                    New With {.AccountID = accountID, .StartDate = startDate, .EndDate = endDate},
                    commandType:=CommandType.StoredProcedure)

                    ' 1. Opening Balance
                    report.OpeningBalance = multi.Read(Of Decimal)().FirstOrDefault()

                    ' 2. Transactions
                    report.Transactions = multi.Read(Of AccountStatementItem)().ToList()
                End Using
            End Using
            Return report
        End Function

        ' === Manual Journal Entry Methods ===

        Public Function GetAllJournalHeaders() As List(Of JournalHeader)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of JournalHeader)(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_GETALL,
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetJournalDetails(jid As Integer) As List(Of JournalDetail)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of JournalDetail)(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_GETDETAILS,
                    New With {.JID = jid},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function SaveJournalEntry(header As JournalHeader) As Integer
            ' Build XML for details (works on all SQL Server versions)
            Dim xmlBuilder As New Text.StringBuilder()
            xmlBuilder.Append("<details>")
            For Each d In header.Details
                ' Escape special characters for XML
                Dim notes = If(d.Notes, "").Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("""", "&quot;")
                
                xmlBuilder.AppendFormat("<item AccountID=""{0}"" Debit=""{1}"" Credit=""{2}"" Notes=""{3}"" />",
                                         d.AccountID,
                                         d.Debit.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
                                         d.Credit.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
                                         notes)
            Next
            xmlBuilder.Append("</details>")

            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_SAVE,
                    New With {
                        header.JID,
                        header.JDate,
                        header.Description,
                        header.UserID,
                        header.TotalAmount,
                        .DetailsXml = xmlBuilder.ToString()
                    },
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub PostJournalEntry(jid As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_POST,
                    New With {.JID = jid},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

    End Class
End Namespace
