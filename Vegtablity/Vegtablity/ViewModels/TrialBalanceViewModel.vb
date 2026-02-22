Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class TrialBalanceViewModel
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

        Private _reportData As TrialBalanceReport
        Public Property ReportData As TrialBalanceReport
            Get
                Return _reportData
            End Get
            Set(value As TrialBalanceReport)
                _reportData = value
                OnPropertyChanged()
                
                ' Update FilteredItems directly when report data changes
                If value IsNot Nothing Then
                    FilteredItems = New ObservableCollection(Of TrialBalanceItem)(value.Items)
                Else
                    FilteredItems = New ObservableCollection(Of TrialBalanceItem)()
                End If
            End Set
        End Property

        Private _filteredItems As ObservableCollection(Of TrialBalanceItem)
        Public Property FilteredItems As ObservableCollection(Of TrialBalanceItem)
            Get
                Return _filteredItems
            End Get
            Set(value As ObservableCollection(Of TrialBalanceItem))
                _filteredItems = value
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
                ' Set the value and notify the UI without auto-triggering search
                If _selectedLevel <> value Then
                    _selectedLevel = value
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Private _isDetailedReport As Boolean = True
        Public Property IsDetailedReport As Boolean
            Get
                Return _isDetailedReport
            End Get
            Set(value As Boolean)
                _isDetailedReport = value
                OnPropertyChanged()
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
                ReportData = _accountingService.GetTrialBalance(StartDate, EndDate, SelectedLevel)
            Catch ex As Exception
                ' Log error
            End Try
        End Sub



        Private Function CanExport(obj As Object) As Boolean
            Return ReportData IsNot Nothing AndAlso ReportData.Items.Count > 0
        End Function

        Private Sub ExecuteExportCsv(obj As Object)
            Try
                ReportExporter.ExportTrialBalanceToCsv(ReportData, StartDate, EndDate, IsDetailedReport)
            Catch ex As Exception
                ' MessageBox.Show("Error: " & ex.Message)
            End Try
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Try
                ReportExporter.ExportTrialBalanceToPdf(ReportData, StartDate, EndDate, IsDetailedReport)
            Catch ex As Exception
                ' MessageBox.Show("Error: " & ex.Message)
            End Try
        End Sub

    End Class
End Namespace
