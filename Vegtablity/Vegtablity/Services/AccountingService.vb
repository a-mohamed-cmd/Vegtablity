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
                If a.AccountID = 0 Then
                    ' Insert mode
                    Return conn.ExecuteScalar(Of Integer)(
                        Helpers.StoredProcedures.SP_ACCOUNT_SAVE,
                        New With {a.AccountID, a.AccountCode, a.AccountName, a.ParentAccountID, a.AccountType, a.AccountLevel, a.IsTransactional},
                        commandType:=CommandType.StoredProcedure)
                Else
                    ' Update mode (Explicit)
                    Return conn.ExecuteScalar(Of Integer)(
                        Helpers.StoredProcedures.SP_ACCOUNT_UPDATE,
                        New With {a.AccountID, a.AccountCode, a.AccountName, a.ParentAccountID, a.AccountType, a.AccountLevel, a.IsTransactional},
                        commandType:=CommandType.StoredProcedure)
                End If
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

        ''' <summary>Returns transactional cash/bank accounts (AccountCode LIKE '11%') for payment ComboBox</summary>
        Public Function GetCashAccounts() As List(Of Account)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim sql = "SELECT AccountID, AccountCode, AccountName FROM [Accounting].[ChartOfAccounts] " &
                          "WHERE AccountCode LIKE '11%' AND IsTransactional = 1 ORDER BY AccountCode"
                Return conn.Query(Of Account)(sql).AsList()
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

                    ' 3. Calculate Totals & Ending Balance
                    report.TotalDebit = report.Transactions.Sum(Function(t) t.DebitAmount)
                    report.TotalCredit = report.Transactions.Sum(Function(t) t.CreditAmount)
                    
                    ' Ending Balance = Opening + Total Debit - Total Credit
                    ' (Note: The SQL procedure already calculates running balance per line)
                    report.EndingBalance = report.OpeningBalance + (report.TotalDebit - report.TotalCredit)
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

        Public Function GetPagedJournalHeaders(pageIndex As Integer, pageSize As Integer, ByRef totalCount As Integer) As List(Of JournalHeader)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageIndex", pageIndex)
                p.Add("@PageSize", pageSize)
                p.Add("@TotalCount", dbType:=DbType.Int32, direction:=ParameterDirection.Output)

                Dim list = conn.Query(Of JournalHeader)(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_GETPAGED,
                    p,
                    commandType:=CommandType.StoredProcedure).AsList()

                totalCount = p.Get(Of Integer)("@TotalCount")
                Return list
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
                                         d.Debit.ToString("F3", System.Globalization.CultureInfo.InvariantCulture),
                                         d.Credit.ToString("F3", System.Globalization.CultureInfo.InvariantCulture),
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

        Public Sub UnpostJournalEntry(jid As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_JOURNALENTRY_UNPOST,
                    New With {.JID = jid},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function GetTrialBalance(startDate As Date, endDate As Date, Optional reportLevel As Integer = 0) As TrialBalanceReport
            Dim report As New TrialBalanceReport() With {.StartDate = startDate, .EndDate = endDate}
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim results = conn.Query(Of TrialBalanceItem)(
                    Helpers.StoredProcedures.SP_REPORT_TRIALBALANCE,
                    New With {.StartDate = startDate, .EndDate = endDate, .ReportLevel = reportLevel},
                    commandType:=CommandType.StoredProcedure)
                report.Items = results.ToList()

                ' Calculate totals
                report.TotalOpeningBalance = report.Items.Sum(Function(i) i.OpeningBalance)
                report.TotalPeriodDebit = report.Items.Sum(Function(i) i.PeriodDebit)
                report.TotalPeriodCredit = report.Items.Sum(Function(i) i.PeriodCredit)
                report.TotalEndingBalance = report.Items.Sum(Function(i) i.EndingBalance)
            End Using
            Return report
        End Function

        Public Function GetProfitLoss(startDate As Date, endDate As Date, Optional reportLevel As Integer = 0) As FinancialReport
            Dim report As New FinancialReport() With {
                .Title = "قائمة الأرباح والخسائر",
                .StartDate = startDate,
                .EndDate = endDate
            }
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim results = conn.Query(Of FinancialReportItem)(
                    Helpers.StoredProcedures.SP_REPORT_PROFITLOSS,
                    New With {.StartDate = startDate, .EndDate = endDate, .ReportLevel = reportLevel},
                    commandType:=CommandType.StoredProcedure)
                report.Items = results.ToList()
            End Using
            Return report
        End Function

        Public Function GetBalanceSheet(asOfDate As Date, Optional reportLevel As Integer = 0) As FinancialReport
            Dim report As New FinancialReport() With {
                .Title = "قائمة المركز المالي",
                .EndDate = asOfDate
            }
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim results = conn.Query(Of FinancialReportItem)(
                    Helpers.StoredProcedures.SP_REPORT_BALANCESHEET,
                    New With {.AsOfDate = asOfDate, .ReportLevel = reportLevel},
                    commandType:=CommandType.StoredProcedure)
                report.Items = results.ToList()
            End Using
            Return report
        End Function

        ' =============================================
        ' Year-End Closing
        ' =============================================
        Public Function CloseFiscalYear(closingDate As Date, retainedEarningsAccountID As Integer, userID As Integer) As (ResultID As Integer, EntryNo As Integer, ResultMsg As String)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                ' Ensure QuerySingleOrDefault is from Dapper
                Dim result = conn.QueryFirstOrDefault(
                    Helpers.StoredProcedures.SP_ACCOUNTING_YEARENDCLOSE,
                    New With {
                        .ClosingDate = closingDate,
                        .RetainedEarningsAccountID = retainedEarningsAccountID,
                        .UserID = userID
                    },
                    commandType:=CommandType.StoredProcedure)

                If result IsNot Nothing Then
                    Return (Convert.ToInt32(result.ResultID), Convert.ToInt32(result.EntryNo), Convert.ToString(result.ResultMsg))
                End If

                Return (0, 0, "Failed to close fiscal year")
            End Using
        End Function
    End Class
End Namespace
