Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class BalanceSheetViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New AccountingService()

        ' === Properties ===

        Private _asOfDate As Date = Now
        Public Property AsOfDate As Date
            Get
                Return _asOfDate
            End Get
            Set(value As Date)
                _asOfDate = value
                OnPropertyChanged()
            End Set
        End Property

        Private _assetItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property AssetItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _assetItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _assetItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalAssets))
            End Set
        End Property

        Private _liabilityItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property LiabilityItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _liabilityItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _liabilityItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalLiabilities))
            End Set
        End Property

        Private _equityItems As New ObservableCollection(Of FinancialReportItem)()
        Public Property EquityItems As ObservableCollection(Of FinancialReportItem)
            Get
                Return _equityItems
            End Get
            Set(value As ObservableCollection(Of FinancialReportItem))
                _equityItems = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalEquity))
            End Set
        End Property

        Public ReadOnly Property TotalAssets As Decimal
            Get
                Return AssetItems.Sum(Function(x) x.Balance)
            End Get
        End Property

        Public ReadOnly Property TotalLiabilities As Decimal
            Get
                Return LiabilityItems.Sum(Function(x) Math.Abs(x.Balance)) ' Liab are credit (-) in DB
            End Get
        End Property

        Public ReadOnly Property TotalEquity As Decimal
            Get
                Return EquityItems.Sum(Function(x) Math.Abs(x.Balance)) ' Equity are credit (-) in DB
            End Get
        End Property

        Public ReadOnly Property TotalLiabilitiesAndEquity As Decimal
            Get
                Return TotalLiabilities + TotalEquity
            End Get
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
                Dim report = _accountingService.GetBalanceSheet(AsOfDate, SelectedLevel)
                
                ' Separation Logic
                AssetItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Assets")
                )
                LiabilityItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Liabilities")
                )
                EquityItems = New ObservableCollection(Of FinancialReportItem)(
                    report.Items.Where(Function(i) i.AccountType = "Equity")
                )
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Function CanExport(obj As Object) As Boolean
            Return AssetItems.Count > 0 OrElse LiabilityItems.Count > 0
        End Function

        Private Sub ExecuteExportCsv(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "Balance Sheet",
                .EndDate = AsOfDate,
                .Items = AssetItems.Concat(LiabilityItems).Concat(EquityItems).ToList()
            }
            ReportExporter.ExportFinancialToCsv(report)
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Dim report As New FinancialReport() With {
                .Title = "قائمة المركز المالي",
                .EndDate = AsOfDate,
                .Items = AssetItems.Concat(LiabilityItems).Concat(EquityItems).ToList()
            }
            ReportExporter.ExportBalanceSheetToPdf(report, AsOfDate)
        End Sub
    End Class
End Namespace
