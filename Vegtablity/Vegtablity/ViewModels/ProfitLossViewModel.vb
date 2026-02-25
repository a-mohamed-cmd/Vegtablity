Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class ProfitLossViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New AccountingService()

        ' === Properties ===

        Private _startDate As Date = New Date(Now.Year, Now.Month, 1)
        Public Property StartDate As Date
            Get
                Return _startDate
            End Get
            Set(value As Date)
                _startDate = value
                OnPropertyChanged()
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
            End Set
        End Property

        Private _revenueItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property RevenueItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _revenueItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _revenueItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalRevenues))
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
                UpdateNetProfit()
            End Set
        End Property

        Public ReadOnly Property TotalRevenues As Decimal
            Get
                Return RevenueItems.Sum(Function(x) x.Balance)
            End Get
        End Property

        Public ReadOnly Property TotalExpenses As Decimal
            Get
                Return ExpenseItems.Sum(Function(x) x.Balance)
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
            End Set
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

        ' === Commands ===
        Public Property SearchCommand As RelayCommand
        Public Property ExportCsvCommand As RelayCommand
        Public Property ExportPdfCommand As RelayCommand

        Public Sub New()
            SearchCommand = New RelayCommand(AddressOf ExecuteSearch)
            ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv, AddressOf CanExport)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanExport)
            
            ' Initial load
            ExecuteSearch(Nothing)
        End Sub

        Private Sub ExecuteSearch(obj As Object)
            Try
                Dim report = _accountingService.GetProfitLoss(StartDate, EndDate, SelectedLevel)
                
                ' Separation Logic
                RevenueItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Revenue")
                )
                ExpenseItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Expenses")
                )
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Sub UpdateNetProfit()
            ' As requested by user: Revenues - Expenses
            ' If result < 0 -> Profit
            ' If result > 0 -> Loss
            NetProfit = TotalRevenues + TotalExpenses

            If NetProfit < 0 Then
                NetProfitLabel = "صافي الربح"
            Else
                NetProfitLabel = "صافي الخسارة"
            End If
        End Sub

        Private Function CanExport(obj As Object) As Boolean
            Return RevenueItems.Count > 0 OrElse ExpenseItems.Count > 0
        End Function

        Private Sub ExecuteExportCsv(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "Profit and Loss",
                .StartDate = StartDate,
                .EndDate = EndDate,
                .Items = RevenueItems.Concat(ExpenseItems).ToList()
            }
            ReportExporter.ExportFinancialToCsv(report)
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "قائمة الأرباح والخسائر",
                .StartDate = StartDate,
                .EndDate = EndDate,
                .Items = RevenueItems.Concat(ExpenseItems).ToList()
            }
            ReportExporter.ExportProfitLossToPdf(report, StartDate, EndDate)
        End Sub
    End Class
End Namespace
