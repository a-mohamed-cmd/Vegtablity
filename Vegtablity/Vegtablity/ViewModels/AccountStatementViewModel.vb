Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class AccountStatementViewModel
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

        Private _startDateText As String = New Date(Now.Year, Now.Month, 1).ToString("dd/MM/yyyy")
        Public Property StartDateText As String
            Get
                Return _startDateText
            End Get
            Set(value As String)
                _startDateText = value
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

        Private _endDateText As String = Now.ToString("dd/MM/yyyy")
        Public Property EndDateText As String
            Get
                Return _endDateText
            End Get
            Set(value As String)
                _endDateText = value
                OnPropertyChanged()
            End Set
        End Property

        Private _accounts As ObservableCollection(Of Account)
        
        Private _filteredAccounts As ObservableCollection(Of Account)
        Public Property FilteredAccounts As ObservableCollection(Of Account)
            Get
                Return _filteredAccounts
            End Get
            Set(value As ObservableCollection(Of Account))
                _filteredAccounts = value
                OnPropertyChanged()
            End Set
        End Property

        Public Sub FilterAccounts(searchText As String)
            If String.IsNullOrWhiteSpace(searchText) Then
                FilteredAccounts = Accounts
            Else
                Dim lower = searchText.ToLower()
                FilteredAccounts = New ObservableCollection(Of Account)(
                    Accounts.Where(Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower().Contains(lower)) OrElse 
                                               (a.AccountCode IsNot Nothing AndAlso a.AccountCode.Contains(searchText)))
                )
            End If
        End Sub

        Public Property Accounts As ObservableCollection(Of Account)
            Get
                Return _accounts
            End Get
            Set(value As ObservableCollection(Of Account))
                _accounts = value
                OnPropertyChanged()
            End Set
        End Property

        Private _selectedAccount As Account
        Public Property SelectedAccount As Account
            Get
                Return _selectedAccount
            End Get
            Set(value As Account)
                _selectedAccount = value
                OnPropertyChanged()
            End Set
        End Property

        Private _reportData As AccountStatementReport
        Public Property ReportData As AccountStatementReport
            Get
                Return _reportData
            End Get
            Set(value As AccountStatementReport)
                _reportData = value
                OnPropertyChanged()
            End Set
        End Property

        ' === Commands ===
        Public Property SearchCommand As RelayCommand
        Public Property PrintCommand As RelayCommand
        Public Property ExportCsvCommand As RelayCommand
        Public Property ExportPdfCommand As RelayCommand

        Public Sub New()
            LoadAccounts()
            SearchCommand = New RelayCommand(AddressOf ExecuteSearch, AddressOf CanSearch)
            PrintCommand = New RelayCommand(AddressOf ExecutePrint, AddressOf CanPrint)
            ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv, AddressOf CanPrint)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanPrint)
        End Sub

        Private Sub LoadAccounts()
            Try
                Dim all = _accountingService.GetAllAccounts()
                ' Only show transactional accounts
                Accounts = New ObservableCollection(Of Account)(all.Where(Function(a) a.IsTransactional))
                FilteredAccounts = Accounts
            Catch ex As Exception
                ' Error handling if needed
            End Try
        End Sub

        Private Function CanSearch(obj As Object) As Boolean
            Return SelectedAccount IsNot Nothing
        End Function

        Private Sub ExecuteSearch(obj As Object)
            Try
                ReportData = _accountingService.GetAccountStatement(SelectedAccount.AccountID, StartDate, EndDate)
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Function CanPrint(obj As Object) As Boolean
            Return ReportData IsNot Nothing AndAlso ReportData.Transactions IsNot Nothing AndAlso ReportData.Transactions.Count > 0
        End Function

        Private Sub ExecutePrint(obj As Object)
            ExecuteExportPdf(obj)
        End Sub

        Private Sub ExecuteExportCsv(obj As Object)
            Try
                ReportExporter.ExportToCsv(ReportData, SelectedAccount.AccountName, StartDate, EndDate)
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Try
                ReportExporter.ExportToPdf(ReportData, SelectedAccount.AccountName, StartDate, EndDate)
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

    End Class
End Namespace
