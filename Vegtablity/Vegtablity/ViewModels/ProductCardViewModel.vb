Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports LiveCharts
Imports LiveCharts.Wpf
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class ProductCardViewModel
        Inherits BaseViewModel

        Private ReadOnly _inventoryService As InventoryService
        
        Public Sub New()
            _inventoryService = New InventoryService()
            PagedMovements = New ObservableCollection(Of ProductMovement)()
            
            LoadSummaryCommand     = New RelayCommand(AddressOf ExecuteLoadSummary)
            FilterMovementsCommand = New RelayCommand(AddressOf ExecuteFilterMovements)
            OpenInvoiceCommand     = New RelayCommand(AddressOf ExecuteOpenInvoice)
            NextPageCommand        = New RelayCommand(AddressOf ExecuteNextPage, Function(o) CurrentPage < TotalPages)
            PrevPageCommand        = New RelayCommand(AddressOf ExecutePrevPage, Function(o) CurrentPage > 1)
            ChartPeriodCommand     = New RelayCommand(AddressOf ExecuteChartPeriod)
            
            ChartSeries = New SeriesCollection()
            ChartLabels = New List(Of String)()
            YFormatter = Function(value) value.ToString("N0")
        End Sub

        ' --- Properties ---

        Private _productID As Integer
        Public Property ProductID As Integer
            Get
                Return _productID
            End Get
            Set(value As Integer)
                If _productID <> value Then
                    _productID = value
                    OnPropertyChanged(NameOf(ProductID))
                    ' Auto-load when ID changes
                    ExecuteLoadSummary(Nothing)
                End If
            End Set
        End Property

        Private _productName As String
        Public Property ProductName As String
            Get
                Return _productName
            End Get
            Set(value As String)
                _productName = value
                OnPropertyChanged(NameOf(ProductName))
            End Set
        End Property

        Private _barcode As String
        Public Property Barcode As String
            Get
                Return _barcode
            End Get
            Set(value As String)
                _barcode = value
                OnPropertyChanged(NameOf(Barcode))
            End Set
        End Property

        Private _summary As ProductCardSummary
        Public Property Summary As ProductCardSummary
            Get
                Return _summary
            End Get
            Set(value As ProductCardSummary)
                _summary = value
                OnPropertyChanged(NameOf(Summary))
            End Set
        End Property

        ' ── Server-Side Pagination ────────────────────────────────────────────────
        Private Const _pageSize As Integer = 15

        Private _currentPage As Integer = 1
        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                If value >= 1 AndAlso value <= TotalPages Then
                    _currentPage = value
                    OnPropertyChanged(NameOf(CurrentPage))
                    OnPropertyChanged(NameOf(PageInfo))
                    FetchCurrentPage()
                End If
            End Set
        End Property

        ' TotalCount يأتي من COUNT(*) OVER() في السيرفير
        Private _totalRecords As Integer = 0
        Public Property TotalRecords As Integer
            Get
                Return _totalRecords
            End Get
            Set(value As Integer)
                _totalRecords = value
                OnPropertyChanged(NameOf(TotalRecords))
                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(PageInfo))
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                If _totalRecords = 0 Then Return 1
                Return CInt(Math.Ceiling(_totalRecords / _pageSize))
            End Get
        End Property

        Public ReadOnly Property PageInfo As String
            Get
                Return $"{CurrentPage} / {TotalPages}"
            End Get
        End Property

        Private _pagedMovements As ObservableCollection(Of ProductMovement)
        Public Property PagedMovements As ObservableCollection(Of ProductMovement)
            Get
                Return _pagedMovements
            End Get
            Set(value As ObservableCollection(Of ProductMovement))
                _pagedMovements = value
                OnPropertyChanged(NameOf(PagedMovements))
            End Set
        End Property

        Private _currentFilter As String = "ALL"
        Public Property CurrentFilter As String
            Get
                Return _currentFilter
            End Get
            Set(value As String)
                _currentFilter = value
                OnPropertyChanged(NameOf(CurrentFilter))
            End Set
        End Property

        ' --- Chart Data ---
        Private _chartSeries As SeriesCollection
        Public Property ChartSeries As SeriesCollection
            Get
                Return _chartSeries
            End Get
            Set(value As SeriesCollection)
                _chartSeries = value
                OnPropertyChanged(NameOf(ChartSeries))
            End Set
        End Property

        Private _chartLabels As List(Of String)
        Public Property ChartLabels As List(Of String)
            Get
                Return _chartLabels
            End Get
            Set(value As List(Of String))
                _chartLabels = value
                OnPropertyChanged(NameOf(ChartLabels))
            End Set
        End Property

        Private _yFormatter As Func(Of Double, String)
        Public Property YFormatter As Func(Of Double, String)
            Get
                Return _yFormatter
            End Get
            Set(value As Func(Of Double, String))
                _yFormatter = value
                OnPropertyChanged(NameOf(YFormatter))
            End Set
        End Property


        ' --- Commands ---
        Public Property LoadSummaryCommand As RelayCommand
        Public Property FilterMovementsCommand As RelayCommand
        Public Property OpenInvoiceCommand As RelayCommand
        Public Property NextPageCommand As RelayCommand
        Public Property PrevPageCommand As RelayCommand
        Public Property ChartPeriodCommand As RelayCommand

        ' ── Chart Period ──────────────────────────────────────────────
        Private _chartPeriodMonths As Integer = 12
        Public Property ChartPeriodMonths As Integer
            Get
                Return _chartPeriodMonths
            End Get
            Set(value As Integer)
                _chartPeriodMonths = value
                OnPropertyChanged(NameOf(ChartPeriodMonths))
            End Set
        End Property

        ' --- Callbacks/Events for UI Navigation ---
        ' This action will be set by the View (InventoryPage) to handle closing the overlay and navigating
        Public Property RequestNavigateToInvoiceAction As Action(Of Integer, Integer) ' (InvID, InvType)

        ' --- Methods ---

        Private Sub ExecuteLoadSummary(obj As Object)
            If ProductID = 0 Then Return

            Try
                ' Load Summary
                Summary = _inventoryService.GetProductCardSummary(ProductID)
                
                ' Load Movements (Default ALL)
                ExecuteFilterMovements("ALL")
                
                ' Load Chart Data
                LoadChartData()
            Catch ex As Exception
                MessageBox.Show("خطأ في تحميل بيانات بطاقة الصنف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteFilterMovements(filterTypeObj As Object)
            Dim filter As String = TryCast(filterTypeObj, String)
            If String.IsNullOrEmpty(filter) Then filter = "ALL"
            CurrentFilter = filter
            ' عودة لابداية عند تغيير الفلتر
            _currentPage = 1
            FetchCurrentPage()
        End Sub

        ''' <summary>يجلب صفحة واحدة فقط من قاعدة البيانات</summary>
        Private Sub FetchCurrentPage()
            Try
                Dim list = _inventoryService.GetProductMovements(
                               ProductID, CurrentFilter, _currentPage, _pageSize)

                PagedMovements.Clear()
                For Each item In list
                    PagedMovements.Add(item)
                Next

                ' TotalCount يأتي في كل صف من النتيجة بسبب OVER()
                If list.Count > 0 Then
                    TotalRecords = list(0).TotalCount
                Else
                    TotalRecords = 0
                End If

                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(CurrentPage))
                OnPropertyChanged(NameOf(PageInfo))
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            Catch ex As Exception
                MessageBox.Show("خطأ في تحميل حركة الصنف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteNextPage(obj As Object)
            If CurrentPage < TotalPages Then
                _currentPage += 1
                FetchCurrentPage()
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            End If
        End Sub

        Private Sub ExecutePrevPage(obj As Object)
            If CurrentPage > 1 Then
                _currentPage -= 1
                FetchCurrentPage()
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            End If
        End Sub

        Private Sub ExecuteChartPeriod(obj As Object)
            ' CommandParameter: "1" | "3" | "6" | "12"
            Dim months As Integer = 12
            If obj IsNot Nothing AndAlso Integer.TryParse(obj.ToString(), months) Then
                ChartPeriodMonths = months
                LoadChartData()
            End If
        End Sub

        Private Sub LoadChartData()
            Try
                Dim data = _inventoryService.GetProductChartData(ProductID, ChartPeriodMonths)
                
                ChartSeries.Clear()
                ChartLabels.Clear()

                Dim inValues As New ChartValues(Of Decimal)()
                Dim outValues As New ChartValues(Of Decimal)()
                Dim balanceValues As New ChartValues(Of Decimal)()
                
                Dim currentRunningBalance As Decimal = 0

                For Each point In data
                    ChartLabels.Add(point.MovementDate.ToString("dd/MMM"))
                    inValues.Add(point.DailyInQty)
                    outValues.Add(point.DailyOutQty)
                    
                    currentRunningBalance += point.NetDayMovement
                    balanceValues.Add(currentRunningBalance)
                Next

                ' Add Series
                ChartSeries.Add(New ColumnSeries With {
                    .Title = "وارد",
                    .Values = inValues,
                    .Fill = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(16, 185, 129)) ' Green #10B981
                })

                ChartSeries.Add(New ColumnSeries With {
                    .Title = "صادر",
                    .Values = outValues,
                    .Fill = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(239, 68, 68)) ' Red #EF4444
                })

                ChartSeries.Add(New LineSeries With {
                    .Title = "الرصيد التراكمي",
                    .Values = balanceValues,
                    .Stroke = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(59, 130, 246)), ' Blue #3B82F6
                    .Fill = System.Windows.Media.Brushes.Transparent,
                    .PointGeometrySize = 10,
                    .LineSmoothness = 0.5
                })

            Catch ex As Exception
                ' Silent or log
            End Try
        End Sub

        Private Sub ExecuteOpenInvoice(obj As Object)
            Dim movement As ProductMovement = TryCast(obj, ProductMovement)
            If movement IsNot Nothing AndAlso RequestNavigateToInvoiceAction IsNot Nothing Then
                ' Navigate: pass InvID and 1 for Sales, 2 for Purchase (mapped from string)
                Dim typeCode As Integer = If(movement.InvType = "Sales", 1, 2)
                RequestNavigateToInvoiceAction.Invoke(movement.InvID, typeCode)
            End If
        End Sub

    End Class
End Namespace
