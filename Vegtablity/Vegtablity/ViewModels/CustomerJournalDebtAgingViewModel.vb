Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Windows
Imports System.Windows.Input
Imports Dapper
Imports Microsoft.Win32
Imports Vegtablity.Helpers
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace Models
    ''' <summary>
    ''' نموذج بيانات تقرير أعمار الديون للعملاء المبني على جدول القيود المحاسبية [Accounting].[JournalEntries]
    ''' يقسم الفواتير (المدين) والسداد (الدائن) لكل عميل حسب الفترات العمرية (0-30، 31-60، 61-90، +90 يوم)
    ''' </summary>
    Public Class ReportCustomerJournalDebtAging
        Public Property RowNumber As Integer
        Public Property IsEvenRow As Boolean

        Public Property PartnerID As Integer
        Public Property PartnerName As String = "عميل غير مسمى"
        Public Property Phone As String = "-"
        Public Property AccountID As Integer
        Public Property AccountCode As String = "-"
        Public Property AccountName As String = "-"

        Public Property OpeningBalance As Decimal

        ' الفترة 1: 0 - 30 يوم
        Public Property Debit_0_30 As Decimal
        Public Property Paid_0_30 As Decimal
        Public Property Count_0_30 As Integer
        Public Property PayCount_0_30 As Integer

        ' الفترة 2: 31 - 60 يوم
        Public Property Debit_31_60 As Decimal
        Public Property Paid_31_60 As Decimal
        Public Property Count_31_60 As Integer
        Public Property PayCount_31_60 As Integer

        ' الفترة 3: 61 - 90 يوم
        Public Property Debit_61_90 As Decimal
        Public Property Paid_61_90 As Decimal
        Public Property Count_61_90 As Integer
        Public Property PayCount_61_90 As Integer

        ' الفترة 4: أكثر من 90 يوم
        Public Property Debit_Over_90 As Decimal
        Public Property Paid_Over_90 As Decimal
        Public Property Count_Over_90 As Integer
        Public Property PayCount_Over_90 As Integer

        ' إجماليات الفترة والرصيد الختامي
        Public Property TotalPeriodDebit As Decimal
        Public Property TotalPeriodCredit As Decimal
        Public Property TotalPeriodInvoicesCount As Integer
        Public Property TotalPeriodPaymentsCount As Integer
        Public Property NetPeriodBalance As Decimal
        Public Property ClosingBalance As Decimal

        Public Property LastInvoiceDate As DateTime?
        Public Property LastPaymentDate As DateTime?

        ' ==========================================================
        ' خصائص محسوبة لصافي كل فترة عمرية (الفواتير - السداد في نفس الفترة)
        ' ==========================================================
        Public ReadOnly Property Net_0_30 As Decimal
            Get
                Return Debit_0_30 - Paid_0_30
            End Get
        End Property

        Public ReadOnly Property Net_31_60 As Decimal
            Get
                Return Debit_31_60 - Paid_31_60
            End Get
        End Property

        Public ReadOnly Property Net_61_90 As Decimal
            Get
                Return Debit_61_90 - Paid_61_90
            End Get
        End Property

        Public ReadOnly Property Net_Over_90 As Decimal
            Get
                Return Debit_Over_90 - Paid_Over_90
            End Get
        End Property

        ' ==========================================================
        ' نصوص منسقة للعرض في الـ UserControl المخصص
        ' ==========================================================
        Public ReadOnly Property OpeningBalanceText As String
            Get
                Return OpeningBalance.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Debit_0_30_Text As String
            Get
                Return Debit_0_30.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Paid_0_30_Text As String
            Get
                Return Paid_0_30.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Net_0_30_Text As String
            Get
                Return Net_0_30.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Meta_0_30_Text As String
            Get
                Return $"فواتير: {Count_0_30} | سداد: {PayCount_0_30}"
            End Get
        End Property

        Public ReadOnly Property Debit_31_60_Text As String
            Get
                Return Debit_31_60.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Paid_31_60_Text As String
            Get
                Return Paid_31_60.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Net_31_60_Text As String
            Get
                Return Net_31_60.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Meta_31_60_Text As String
            Get
                Return $"فواتير: {Count_31_60} | سداد: {PayCount_31_60}"
            End Get
        End Property

        Public ReadOnly Property Debit_61_90_Text As String
            Get
                Return Debit_61_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Paid_61_90_Text As String
            Get
                Return Paid_61_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Net_61_90_Text As String
            Get
                Return Net_61_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Meta_61_90_Text As String
            Get
                Return $"فواتير: {Count_61_90} | سداد: {PayCount_61_90}"
            End Get
        End Property

        Public ReadOnly Property Debit_Over_90_Text As String
            Get
                Return Debit_Over_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Paid_Over_90_Text As String
            Get
                Return Paid_Over_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Net_Over_90_Text As String
            Get
                Return Net_Over_90.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property Meta_Over_90_Text As String
            Get
                Return $"فواتير: {Count_Over_90} | سداد: {PayCount_Over_90}"
            End Get
        End Property

        Public ReadOnly Property TotalPeriodDebitText As String
            Get
                Return TotalPeriodDebit.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalPeriodCreditText As String
            Get
                Return TotalPeriodCredit.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property NetPeriodBalanceText As String
            Get
                Return NetPeriodBalance.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property ClosingBalanceText As String
            Get
                Return ClosingBalance.ToString("N3")
            End Get
        End Property

        Public ReadOnly Property CollectionRatePercent As Decimal
            Get
                Dim totalRequired As Decimal = Math.Max(0D, OpeningBalance) + TotalPeriodDebit
                If totalRequired <= 0D Then
                    Return If(TotalPeriodCredit > 0D OrElse ClosingBalance <= 0D, 100D, 0D)
                End If
                Dim rate As Decimal = (TotalPeriodCredit / totalRequired) * 100D
                If rate < 0D Then rate = 0D
                If rate > 100D Then rate = 100D
                Return Math.Round(rate, 1)
            End Get
        End Property

        Public ReadOnly Property CollectionRateText As String
            Get
                Return $"{CollectionRatePercent:N1}%"
            End Get
        End Property

        Public ReadOnly Property LastInvoiceDateText As String
            Get
                Return If(LastInvoiceDate.HasValue, LastInvoiceDate.Value.ToString("yyyy/MM/dd"), "لا يوجد")
            End Get
        End Property

        Public ReadOnly Property LastPaymentDateText As String
            Get
                Return If(LastPaymentDate.HasValue, LastPaymentDate.Value.ToString("yyyy/MM/dd"), "لا يوجد")
            End Get
        End Property

        Public ReadOnly Property CustomerSubInfoText As String
            Get
                Dim parts As New List(Of String)()
                If Not String.IsNullOrWhiteSpace(Phone) AndAlso Phone <> "-" Then
                    parts.Add($"📞 {Phone}")
                End If
                If Not String.IsNullOrWhiteSpace(AccountCode) AndAlso AccountCode <> "-" Then
                    parts.Add($"حساب: {AccountCode}")
                End If
                parts.Add($"آخر فاتورة: {LastInvoiceDateText}")
                parts.Add($"آخر سداد: {LastPaymentDateText}")
                Return String.Join("  •  ", parts)
            End Get
        End Property

        Public ReadOnly Property AgingStatusBadgeText As String
            Get
                If ClosingBalance <= 0D Then
                    Return "✅ مسدد / لا توجد مديونية"
                ElseIf Net_Over_90 > 0D OrElse (Debit_Over_90 > 0D AndAlso ClosingBalance > 0D) Then
                    Return "🚨 مديونية حرجة (+90 يوم)"
                ElseIf Net_61_90 > 0D OrElse (Debit_61_90 > 0D AndAlso ClosingBalance > 0D) Then
                    Return "⚠️ متأخر (61 - 90 يوم)"
                ElseIf Net_31_60 > 0D OrElse (Debit_31_60 > 0D AndAlso ClosingBalance > 0D) Then
                    Return "⏳ متوسط (31 - 60 يوم)"
                Else
                    Return "🟢 حديث (0 - 30 يوم)"
                End If
            End Get
        End Property

        Public ReadOnly Property AgingStatusFg As String
            Get
                If ClosingBalance <= 0D Then Return "#047857"
                If Net_Over_90 > 0D OrElse Debit_Over_90 > 0D Then Return "#BE123C"
                If Net_61_90 > 0D OrElse Debit_61_90 > 0D Then Return "#C2410C"
                If Net_31_60 > 0D OrElse Debit_31_60 > 0D Then Return "#B45309"
                Return "#1D4ED8"
            End Get
        End Property

        Public ReadOnly Property AgingStatusBg As String
            Get
                If ClosingBalance <= 0D Then Return "#ECFDF5"
                If Net_Over_90 > 0D OrElse Debit_Over_90 > 0D Then Return "#FFF1F2"
                If Net_61_90 > 0D OrElse Debit_61_90 > 0D Then Return "#FFF7ED"
                If Net_31_60 > 0D OrElse Debit_31_60 > 0D Then Return "#FFFBEB"
                Return "#EFF6FF"
            End Get
        End Property

        Public ReadOnly Property AgingStatusBorder As String
            Get
                If ClosingBalance <= 0D Then Return "#A7F3D0"
                If Net_Over_90 > 0D OrElse Debit_Over_90 > 0D Then Return "#FECDD3"
                If Net_61_90 > 0D OrElse Debit_61_90 > 0D Then Return "#FED7AA"
                If Net_31_60 > 0D OrElse Debit_31_60 > 0D Then Return "#FDE68A"
                Return "#BFDBFE"
            End Get
        End Property

        Public ReadOnly Property ClosingBalanceFg As String
            Get
                Return If(ClosingBalance > 0D, "#BE123C", "#047857")
            End Get
        End Property

        Public ReadOnly Property ClosingBalanceBg As String
            Get
                Return If(ClosingBalance > 0D, "#FFF1F2", "#ECFDF5")
            End Get
        End Property

        Public ReadOnly Property ClosingBalanceBorder As String
            Get
                Return If(ClosingBalance > 0D, "#FECDD3", "#A7F3D0")
            End Get
        End Property

        Public ReadOnly Property SearchableText As String
            Get
                Return $"{PartnerID} {PartnerName} {Phone} {AccountCode} {AccountName} {AgingStatusBadgeText}"
            End Get
        End Property
    End Class
End Namespace

Namespace Services
    ''' <summary>
    ''' خدمة جلب بيانات تقرير أعمار الديون للعملاء من جدول القيود المحاسبية [Accounting].[JournalEntries]
    ''' </summary>
    Public Class CustomerJournalDebtAgingService
        Private ReadOnly _dbHelper As New DatabaseHelper()

        Public Function GetCustomerDebtAgingFromJournal(startDate As DateTime,
                                                        endDate As DateTime,
                                                        Optional partnerID As Integer? = Nothing) As List(Of ReportCustomerJournalDebtAging)
            Dim pIdParam As Integer = If(partnerID.HasValue AndAlso partnerID.Value > 0, partnerID.Value, 0)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Try
                        Return conn.Query(Of ReportCustomerJournalDebtAging)(
                            StoredProcedures.SP_REPORT_CUSTOMERDEBTAGING_JOURNAL,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .PartnerID = pIdParam
                            },
                            commandType:=CommandType.StoredProcedure
                        ).AsList()
                    Catch spEx As Exception
                        ' Fallback direct query on [Accounting].[JournalEntries] if SP is not yet created in DB
                        Dim sql As String = "
                        ;WITH CustomerAccounts AS (
                            SELECT
                                p.PartnerID,
                                ISNULL(p.PartnerName, N'عميل غير مسمى') AS PartnerName,
                                ISNULL(NULLIF(LTRIM(RTRIM(p.Phone)), ''), N'-') AS Phone,
                                ISNULL(p.AccountID, 0) AS AccountID,
                                ISNULL(a.AccountCode, N'-') AS AccountCode,
                                ISNULL(a.AccountName, p.PartnerName) AS AccountName
                            FROM [Sales].[Partners] p
                            LEFT JOIN [Accounting].[ChartOfAccounts] a ON p.AccountID = a.AccountID
                            WHERE p.AccountID IS NOT NULL
                              AND (
                                  (@PartnerID > 0 AND p.PartnerID = @PartnerID)
                                  OR
                                  (@PartnerID = 0 AND (
                                      p.PartnerType IN ('Customer', 'Both')
                                      OR p.PartnerType LIKE N'%عميل%'
                                      OR p.PartnerType LIKE N'%زبون%'
                                      OR a.AccountCode LIKE '12%'
                                  ))
                              )
                        ),
                        JournalAgg AS (
                            SELECT
                                ca.PartnerID,
                                ca.PartnerName,
                                ca.Phone,
                                ca.AccountID,
                                ca.AccountCode,
                                ca.AccountName,
                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) < @StartDate
                                    THEN (ISNULL(je.DebitAmount, 0) - ISNULL(je.CreditAmount, 0))
                                    ELSE 0
                                END), 0) AS OpeningBalance,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 0 AND 30
                                    THEN ISNULL(je.DebitAmount, 0)
                                    ELSE 0
                                END), 0) AS Debit_0_30,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 0 AND 30
                                    THEN ISNULL(je.CreditAmount, 0)
                                    ELSE 0
                                END), 0) AS Paid_0_30,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 0 AND 30
                                     AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS Count_0_30,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 0 AND 30
                                     AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS PayCount_0_30,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 31 AND 60
                                    THEN ISNULL(je.DebitAmount, 0)
                                    ELSE 0
                                END), 0) AS Debit_31_60,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 31 AND 60
                                    THEN ISNULL(je.CreditAmount, 0)
                                    ELSE 0
                                END), 0) AS Paid_31_60,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 31 AND 60
                                     AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS Count_31_60,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 31 AND 60
                                     AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS PayCount_31_60,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 61 AND 90
                                    THEN ISNULL(je.DebitAmount, 0)
                                    ELSE 0
                                END), 0) AS Debit_61_90,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 61 AND 90
                                    THEN ISNULL(je.CreditAmount, 0)
                                    ELSE 0
                                END), 0) AS Paid_61_90,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 61 AND 90
                                     AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS Count_61_90,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) BETWEEN 61 AND 90
                                     AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS PayCount_61_90,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) > 90
                                    THEN ISNULL(je.DebitAmount, 0)
                                    ELSE 0
                                END), 0) AS Debit_Over_90,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) > 90
                                    THEN ISNULL(je.CreditAmount, 0)
                                    ELSE 0
                                END), 0) AS Paid_Over_90,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) > 90
                                     AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS Count_Over_90,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND DATEDIFF(DAY, CAST(je.EntryDate AS DATE), @EndDate) > 90
                                     AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS PayCount_Over_90,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                    THEN ISNULL(je.DebitAmount, 0)
                                    ELSE 0
                                END), 0) AS TotalPeriodDebit,

                                ISNULL(SUM(CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                    THEN ISNULL(je.CreditAmount, 0)
                                    ELSE 0
                                END), 0) AS TotalPeriodCredit,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS TotalPeriodInvoicesCount,

                                COUNT(DISTINCT CASE
                                    WHEN CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
                                     AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryID
                                END) AS TotalPeriodPaymentsCount,

                                MAX(CASE
                                    WHEN CAST(je.EntryDate AS DATE) <= @EndDate AND ISNULL(je.DebitAmount, 0) > 0
                                    THEN je.EntryDate
                                END) AS LastInvoiceDate,

                                MAX(CASE
                                    WHEN CAST(je.EntryDate AS DATE) <= @EndDate AND ISNULL(je.CreditAmount, 0) > 0
                                    THEN je.EntryDate
                                END) AS LastPaymentDate

                            FROM CustomerAccounts ca
                            LEFT JOIN [Accounting].[JournalEntries] je
                                ON je.AccountID = ca.AccountID
                               AND CAST(je.EntryDate AS DATE) <= @EndDate
                            GROUP BY
                                ca.PartnerID,
                                ca.PartnerName,
                                ca.Phone,
                                ca.AccountID,
                                ca.AccountCode,
                                ca.AccountName
                        )
                        SELECT
                            PartnerID,
                            PartnerName,
                            Phone,
                            AccountID,
                            AccountCode,
                            AccountName,
                            CAST(ROUND(OpeningBalance, 3, 1) AS DECIMAL(18, 3)) AS OpeningBalance,
                            CAST(ROUND(Debit_0_30, 3, 1) AS DECIMAL(18, 3)) AS Debit_0_30,
                            CAST(ROUND(Paid_0_30, 3, 1) AS DECIMAL(18, 3)) AS Paid_0_30,
                            Count_0_30,
                            PayCount_0_30,
                            CAST(ROUND(Debit_31_60, 3, 1) AS DECIMAL(18, 3)) AS Debit_31_60,
                            CAST(ROUND(Paid_31_60, 3, 1) AS DECIMAL(18, 3)) AS Paid_31_60,
                            Count_31_60,
                            PayCount_31_60,
                            CAST(ROUND(Debit_61_90, 3, 1) AS DECIMAL(18, 3)) AS Debit_61_90,
                            CAST(ROUND(Paid_61_90, 3, 1) AS DECIMAL(18, 3)) AS Paid_61_90,
                            Count_61_90,
                            PayCount_61_90,
                            CAST(ROUND(Debit_Over_90, 3, 1) AS DECIMAL(18, 3)) AS Debit_Over_90,
                            CAST(ROUND(Paid_Over_90, 3, 1) AS DECIMAL(18, 3)) AS Paid_Over_90,
                            Count_Over_90,
                            PayCount_Over_90,
                            CAST(ROUND(TotalPeriodDebit, 3, 1) AS DECIMAL(18, 3)) AS TotalPeriodDebit,
                            CAST(ROUND(TotalPeriodCredit, 3, 1) AS DECIMAL(18, 3)) AS TotalPeriodCredit,
                            TotalPeriodInvoicesCount,
                            TotalPeriodPaymentsCount,
                            CAST(ROUND((TotalPeriodDebit - TotalPeriodCredit), 3, 1) AS DECIMAL(18, 3)) AS NetPeriodBalance,
                            CAST(ROUND((OpeningBalance + TotalPeriodDebit - TotalPeriodCredit), 3, 1) AS DECIMAL(18, 3)) AS ClosingBalance,
                            LastInvoiceDate,
                            LastPaymentDate
                        FROM JournalAgg
                        WHERE @PartnerID > 0
                           OR TotalPeriodDebit > 0
                           OR TotalPeriodCredit > 0
                           OR OpeningBalance <> 0
                           OR (OpeningBalance + TotalPeriodDebit - TotalPeriodCredit) <> 0
                        ORDER BY
                            (OpeningBalance + TotalPeriodDebit - TotalPeriodCredit) DESC,
                            TotalPeriodDebit DESC,
                            PartnerName ASC;"

                        Return conn.Query(Of ReportCustomerJournalDebtAging)(
                            sql,
                            New With {
                                .StartDate = startDate.Date,
                                .EndDate = endDate.Date,
                                .PartnerID = pIdParam
                            }
                        ).AsList()
                    End Try
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ أثناء تحميل تقرير أعمار ديون العملاء من القيود المحاسبية: " & ex.Message, ex)
            End Try
        End Function
    End Class
End Namespace

Namespace ViewModels
    ''' <summary>
    ''' ViewModel مستقل (MVVM) لإدارة تقرير أعمار الديون للعملاء من واقع جدول القيود [Accounting].[JournalEntries]
    ''' يدعم الفلترة حسب العميل، الفترة الزمنية، فئة المدة العمرية، البحث الفوري، التصفح (Pagination)، والتصدير إلى PDF و Excel
    ''' </summary>
    Public Class CustomerJournalDebtAgingViewModel
        Inherits BaseViewModel

        Private ReadOnly _service As New CustomerJournalDebtAgingService()
        Private ReadOnly _allItems As New List(Of ReportCustomerJournalDebtAging)()
        Private _filteredItems As New List(Of ReportCustomerJournalDebtAging)()
        Private ReadOnly PAGE_SIZE As Integer = 15
        Private _currentPage As Integer = 0
        Private _quickSearchText As String = ""
        Private _selectedBucketFilter As String = "All"

        Public Event FiltersChanged As EventHandler

        Public Sub New()
            PagedCustomers = New ObservableCollection(Of ReportCustomerJournalDebtAging)()

            NextPageCommand = New RelayCommand(Sub() CurrentPage += 1, Function() CanGoNextPage)
            PrevPageCommand = New RelayCommand(Sub() CurrentPage -= 1, Function() CanGoPrevPage)

            SetBucketFilterCommand = New RelayCommand(Sub(param)
                                                          Dim bucket As String = If(param?.ToString(), "All")
                                                          SelectedBucketFilter = bucket
                                                      End Sub)

            ExportSingleCustomerPdfCommand = New RelayCommand(Sub(param)
                                                                  Dim item = TryCast(param, ReportCustomerJournalDebtAging)
                                                                  If item IsNot Nothing Then
                                                                      ExportSingleCustomerToPdf(item)
                                                                  End If
                                                              End Sub)

            ExportSingleCustomerExcelCommand = New RelayCommand(Sub(param)
                                                                    Dim item = TryCast(param, ReportCustomerJournalDebtAging)
                                                                    If item IsNot Nothing Then
                                                                        ExportSingleCustomerToExcel(item)
                                                                    End If
                                                                End Sub)
        End Sub

        ' ==========================================================
        ' Collections & Properties Bound to JournalDebtAgingControl
        ' ==========================================================
        Private _pagedCustomers As ObservableCollection(Of ReportCustomerJournalDebtAging)
        Public Property PagedCustomers As ObservableCollection(Of ReportCustomerJournalDebtAging)
            Get
                Return _pagedCustomers
            End Get
            Set(value As ObservableCollection(Of ReportCustomerJournalDebtAging))
                SetProperty(_pagedCustomers, value)
            End Set
        End Property

        Public ReadOnly Property AllFilteredCustomers As List(Of ReportCustomerJournalDebtAging)
            Get
                Return _filteredItems
            End Get
        End Property

        Public ReadOnly Property HasCustomerRows As Boolean
            Get
                Return _filteredItems IsNot Nothing AndAlso _filteredItems.Count > 0
            End Get
        End Property

        Public Property SelectedBucketFilter As String
            Get
                Return _selectedBucketFilter
            End Get
            Set(value As String)
                If SetProperty(_selectedBucketFilter, value) Then
                    _currentPage = 0
                    OnPropertyChanged(NameOf(CurrentPage))
                    OnPropertyChanged(NameOf(IsBucketAll))
                    OnPropertyChanged(NameOf(IsBucket0To30))
                    OnPropertyChanged(NameOf(IsBucket31To60))
                    OnPropertyChanged(NameOf(IsBucket61To90))
                    OnPropertyChanged(NameOf(IsBucketOver90))
                    OnPropertyChanged(NameOf(IsBucketActiveDebt))
                    ApplyFiltersAndPaginate()
                    RaiseEvent FiltersChanged(Me, EventArgs.Empty)
                End If
            End Set
        End Property

        Public ReadOnly Property IsBucketAll As Boolean
            Get
                Return _selectedBucketFilter = "All"
            End Get
        End Property

        Public ReadOnly Property IsBucket0To30 As Boolean
            Get
                Return _selectedBucketFilter = "0_30"
            End Get
        End Property

        Public ReadOnly Property IsBucket31To60 As Boolean
            Get
                Return _selectedBucketFilter = "31_60"
            End Get
        End Property

        Public ReadOnly Property IsBucket61To90 As Boolean
            Get
                Return _selectedBucketFilter = "61_90"
            End Get
        End Property

        Public ReadOnly Property IsBucketOver90 As Boolean
            Get
                Return _selectedBucketFilter = "Over_90"
            End Get
        End Property

        Public ReadOnly Property IsBucketActiveDebt As Boolean
            Get
                Return _selectedBucketFilter = "ActiveDebt"
            End Get
        End Property

        ' إجماليات الفترات العمرية الأربع (لعرضها في شريط ملخص الفترات داخل الـ UserControl)
        Public ReadOnly Property TotalBucket_0_30_Debit As String
            Get
                Return _filteredItems.Sum(Function(x) x.Debit_0_30).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_0_30_Paid As String
            Get
                Return _filteredItems.Sum(Function(x) x.Paid_0_30).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_31_60_Debit As String
            Get
                Return _filteredItems.Sum(Function(x) x.Debit_31_60).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_31_60_Paid As String
            Get
                Return _filteredItems.Sum(Function(x) x.Paid_31_60).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_61_90_Debit As String
            Get
                Return _filteredItems.Sum(Function(x) x.Debit_61_90).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_61_90_Paid As String
            Get
                Return _filteredItems.Sum(Function(x) x.Paid_61_90).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_Over_90_Debit As String
            Get
                Return _filteredItems.Sum(Function(x) x.Debit_Over_90).ToString("N3")
            End Get
        End Property

        Public ReadOnly Property TotalBucket_Over_90_Paid As String
            Get
                Return _filteredItems.Sum(Function(x) x.Paid_Over_90).ToString("N3")
            End Get
        End Property

        ' ==========================================================
        ' Pagination Properties & Commands
        ' ==========================================================
        Public Property NextPageCommand As ICommand
        Public Property PrevPageCommand As ICommand
        Public Property SetBucketFilterCommand As ICommand
        Public Property ExportSingleCustomerPdfCommand As ICommand
        Public Property ExportSingleCustomerExcelCommand As ICommand

        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                If value < 0 Then value = 0
                Dim maxP = Math.Max(0, TotalPages - 1)
                If value > maxP Then value = maxP
                If SetProperty(_currentPage, value) Then
                    UpdatePaginationSlice()
                End If
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                Dim cnt = If(_filteredItems IsNot Nothing, _filteredItems.Count, 0)
                Return Math.Max(1, CInt(Math.Ceiling(cnt / CDbl(PAGE_SIZE))))
            End Get
        End Property

        Public ReadOnly Property PageLabel As String
            Get
                Dim cnt = If(_filteredItems IsNot Nothing, _filteredItems.Count, 0)
                Return $"صفحة {CurrentPage + 1} من {TotalPages} ({cnt} عميل)"
            End Get
        End Property

        Public ReadOnly Property CanGoNextPage As Boolean
            Get
                Return CurrentPage < TotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevPage As Boolean
            Get
                Return CurrentPage > 0
            End Get
        End Property

        ' ==========================================================
        ' Core Data Loading & Filtering
        ' ==========================================================
        Public Sub LoadReport(startDate As DateTime, endDate As DateTime, Optional partnerID As Integer? = Nothing, Optional quickSearch As String = "")
            _allItems.Clear()
            _currentPage = 0
            _quickSearchText = If(quickSearch, "")

            Dim data = _service.GetCustomerDebtAgingFromJournal(startDate, endDate, partnerID)
            If data IsNot Nothing Then
                _allItems.AddRange(data)
            End If

            ApplyFiltersAndPaginate()
        End Sub

        Public Sub ApplyQuickSearch(quickSearch As String)
            _quickSearchText = If(quickSearch, "")
            _currentPage = 0
            ApplyFiltersAndPaginate()
        End Sub

        Private Sub ApplyFiltersAndPaginate()
            Dim query As IEnumerable(Of ReportCustomerJournalDebtAging) = _allItems

            ' 1. فلتر المدة العمرية (Duration Bucket Filter)
            Select Case _selectedBucketFilter
                Case "0_30"
                    query = query.Where(Function(x) x.Debit_0_30 > 0D OrElse x.Paid_0_30 > 0D)
                Case "31_60"
                    query = query.Where(Function(x) x.Debit_31_60 > 0D OrElse x.Paid_31_60 > 0D)
                Case "61_90"
                    query = query.Where(Function(x) x.Debit_61_90 > 0D OrElse x.Paid_61_90 > 0D)
                Case "Over_90"
                    query = query.Where(Function(x) x.Debit_Over_90 > 0D OrElse x.Paid_Over_90 > 0D)
                Case "ActiveDebt"
                    query = query.Where(Function(x) x.ClosingBalance > 0D)
            End Select

            ' 2. البحث الفوري النصي
            If Not String.IsNullOrWhiteSpace(_quickSearchText) Then
                Dim q As String = _quickSearchText.Trim().ToLowerInvariant()
                query = query.Where(Function(x) x.SearchableText IsNot Nothing AndAlso x.SearchableText.ToLowerInvariant().Contains(q))
            End If

            _filteredItems = query.ToList()

            ' إعادة ترقيم السجلات المفلترة
            For i As Integer = 0 To _filteredItems.Count - 1
                _filteredItems(i).RowNumber = i + 1
                _filteredItems(i).IsEvenRow = ((i + 1) Mod 2 = 0)
            Next

            OnPropertyChanged(NameOf(TotalBucket_0_30_Debit))
            OnPropertyChanged(NameOf(TotalBucket_0_30_Paid))
            OnPropertyChanged(NameOf(TotalBucket_31_60_Debit))
            OnPropertyChanged(NameOf(TotalBucket_31_60_Paid))
            OnPropertyChanged(NameOf(TotalBucket_61_90_Debit))
            OnPropertyChanged(NameOf(TotalBucket_61_90_Paid))
            OnPropertyChanged(NameOf(TotalBucket_Over_90_Debit))
            OnPropertyChanged(NameOf(TotalBucket_Over_90_Paid))

            UpdatePaginationSlice()
        End Sub

        Private Sub UpdatePaginationSlice()
            Dim skipCount As Integer = _currentPage * PAGE_SIZE
            Dim pageSlice = _filteredItems.Skip(skipCount).Take(PAGE_SIZE).ToList()

            PagedCustomers.Clear()
            For Each item In pageSlice
                PagedCustomers.Add(item)
            Next

            OnPropertyChanged(NameOf(HasCustomerRows))
            OnPropertyChanged(NameOf(TotalPages))
            OnPropertyChanged(NameOf(PageLabel))
            OnPropertyChanged(NameOf(CanGoNextPage))
            OnPropertyChanged(NameOf(CanGoPrevPage))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        ' ==========================================================
        ' Summary Metrics Builder (لشريط الإجماليات العلوي في صفحة التقارير)
        ' ==========================================================
        Public Function BuildSummaryMetrics() As List(Of ReportSummaryMetric)
            Dim metrics As New List(Of ReportSummaryMetric)()
            Dim list = If(_filteredItems, New List(Of ReportCustomerJournalDebtAging)())

            Dim totalOpening As Decimal = list.Sum(Function(x) x.OpeningBalance)
            Dim totalDebit As Decimal = list.Sum(Function(x) x.TotalPeriodDebit)
            Dim totalCredit As Decimal = list.Sum(Function(x) x.TotalPeriodCredit)
            Dim totalClosing As Decimal = list.Sum(Function(x) x.ClosingBalance)
            Dim totalInvCount As Integer = list.Sum(Function(x) x.TotalPeriodInvoicesCount)
            Dim totalPayCount As Integer = list.Sum(Function(x) x.TotalPeriodPaymentsCount)

            metrics.Add(New ReportSummaryMetric() With {
                .Title = "عدد العملاء بالتقرير",
                .ValueText = $"{list.Count:N0} عميل",
                .SubText = $"رصيد سابق قبل الفترة: {totalOpening:N3}",
                .Icon = "👥",
                .AccentColor = "#2563EB",
                .BgColor = "#EFF6FF",
                .BorderColor = "#BFDBFE"
            })

            metrics.Add(New ReportSummaryMetric() With {
                .Title = "إجمالي الفواتير (مدين بالقيود)",
                .ValueText = $"{totalDebit:N3}",
                .SubText = $"عدد قيود المديونية: {totalInvCount:N0} قيد/فاتورة",
                .Icon = "🧾",
                .AccentColor = "#0284C7",
                .BgColor = "#F0F9FF",
                .BorderColor = "#BAE6FD"
            })

            metrics.Add(New ReportSummaryMetric() With {
                .Title = "إجمالي السداد في نفس الفترة",
                .ValueText = $"{totalCredit:N3}",
                .SubText = $"عدد قيود/سندات السداد: {totalPayCount:N0} عملية",
                .Icon = "✅",
                .AccentColor = "#10B981",
                .BgColor = "#ECFDF5",
                .BorderColor = "#A7F3D0"
            })

            metrics.Add(New ReportSummaryMetric() With {
                .Title = "صافي المديونية المتبقية",
                .ValueText = $"{totalClosing:N3}",
                .SubText = If(totalDebit > 0D, $"نسبة سداد الفترة: {Math.Min(100D, (totalCredit / totalDebit) * 100D):N1}%", "الرصيد الختامي بالقيود"),
                .Icon = "⏳",
                .AccentColor = "#E11D48",
                .BgColor = "#FFF1F2",
                .BorderColor = "#FECDD3"
            })

            Return metrics
        End Function

        ' ==========================================================
        ' Export Helpers (PDF & Excel/CSV) for All or Single Customer
        ' ==========================================================
        Public Function BuildExportHeaders() As List(Of ReportColumnHeader)
            Return New List(Of ReportColumnHeader)() From {
                New ReportColumnHeader() With {.Title = "اسم العميل", .WidthWeight = 1.8},
                New ReportColumnHeader() With {.Title = "الهاتف", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "رصيد سابق", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "فواتير 0-30", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "سداد 0-30", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "فواتير 31-60", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "سداد 31-60", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "فواتير 61-90", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "سداد 61-90", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "فواتير +90", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "سداد +90", .WidthWeight = 1.0},
                New ReportColumnHeader() With {.Title = "إجمالي الفواتير", .WidthWeight = 1.1, .IsHighlight = True, .AccentColor = "#2563EB"},
                New ReportColumnHeader() With {.Title = "إجمالي السداد", .WidthWeight = 1.1, .IsHighlight = True, .AccentColor = "#10B981"},
                New ReportColumnHeader() With {.Title = "صافي المديونية", .WidthWeight = 1.2, .IsHighlight = True, .AccentColor = "#E11D48"}
            }
        End Function

        Public Function BuildExportRows(Optional sourceList As IEnumerable(Of ReportCustomerJournalDebtAging) = Nothing) As List(Of ReportRowItem)
            Dim items = If(sourceList, _filteredItems).ToList()
            Dim rows As New List(Of ReportRowItem)()
            Dim idx As Integer = 1

            For Each item In items
                Dim r As New ReportRowItem() With {
                    .RowNumber = idx,
                    .IsEvenRow = (idx Mod 2 = 0),
                    .RawItem = item,
                    .SearchableText = item.SearchableText
                }
                r.Cells.Add(New ReportCellInfo() With {.Text = item.PartnerName, .WidthWeight = 1.8, .IsBold = True})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Phone, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.OpeningBalanceText, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Debit_0_30_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Paid_0_30_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Debit_31_60_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Paid_31_60_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Debit_61_90_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Paid_61_90_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Debit_Over_90_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.Paid_Over_90_Text, .WidthWeight = 1.0})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.TotalPeriodDebitText, .WidthWeight = 1.1, .IsBold = True})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.TotalPeriodCreditText, .WidthWeight = 1.1, .IsBold = True})
                r.Cells.Add(New ReportCellInfo() With {.Text = item.ClosingBalanceText, .WidthWeight = 1.2, .IsBold = True})
                rows.Add(r)
                idx += 1
            Next

            Return rows
        End Function

        Public Sub ExportToPdf(reportTitle As String, Optional summaryMetrics As IList(Of ReportSummaryMetric) = Nothing)
            Dim headers = BuildExportHeaders()
            Dim rows = BuildExportRows(_filteredItems)
            Dim metrics = If(summaryMetrics, BuildSummaryMetrics())
            ReportExporter.ExportReportRowsToPdf(reportTitle, headers, rows, metrics)
        End Sub

        Public Sub ExportSingleCustomerToPdf(customer As ReportCustomerJournalDebtAging)
            If customer Is Nothing Then Return
            Dim singleList As New List(Of ReportCustomerJournalDebtAging) From {customer}
            Dim headers = BuildExportHeaders()
            Dim rows = BuildExportRows(singleList)
            Dim singleMetrics As New List(Of ReportSummaryMetric) From {
                New ReportSummaryMetric() With {.Title = "العميل", .ValueText = customer.PartnerName},
                New ReportSummaryMetric() With {.Title = "رصيد سابق", .ValueText = customer.OpeningBalanceText},
                New ReportSummaryMetric() With {.Title = "إجمالي الفواتير", .ValueText = customer.TotalPeriodDebitText},
                New ReportSummaryMetric() With {.Title = "إجمالي السداد", .ValueText = customer.TotalPeriodCreditText},
                New ReportSummaryMetric() With {.Title = "صافي المديونية", .ValueText = customer.ClosingBalanceText}
            }
            ReportExporter.ExportReportRowsToPdf($"أعمار الديون بالقيود - {customer.PartnerName}", headers, rows, singleMetrics)
        End Sub

        Public Sub ExportToExcel(reportTitle As String, Optional summaryMetrics As IList(Of ReportSummaryMetric) = Nothing)
            Dim headers = BuildExportHeaders()
            Dim rows = BuildExportRows(_filteredItems)
            Dim metrics = If(summaryMetrics, BuildSummaryMetrics())
            ReportExporter.ExportReportRowsToCsv(reportTitle, headers, rows, metrics)
        End Sub

        Public Sub ExportSingleCustomerToExcel(customer As ReportCustomerJournalDebtAging)
            If customer Is Nothing Then Return
            Dim singleList As New List(Of ReportCustomerJournalDebtAging) From {customer}
            Dim headers = BuildExportHeaders()
            Dim rows = BuildExportRows(singleList)
            Dim singleMetrics As New List(Of ReportSummaryMetric) From {
                New ReportSummaryMetric() With {.Title = "العميل", .ValueText = customer.PartnerName},
                New ReportSummaryMetric() With {.Title = "رصيد سابق", .ValueText = customer.OpeningBalanceText},
                New ReportSummaryMetric() With {.Title = "إجمالي الفواتير", .ValueText = customer.TotalPeriodDebitText},
                New ReportSummaryMetric() With {.Title = "إجمالي السداد", .ValueText = customer.TotalPeriodCreditText},
                New ReportSummaryMetric() With {.Title = "صافي المديونية", .ValueText = customer.ClosingBalanceText}
            }
            ReportExporter.ExportReportRowsToCsv($"أعمار الديون بالقيود - {customer.PartnerName}", headers, rows, singleMetrics)
        End Sub

    End Class
End Namespace

