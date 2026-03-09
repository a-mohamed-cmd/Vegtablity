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
            WarehouseStockList = New ObservableCollection(Of WarehouseStock)()
            
            LoadSummaryCommand     = New RelayCommand(AddressOf ExecuteLoadSummary)
            OpenInvoiceCommand = New RelayCommand(AddressOf ExecuteOpenInvoice)
            _SaveEditCommand = New RelayCommand(AddressOf ExecuteSaveEdit)
            _CancelEditCommand = New RelayCommand(AddressOf ExecuteCancelEdit)
            _ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv)
            _ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf)
            LoadMoreCommand = New RelayCommand(AddressOf ExecuteNextPage, Function(o) CurrentPage < TotalPages)
            PrevPageCommand = New RelayCommand(AddressOf ExecutePrevPage, Function(o) CurrentPage > 1)
            FilterMovementsCommand = New RelayCommand(AddressOf ExecuteFilterMovements)
            ChartPeriodCommand = New RelayCommand(AddressOf ExecuteChartPeriod)

            ChartSeries = New SeriesCollection()
            ChartLabels = New List(Of String)()
            YFormatter = Function(value) value.ToString("N0")

            ' Initialize FilterOptions
            FilterOptions = New List(Of String) From {"ALL", "SALES", "PURCHASE", "ADJUSTMENT"}
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

        ' --- Quick Edit Properties ---
        Private _isQuickEditOpen As Boolean
        Public Property IsQuickEditOpen As Boolean
            Get
                Return _isQuickEditOpen
            End Get
            Set(value As Boolean)
                If _isQuickEditOpen <> value Then
                    _isQuickEditOpen = value

                    ' Populate edit fields when opening the panel
                    If _isQuickEditOpen Then
                        EditName = ProductName
                        EditBarcode = Barcode
                        EditPrice = If(Summary IsNot Nothing, Summary.SalePrice, 0)
                    End If

                    OnPropertyChanged(NameOf(IsQuickEditOpen))
                End If
            End Set
        End Property

        Private _editName As String
        Public Property EditName As String
            Get
                Return _editName
            End Get
            Set(value As String)
                _editName = value
                OnPropertyChanged(NameOf(EditName))
            End Set
        End Property

        Private _editBarcode As String
        Public Property EditBarcode As String
            Get
                Return _editBarcode
            End Get
            Set(value As String)
                _editBarcode = value
                OnPropertyChanged(NameOf(EditBarcode))
            End Set
        End Property

        Private _editPrice As Decimal
        Public Property EditPrice As Decimal
            Get
                Return _editPrice
            End Get
            Set(value As Decimal)
                _editPrice = value
                OnPropertyChanged(NameOf(EditPrice))
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

        Private _warehouseStockList As ObservableCollection(Of WarehouseStock)
        Public Property WarehouseStockList As ObservableCollection(Of WarehouseStock)
            Get
                Return _warehouseStockList
            End Get
            Set(value As ObservableCollection(Of WarehouseStock))
                _warehouseStockList = value
                OnPropertyChanged(NameOf(WarehouseStockList))
            End Set
        End Property

        Private _isLowStock As Boolean
        Public Property IsLowStock As Boolean
            Get
                Return _isLowStock
            End Get
            Set(value As Boolean)
                _isLowStock = value
                OnPropertyChanged(NameOf(IsLowStock))
            End Set
        End Property

        Private _stockProgress As Double
        Public Property StockProgress As Double
            Get
                Return _stockProgress
            End Get
            Set(value As Double)
                _stockProgress = value
                OnPropertyChanged(NameOf(StockProgress))
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
        Public Property LoadSummaryCommand As RelayCommand ' Changed type to RelayCommand as per original
        Public Property FilterMovementsCommand As RelayCommand ' Re-added based on context
        Public ReadOnly Property FilterOptions As List(Of String) ' Added FilterOptions

        ' Navigation & Actions
        Public Property OpenInvoiceCommand As ICommand

        Private _SaveEditCommand As ICommand
        Public ReadOnly Property SaveEditCommand As ICommand
            Get
                Return _SaveEditCommand
            End Get
        End Property

        Private _CancelEditCommand As ICommand
        Public ReadOnly Property CancelEditCommand As ICommand
            Get
                Return _CancelEditCommand
            End Get
        End Property

        Private _ExportCsvCommand As ICommand
        Public ReadOnly Property ExportCsvCommand As ICommand
            Get
                Return _ExportCsvCommand
            End Get
        End Property

        Private _ExportPdfCommand As ICommand
        Public ReadOnly Property ExportPdfCommand As ICommand
            Get
                Return _ExportPdfCommand
            End Get
        End Property

        ' Pagination
        Public Property LoadMoreCommand As ICommand ' Renamed from NextPageCommand
        Public Property PrevPageCommand As RelayCommand ' Re-added based on context
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

                ' Calculate stock alerts
                If Summary IsNot Nothing Then
                    IsLowStock = (Summary.Balance <= Summary.AlertQty AndAlso Summary.AlertQty > 0)
                    If Summary.AlertQty > 0 Then
                        ' Avoid exceeding 100% progress for the visual bar
                        StockProgress = Math.Min((Summary.Balance / Summary.AlertQty) * 100, 100)
                    Else
                        StockProgress = 100
                    End If
                End If

                ' Load Warehouse Stock Distribution
                Dim whStock = _inventoryService.GetProductStockByWarehouse(ProductID).ToList()

                For Each wh In whStock
                    If wh.AlertQty > 0 Then
                        wh.IsLowStock = (wh.CurrentQty <= wh.AlertQty)
                    Else
                        wh.IsLowStock = False
                    End If
                Next

                ' Assigning a new instance forces the ItemsControl to completely re-render
                WarehouseStockList = New ObservableCollection(Of WarehouseStock)(whStock)

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

        Private Sub ExecuteCancelEdit(obj As Object)
            IsQuickEditOpen = False
        End Sub

        Private Sub ExecuteSaveEdit(obj As Object)
            Try
                If String.IsNullOrWhiteSpace(EditName) Then
                    MessageBox.Show("الرجاء إدخال اسم الصنف", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If

                _inventoryService.UpdateProductQuickDetails(ProductID, EditName, EditBarcode, EditPrice)

                ' Update UI fields and collapse panel
                ProductName = EditName
                Barcode = EditBarcode
                If Summary IsNot Nothing Then
                    Summary.Barcode = EditBarcode
                End If
                IsQuickEditOpen = False

                MessageBox.Show("تم حفظ التعديلات بنجاح", "نجاح", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ التعديلات: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteExportCsv(obj As Object)
            If PagedMovements IsNot Nothing AndAlso PagedMovements.Count > 0 Then ' Changed Movements to PagedMovements
                Dim prodName = If(Summary IsNot Nothing, _inventoryService.GetProductByID(ProductID)?.ProductName, "UnknownProduct")
                Helpers.ReportExporter.ExportProductMovementsToCsv(PagedMovements.ToList(), prodName) ' Changed Movements to PagedMovements
            End If
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            If PagedMovements IsNot Nothing AndAlso PagedMovements.Count > 0 Then
                Dim prodName = If(Summary IsNot Nothing, _inventoryService.GetProductByID(ProductID)?.ProductName, "UnknownProduct")
                Helpers.ReportExporter.ExportProductMovementsToPdf(PagedMovements.ToList(), prodName, Summary, WarehouseStockList?.ToList())
            End If
        End Sub

#Region "Chart Data Loading"
        Private Sub ExecuteNextPage(obj As Object) ' This is now LoadMoreCommand's execution method
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
#End Region
    End Class
End Namespace
