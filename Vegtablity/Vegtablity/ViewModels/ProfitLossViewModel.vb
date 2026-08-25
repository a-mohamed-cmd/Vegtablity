Imports System.Collections.ObjectModel
Imports System.Windows.Media
Imports LiveCharts
Imports LiveCharts.Wpf
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class ProfitLossViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New AccountingService()

        ' === Properties ===

        Private _selectedTabIndex As Integer = 0
        Public Property SelectedTabIndex As Integer
            Get
                Return _selectedTabIndex
            End Get
            Set(value As Integer)
                If SetProperty(_selectedTabIndex, value) Then
                    If value = 1 AndAlso (MonthlyReport Is Nothing OrElse MonthlyReport.Months.Count = 0) Then
                        ExecuteSearch(Nothing)
                    End If
                End If
            End Set
        End Property

        Private _startDate As Date = New Date(Now.Year, 1, 1)
        Public Property StartDate As Date
            Get
                Return _startDate
            End Get
            Set(value As Date)
                _startDate = value
                OnPropertyChanged()
                _startDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged(NameOf(StartDateText))
            End Set
        End Property

        Private _startDateText As String = New Date(Now.Year, 1, 1).ToString("dd/MM/yyyy")
        Public Property StartDateText As String
            Get
                Return _startDateText
            End Get
            Set(value As String)
                _startDateText = If(value, "")
                OnPropertyChanged(NameOf(StartDateText))
            End Set
        End Property

        Private _endDate As Date = Now
        Public Property EndDate As Date
            Get
                Return _endDate
            End Get
            Set(value As Date)
                _endDate = value
                OnPropertyChanged()
                _endDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged(NameOf(EndDateText))
            End Set
        End Property

        Private _endDateText As String = Now.ToString("dd/MM/yyyy")
        Public Property EndDateText As String
            Get
                Return _endDateText
            End Get
            Set(value As String)
                _endDateText = If(value, "")
                OnPropertyChanged(NameOf(EndDateText))
            End Set
        End Property

        ' ============================================================
        ' Cumulative Report Properties (التقرير التراكمي)
        ' ============================================================
        Private _revenueItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property RevenueItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _revenueItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _revenueItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalRevenues))
                OnPropertyChanged(NameOf(TotalRevenuesPercentage))
                UpdateNetProfit()
            End Set
        End Property

        Private _expenseItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property ExpenseItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _expenseItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _expenseItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalExpenses))
                OnPropertyChanged(NameOf(TotalExpensesPercentage))
                UpdateNetProfit()
            End Set
        End Property

        Public ReadOnly Property TotalRevenues As Decimal
            Get
                Return If(RevenueItems IsNot Nothing, RevenueItems.Sum(Function(x) x.Balance), 0)
            End Get
        End Property

        Public ReadOnly Property TotalExpenses As Decimal
            Get
                Return If(ExpenseItems IsNot Nothing, ExpenseItems.Sum(Function(x) x.Balance), 0)
            End Get
        End Property

        Public ReadOnly Property TotalRevenuesPercentage As String
            Get
                Return "100.0 %"
            End Get
        End Property

        Public ReadOnly Property TotalExpensesPercentage As String
            Get
                Dim baseSales = Math.Abs(TotalRevenues)
                If baseSales > 0 Then
                    Return ((Math.Abs(TotalExpenses) / baseSales) * 100D).ToString("F1") & " %"
                End If
                Return "0.0 %"
            End Get
        End Property

        Private _netProfit As Decimal
        Public Property NetProfit As Decimal
            Get
                Return _netProfit
            End Get
            Set(value As Decimal)
                _netProfit = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(NetProfitPercentage))
            End Set
        End Property

        Public ReadOnly Property NetProfitPercentage As String
            Get
                Dim baseSales = Math.Abs(TotalRevenues)
                If baseSales > 0 Then
                    Return ((Math.Abs(NetProfit) / baseSales) * 100D).ToString("F1") & " %"
                End If
                Return "0.0 %"
            End Get
        End Property

        Private _netProfitLabel As String = "صافي الربح"
        Public Property NetProfitLabel As String
            Get
                Return _netProfitLabel
            End Get
            Set(value As String)
                _netProfitLabel = value
                OnPropertyChanged()
            End Set
        End Property

        Public Property AvailableLevels As New Dictionary(Of String, Integer) From {
            {"المستوى الرئيسي (0)", 0},
            {"المستوى الفرعي (1)", 1},
            {"مستوى المجموعات (2)", 2}
        }

        Private _selectedLevel As Integer = 0
        Public Property SelectedLevel As Integer
            Get
                Return _selectedLevel
            End Get
            Set(value As Integer)
                If _selectedLevel <> value Then
                    _selectedLevel = value
                    OnPropertyChanged()
                End If
            End Set
        End Property

        ' ============================================================
        ' Monthly Comparative Report Properties (المقارنة الشهرية)
        ' ============================================================
        Private _monthlyReport As MonthlyComparativeReport
        Public Property MonthlyReport As MonthlyComparativeReport
            Get
                Return _monthlyReport
            End Get
            Set(value As MonthlyComparativeReport)
                SetProperty(_monthlyReport, value)
            End Set
        End Property

        Private _monthlyColumns As New ObservableCollection(Of MonthlyPeriodHeader)()
        Public Property MonthlyColumns As ObservableCollection(Of MonthlyPeriodHeader)
            Get
                Return _monthlyColumns
            End Get
            Set(value As ObservableCollection(Of MonthlyPeriodHeader))
                SetProperty(_monthlyColumns, value)
            End Set
        End Property

        Private _monthlyRevenueRows As New ObservableCollection(Of MonthlyComparativeRow)()
        Public Property MonthlyRevenueRows As ObservableCollection(Of MonthlyComparativeRow)
            Get
                Return _monthlyRevenueRows
            End Get
            Set(value As ObservableCollection(Of MonthlyComparativeRow))
                SetProperty(_monthlyRevenueRows, value)
            End Set
        End Property

        Private _monthlyExpenseRows As New ObservableCollection(Of MonthlyComparativeRow)()
        Public Property MonthlyExpenseRows As ObservableCollection(Of MonthlyComparativeRow)
            Get
                Return _monthlyExpenseRows
            End Get
            Set(value As ObservableCollection(Of MonthlyComparativeRow))
                SetProperty(_monthlyExpenseRows, value)
            End Set
        End Property

        Private _monthlyChartSeries As SeriesCollection
        Public Property MonthlyChartSeries As SeriesCollection
            Get
                Return _monthlyChartSeries
            End Get
            Set(value As SeriesCollection)
                SetProperty(_monthlyChartSeries, value)
            End Set
        End Property

        Private _monthlyChartLabels As String()
        Public Property MonthlyChartLabels As String()
            Get
                Return _monthlyChartLabels
            End Get
            Set(value As String())
                SetProperty(_monthlyChartLabels, value)
            End Set
        End Property

        Public ReadOnly Property MonthlyChartFormatter As Func(Of Double, String)
            Get
                Return Function(val) val.ToString("N0")
            End Get
        End Property

        ' === Commands ===
        Public Property SearchCommand As RelayCommand
        Public Property ExportCsvCommand As RelayCommand
        Public Property ExportExcelCommand As RelayCommand
        Public Property ExportPdfCommand As RelayCommand
        Public Property ExportMonthlyPdfCommand As RelayCommand
        Public Property ExportMonthlyExcelCommand As RelayCommand

        Public Sub New()
            SearchCommand = New RelayCommand(AddressOf ExecuteSearch)
            ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv, AddressOf CanExport)
            ExportExcelCommand = New RelayCommand(AddressOf ExecuteExportExcel, AddressOf CanExport)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanExport)
            ExportMonthlyPdfCommand = New RelayCommand(AddressOf ExecuteExportMonthlyPdf, AddressOf CanExportMonthly)
            ExportMonthlyExcelCommand = New RelayCommand(AddressOf ExecuteExportMonthlyExcel, AddressOf CanExportMonthly)
            
            ' Initial load
            ExecuteSearch(Nothing)
        End Sub

        Private Sub ExecuteSearch(obj As Object)
            Try
                ' 1. Load Cumulative Profit Loss
                Dim report = _accountingService.GetProfitLoss(StartDate, EndDate, SelectedLevel)
                
                RevenueItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Revenue")
                )
                ExpenseItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Expenses")
                )

                ' 2. Load Monthly Comparative Profit Loss
                Dim mReport = _accountingService.GetMonthlyComparativeProfitLoss(StartDate, EndDate, SelectedLevel)
                MonthlyReport = mReport
                MonthlyColumns = New ObservableCollection(Of MonthlyPeriodHeader)(mReport.Months)
                MonthlyRevenueRows = New ObservableCollection(Of MonthlyComparativeRow)(mReport.RevenueRows)
                MonthlyExpenseRows = New ObservableCollection(Of MonthlyComparativeRow)(mReport.ExpenseRows)

                ' 3. Build LiveCharts Monthly Series
                BuildMonthlyChart(mReport)

            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Sub BuildMonthlyChart(mReport As MonthlyComparativeReport)
            If mReport Is Nothing OrElse mReport.Months.Count = 0 Then
                MonthlyChartSeries = New SeriesCollection()
                MonthlyChartLabels = Array.Empty(Of String)()
                Return
            End If

            Dim labels = mReport.Months.Select(Function(m) m.MonthName).ToArray()
            MonthlyChartLabels = labels

            Dim revValues As New ChartValues(Of Double)()
            Dim expValues As New ChartValues(Of Double)()
            Dim netValues As New ChartValues(Of Double)()

            For Each m In mReport.Months
                Dim r = If(mReport.MonthlyRevenuesTotal.ContainsKey(m.MonthKey), CDbl(Math.Abs(mReport.MonthlyRevenuesTotal(m.MonthKey))), 0.0)
                Dim e = If(mReport.MonthlyExpensesTotal.ContainsKey(m.MonthKey), CDbl(Math.Abs(mReport.MonthlyExpensesTotal(m.MonthKey))), 0.0)
                Dim n = If(mReport.MonthlyNetProfit.ContainsKey(m.MonthKey), CDbl(Math.Abs(mReport.MonthlyNetProfit(m.MonthKey))), 0.0)

                revValues.Add(r)
                expValues.Add(e)
                netValues.Add(n)
            Next

            MonthlyChartSeries = New SeriesCollection From {
                New ColumnSeries With {
                    .Title = "الإيرادات",
                    .Values = revValues,
                    .Fill = New SolidColorBrush(Color.FromRgb(34, 197, 94)),
                    .DataLabels = True
                },
                New ColumnSeries With {
                    .Title = "المصروفات",
                    .Values = expValues,
                    .Fill = New SolidColorBrush(Color.FromRgb(239, 68, 68)),
                    .DataLabels = True
                },
                New LineSeries With {
                    .Title = "صافي الربح",
                    .Values = netValues,
                    .Stroke = New SolidColorBrush(Color.FromRgb(79, 70, 229)),
                    .Fill = Brushes.Transparent,
                    .PointGeometrySize = 10,
                    .DataLabels = True
                }
            }
        End Sub

        Private Sub UpdateNetProfit()
            NetProfit = TotalRevenues + TotalExpenses

            If NetProfit < 0 Then
                NetProfitLabel = "صافي الربح للفترة"
            Else
                NetProfitLabel = "صافي الخسارة للفترة"
            End If

            OnPropertyChanged(NameOf(TotalExpensesPercentage))
            OnPropertyChanged(NameOf(NetProfitPercentage))
        End Sub

        Private Function CanExport(obj As Object) As Boolean
            Return RevenueItems.Count > 0 OrElse ExpenseItems.Count > 0
        End Function

        Private Function CanExportMonthly(obj As Object) As Boolean
            Return MonthlyReport IsNot Nothing AndAlso MonthlyReport.Months.Count > 0
        End Function

        Private Sub ExecuteExportCsv(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "Profit and Loss",
                .StartDate = StartDate,
                .EndDate = EndDate,
                .Items = RevenueItems.Concat(ExpenseItems).ToList(),
                .TotalBalance = NetProfit
            }
            ReportExporter.ExportFinancialToCsv(report)
        End Sub

        Private Sub ExecuteExportExcel(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "قائمة الأرباح والخسائر",
                .StartDate = StartDate,
                .EndDate = EndDate,
                .Items = RevenueItems.Concat(ExpenseItems).ToList(),
                .TotalBalance = NetProfit
            }
            ReportExporter.ExportProfitLossToExcel(report, StartDate, EndDate)
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "قائمة الأرباح والخسائر",
                .StartDate = StartDate,
                .EndDate = EndDate,
                .Items = RevenueItems.Concat(ExpenseItems).ToList(),
                .TotalBalance = NetProfit
            }
            ReportExporter.ExportProfitLossToPdf(report, StartDate, EndDate)
        End Sub

        Private Sub ExecuteExportMonthlyPdf(obj As Object)
            If MonthlyReport IsNot Nothing Then
                ReportExporter.ExportMonthlyComparativeToPdf(MonthlyReport, StartDate, EndDate)
            End If
        End Sub

        Private Sub ExecuteExportMonthlyExcel(obj As Object)
            If MonthlyReport IsNot Nothing Then
                ReportExporter.ExportMonthlyComparativeToExcel(MonthlyReport, StartDate, EndDate)
            End If
        End Sub
    End Class
End Namespace
