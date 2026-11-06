Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers
Imports System.Windows

Namespace ViewModels
    Public Class ReportsViewModel
        Inherits BaseViewModel

        Private ReadOnly _reportService As New ReportService()
        Private ReadOnly _warehouseService As New WarehouseService()
        Private ReadOnly _productService As New ProductService()
        Private ReadOnly _partnerService As New PartnerService()

        Private ReadOnly _allWarehouses As New List(Of Warehouse)()
        Private ReadOnly _allProducts As New List(Of Product)()
        Private ReadOnly _allPartners As New List(Of Partner)()

        Public Sub New()
            ' Default Dates to current month
            SelectedStartDate = New DateTime(DateTime.Now.Year, DateTime.Now.Month, 1)
            SelectedEndDate = DateTime.Now

            ' Initialize Collections
            ProductProfits = New ObservableCollection(Of ReportProductProfit)()
            InvoiceProfits = New ObservableCollection(Of ReportInvoiceProfit)()
            SalesSummary = New ObservableCollection(Of ReportSalesSummary)()
            TopCustomers = New ObservableCollection(Of ReportTopCustomer)()
            UnpaidInvoices = New ObservableCollection(Of ReportUnpaidInvoice)()
            InventoryValuation = New ObservableCollection(Of ReportInventoryValuation)()
            SlowMovingStock = New ObservableCollection(Of ReportSlowMovingStock)()
            StockMovement = New ObservableCollection(Of ReportStockMovement)()
            ExpenseAnalysis = New ObservableCollection(Of ReportExpenseAnalysis)()
            QuotationStatus = New ObservableCollection(Of ReportQuotationStatus)()

            ' Customer & Wastage & Warehouse & Purchase Reports
            CustomerSalesSummary = New ObservableCollection(Of ReportCustomerSalesSummary)()
            CustomerInvoicesDetail = New ObservableCollection(Of ReportCustomerInvoiceDetail)()
            CustomerProductSales = New ObservableCollection(Of ReportCustomerProductSale)()
            WastageReport = New ObservableCollection(Of ReportWastageItem)()
            WarehouseSales = New ObservableCollection(Of ReportWarehouseSales)()
            PurchaseInvoicesReport = New ObservableCollection(Of ReportPurchaseInvoice)()

            ' Unified Summary Bar & Custom UserControl Row Collections
            SummaryMetrics = New ObservableCollection(Of ReportSummaryMetric)()
            CurrentReportHeaders = New ObservableCollection(Of ReportColumnHeader)()
            CurrentReportRows = New ObservableCollection(Of ReportRowItem)()

            NextReportPageCommand = New RelayCommand(Sub() ReportPage += 1, Function() CanGoNextReport)
            PrevReportPageCommand = New RelayCommand(Sub() ReportPage -= 1, Function() CanGoPrevReport)

            SetTodayRangeCommand = New RelayCommand(Sub() SetQuickDateRange("Today"))
            SetWeekRangeCommand = New RelayCommand(Sub() SetQuickDateRange("Week"))
            SetMonthRangeCommand = New RelayCommand(Sub() SetQuickDateRange("Month"))
            SetYearRangeCommand = New RelayCommand(Sub() SetQuickDateRange("Year"))
            ClearQuickSearchCommand = New RelayCommand(Sub() ReportQuickSearch = "")

            ' Filter options
            Dim warehouseList = _warehouseService.GetAllWarehouses()
            _allWarehouses.Clear()
            _allWarehouses.Add(New Warehouse() With {.WarehouseID = 0, .WarehouseName = "الكل (جميع الفروع والمخازن)"})
            If warehouseList IsNot Nothing Then
                For Each w In warehouseList
                    _allWarehouses.Add(w)
                Next
            End If
            Warehouses = New ObservableCollection(Of Warehouse)(_allWarehouses)

            SelectedWarehouseID = 0
            Dim productList = _productService.GetAllProducts()
            _allProducts.Clear()
            If productList IsNot Nothing Then
                _allProducts.AddRange(productList)
            End If
            Products = New ObservableCollection(Of Product)(_allProducts)

            ' Load Partners (Customers & Suppliers) for Filters
            Dim customerList = _partnerService.GetAllPartners("All")
            _allPartners.Clear()
            _allPartners.Add(New Partner() With {.PartnerID = 0, .PartnerName = "الكل (جميع العملاء والموردين)"})
            If customerList IsNot Nothing Then
                For Each c In customerList
                    _allPartners.Add(c)
                Next
            End If
            Partners = New ObservableCollection(Of Partner)(_allPartners)
            SelectedPartnerID = 0

            ' By default, select the first report tab
            SelectedReportTab = 0

            ' Load data for the initial tab
            ExecuteLoadReport(Nothing)
        End Sub

        ' =======================================================
        ' Quick Date Presets & Search Commands
        ' =======================================================
        Public Property SetTodayRangeCommand As ICommand
        Public Property SetWeekRangeCommand As ICommand
        Public Property SetMonthRangeCommand As ICommand
        Public Property SetYearRangeCommand As ICommand
        Public Property ClearQuickSearchCommand As ICommand

        Private Sub SetQuickDateRange(mode As String)
            Dim today As DateTime = DateTime.Now.Date
            Select Case mode
                Case "Today"
                    SelectedStartDate = today
                    SelectedEndDate = today
                Case "Week"
                    SelectedStartDate = today.AddDays(-6)
                    SelectedEndDate = today
                Case "Month"
                    SelectedStartDate = New DateTime(today.Year, today.Month, 1)
                    SelectedEndDate = today
                Case "Year"
                    SelectedStartDate = New DateTime(today.Year, 1, 1)
                    SelectedEndDate = today
            End Select
            SelectedStartDateText = SelectedStartDate.ToString("dd/MM/yyyy")
            SelectedEndDateText = SelectedEndDate.ToString("dd/MM/yyyy")
            ExecuteLoadReport(Nothing)
        End Sub

        ' =======================================================
        ' Global Filters mapped to UI
        ' =======================================================
        Private _selectedStartDate As DateTime
        Public Property SelectedStartDate As DateTime
            Get
                Return _selectedStartDate
            End Get
            Set(value As DateTime)
                SetProperty(_selectedStartDate, value)
            End Set
        End Property

        Private _selectedStartDateText As String = New DateTime(DateTime.Now.Year, DateTime.Now.Month, 1).ToString("dd/MM/yyyy")
        Public Property SelectedStartDateText As String
            Get
                Return _selectedStartDateText
            End Get
            Set(value As String)
                SetProperty(_selectedStartDateText, value)
            End Set
        End Property

        Private _selectedEndDate As DateTime
        Public Property SelectedEndDate As DateTime
            Get
                Return _selectedEndDate
            End Get
            Set(value As DateTime)
                SetProperty(_selectedEndDate, value)
            End Set
        End Property

        Private _selectedEndDateText As String = DateTime.Now.ToString("dd/MM/yyyy")
        Public Property SelectedEndDateText As String
            Get
                Return _selectedEndDateText
            End Get
            Set(value As String)
                SetProperty(_selectedEndDateText, value)
            End Set
        End Property

        Private _selectedReportTab As Integer
        Public Property SelectedReportTab As Integer
            Get
                Return _selectedReportTab
            End Get
            Set(value As Integer)
                Dim prevTab As Integer = _selectedReportTab
                If SetProperty(_selectedReportTab, value) Then
                    _reportQuickSearch = ""
                    OnPropertyChanged(NameOf(ReportQuickSearch))
                    If (prevTab = 15 OrElse value = 15) Then
                        SelectedPartnerID = 0
                        ApplyPartnerFilter("")
                    End If
                    OnPropertyChanged(NameOf(ShowPartnerFilter))
                    OnPropertyChanged(NameOf(PartnerFilterLabel))
                    OnPropertyChanged(NameOf(PartnerFilterWatermark))
                    OnPropertyChanged(NameOf(ShowWarehouseFilter))
                    OnPropertyChanged(NameOf(ShowProductFilter))
                    ExecuteLoadReport(Nothing) ' Auto load when switching tabs
                End If
            End Set
        End Property

        Public ReadOnly Property ShowPartnerFilter As Boolean
            Get
                Return SelectedReportTab = 4 OrElse SelectedReportTab = 10 OrElse SelectedReportTab = 11 OrElse SelectedReportTab = 12 OrElse SelectedReportTab = 15
            End Get
        End Property

        Public ReadOnly Property PartnerFilterLabel As String
            Get
                Return If(SelectedReportTab = 15, "المورد:", "العميل / الشريك:")
            End Get
        End Property

        Public ReadOnly Property PartnerFilterWatermark As String
            Get
                Return If(SelectedReportTab = 15, "ابحث عن المورد...", "ابحث عن العميل...")
            End Get
        End Property

        Public ReadOnly Property ShowWarehouseFilter As Boolean
            Get
                Return SelectedReportTab = 5 OrElse SelectedReportTab = 7 OrElse SelectedReportTab = 13 OrElse SelectedReportTab = 14 OrElse SelectedReportTab = 15
            End Get
        End Property

        Public ReadOnly Property ShowProductFilter As Boolean
            Get
                Return SelectedReportTab = 7
            End Get
        End Property

        Private _reportQuickSearch As String = ""
        Public Property ReportQuickSearch As String
            Get
                Return _reportQuickSearch
            End Get
            Set(value As String)
                If SetProperty(_reportQuickSearch, value) Then
                    _reportPage = 0
                    OnPropertyChanged(NameOf(ReportPage))
                    ApplyInReportQuickSearchAndPaginate()
                End If
            End Set
        End Property

        ' For Inventory Valuation / Stock Movement / Warehouse Sales
        Private _warehouses As ObservableCollection(Of Warehouse)
        Public Property Warehouses As ObservableCollection(Of Warehouse)
            Get
                Return _warehouses
            End Get
            Set(value As ObservableCollection(Of Warehouse))
                SetProperty(_warehouses, value)
            End Set
        End Property

        Private _selectedWarehouseID As Integer = 0
        Public Property SelectedWarehouseID As Integer
            Get
                Return _selectedWarehouseID
            End Get
            Set(value As Integer)
                SetProperty(_selectedWarehouseID, value)
            End Set
        End Property

        ' For Stock Movement
        Private _products As ObservableCollection(Of Product)
        Public Property Products As ObservableCollection(Of Product)
            Get
                Return _products
            End Get
            Set(value As ObservableCollection(Of Product))
                SetProperty(_products, value)
            End Set
        End Property

        Private _selectedProductID As Integer = 0
        Public Property SelectedProductID As Integer
            Get
                Return _selectedProductID
            End Get
            Set(value As Integer)
                SetProperty(_selectedProductID, value)
            End Set
        End Property

        ' For Customer Reports
        Private _partners As ObservableCollection(Of Partner)
        Public Property Partners As ObservableCollection(Of Partner)
            Get
                Return _partners
            End Get
            Set(value As ObservableCollection(Of Partner))
                SetProperty(_partners, value)
            End Set
        End Property

        Private _selectedPartnerID As Integer = 0
        Public Property SelectedPartnerID As Integer
            Get
                Return _selectedPartnerID
            End Get
            Set(value As Integer)
                SetProperty(_selectedPartnerID, value)
            End Set
        End Property

        ' =======================================================
        ' SearchableDropdown Filter Helpers (In-Memory)
        ' =======================================================
        Public Sub ApplyPartnerFilter(Optional searchText As String = "")
            Dim baseList As IEnumerable(Of Partner) = _allPartners
            If SelectedReportTab = 15 Then
                baseList = _allPartners.Where(Function(p) p.PartnerID = 0 OrElse
                                                          String.Equals(p.PartnerType, "Supplier", StringComparison.OrdinalIgnoreCase) OrElse
                                                          String.Equals(p.PartnerType, "Both", StringComparison.OrdinalIgnoreCase) OrElse
                                                          (p.PartnerType IsNot Nothing AndAlso p.PartnerType.Contains("مورد")))
            End If

            If String.IsNullOrWhiteSpace(searchText) Then
                Partners = New ObservableCollection(Of Partner)(baseList.ToList())
            Else
                Dim lower = searchText.Trim().ToLower()
                Dim filtered = baseList.Where(Function(p) (p.PartnerName IsNot Nothing AndAlso p.PartnerName.ToLower().Contains(lower)) OrElse
                                                          (p.Phone IsNot Nothing AndAlso p.Phone.ToLower().Contains(lower)) OrElse
                                                          (p.AccountCode IsNot Nothing AndAlso p.AccountCode.ToLower().Contains(lower))).ToList()
                Partners = New ObservableCollection(Of Partner)(filtered)
            End If
            OnPropertyChanged(NameOf(Partners))
        End Sub

        Public Sub ApplyProductFilter(Optional searchText As String = "")
            If String.IsNullOrWhiteSpace(searchText) Then
                Products = New ObservableCollection(Of Product)(_allProducts)
            Else
                Dim lower = searchText.Trim().ToLower()
                Dim filtered = _allProducts.Where(Function(p) (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(lower)) OrElse
                                                             (p.ProductNameEn IsNot Nothing AndAlso p.ProductNameEn.ToLower().Contains(lower)) OrElse
                                                             (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(lower))).ToList()
                Products = New ObservableCollection(Of Product)(filtered)
            End If
            OnPropertyChanged(NameOf(Products))
        End Sub

        Public Sub ApplyWarehouseFilter(Optional searchText As String = "")
            If String.IsNullOrWhiteSpace(searchText) Then
                Warehouses = New ObservableCollection(Of Warehouse)(_allWarehouses)
            Else
                Dim lower = searchText.Trim().ToLower()
                Dim filtered = _allWarehouses.Where(Function(w) w.WarehouseName IsNot Nothing AndAlso w.WarehouseName.ToLower().Contains(lower)).ToList()
                Warehouses = New ObservableCollection(Of Warehouse)(filtered)
            End If
            OnPropertyChanged(NameOf(Warehouses))
        End Sub

        ' =======================================================
        ' Data Collections
        ' =======================================================
        Private _productProfits As ObservableCollection(Of ReportProductProfit)
        Public Property ProductProfits As ObservableCollection(Of ReportProductProfit)
            Get
                Return _productProfits
            End Get
            Set(value As ObservableCollection(Of ReportProductProfit))
                SetProperty(_productProfits, value)
            End Set
        End Property

        Private _invoiceProfits As ObservableCollection(Of ReportInvoiceProfit)
        Public Property InvoiceProfits As ObservableCollection(Of ReportInvoiceProfit)
            Get
                Return _invoiceProfits
            End Get
            Set(value As ObservableCollection(Of ReportInvoiceProfit))
                SetProperty(_invoiceProfits, value)
            End Set
        End Property

        Private _salesSummary As ObservableCollection(Of ReportSalesSummary)
        Public Property SalesSummary As ObservableCollection(Of ReportSalesSummary)
            Get
                Return _salesSummary
            End Get
            Set(value As ObservableCollection(Of ReportSalesSummary))
                SetProperty(_salesSummary, value)
            End Set
        End Property

        Private _topCustomers As ObservableCollection(Of ReportTopCustomer)
        Public Property TopCustomers As ObservableCollection(Of ReportTopCustomer)
            Get
                Return _topCustomers
            End Get
            Set(value As ObservableCollection(Of ReportTopCustomer))
                SetProperty(_topCustomers, value)
            End Set
        End Property

        Private _unpaidInvoices As ObservableCollection(Of ReportUnpaidInvoice)
        Public Property UnpaidInvoices As ObservableCollection(Of ReportUnpaidInvoice)
            Get
                Return _unpaidInvoices
            End Get
            Set(value As ObservableCollection(Of ReportUnpaidInvoice))
                SetProperty(_unpaidInvoices, value)
            End Set
        End Property

        Private _inventoryValuation As ObservableCollection(Of ReportInventoryValuation)
        Public Property InventoryValuation As ObservableCollection(Of ReportInventoryValuation)
            Get
                Return _inventoryValuation
            End Get
            Set(value As ObservableCollection(Of ReportInventoryValuation))
                SetProperty(_inventoryValuation, value)
            End Set
        End Property

        Private _slowMovingStock As ObservableCollection(Of ReportSlowMovingStock)
        Public Property SlowMovingStock As ObservableCollection(Of ReportSlowMovingStock)
            Get
                Return _slowMovingStock
            End Get
            Set(value As ObservableCollection(Of ReportSlowMovingStock))
                SetProperty(_slowMovingStock, value)
            End Set
        End Property

        Private _stockMovement As ObservableCollection(Of ReportStockMovement)
        Public Property StockMovement As ObservableCollection(Of ReportStockMovement)
            Get
                Return _stockMovement
            End Get
            Set(value As ObservableCollection(Of ReportStockMovement))
                SetProperty(_stockMovement, value)
            End Set
        End Property

        Private _expenseAnalysis As ObservableCollection(Of ReportExpenseAnalysis)
        Public Property ExpenseAnalysis As ObservableCollection(Of ReportExpenseAnalysis)
            Get
                Return _expenseAnalysis
            End Get
            Set(value As ObservableCollection(Of ReportExpenseAnalysis))
                SetProperty(_expenseAnalysis, value)
            End Set
        End Property

        Private _quotationStatus As ObservableCollection(Of ReportQuotationStatus)
        Public Property QuotationStatus As ObservableCollection(Of ReportQuotationStatus)
            Get
                Return _quotationStatus
            End Get
            Set(value As ObservableCollection(Of ReportQuotationStatus))
                SetProperty(_quotationStatus, value)
            End Set
        End Property

        Private _customerSalesSummary As ObservableCollection(Of ReportCustomerSalesSummary)
        Public Property CustomerSalesSummary As ObservableCollection(Of ReportCustomerSalesSummary)
            Get
                Return _customerSalesSummary
            End Get
            Set(value As ObservableCollection(Of ReportCustomerSalesSummary))
                SetProperty(_customerSalesSummary, value)
            End Set
        End Property

        Private _customerInvoicesDetail As ObservableCollection(Of ReportCustomerInvoiceDetail)
        Public Property CustomerInvoicesDetail As ObservableCollection(Of ReportCustomerInvoiceDetail)
            Get
                Return _customerInvoicesDetail
            End Get
            Set(value As ObservableCollection(Of ReportCustomerInvoiceDetail))
                SetProperty(_customerInvoicesDetail, value)
            End Set
        End Property

        Private _customerProductSales As ObservableCollection(Of ReportCustomerProductSale)
        Public Property CustomerProductSales As ObservableCollection(Of ReportCustomerProductSale)
            Get
                Return _customerProductSales
            End Get
            Set(value As ObservableCollection(Of ReportCustomerProductSale))
                SetProperty(_customerProductSales, value)
            End Set
        End Property

        Private _wastageReport As ObservableCollection(Of ReportWastageItem)
        Public Property WastageReport As ObservableCollection(Of ReportWastageItem)
            Get
                Return _wastageReport
            End Get
            Set(value As ObservableCollection(Of ReportWastageItem))
                SetProperty(_wastageReport, value)
            End Set
        End Property

        Private _warehouseSales As ObservableCollection(Of ReportWarehouseSales)
        Public Property WarehouseSales As ObservableCollection(Of ReportWarehouseSales)
            Get
                Return _warehouseSales
            End Get
            Set(value As ObservableCollection(Of ReportWarehouseSales))
                SetProperty(_warehouseSales, value)
            End Set
        End Property

        Private _purchaseInvoicesReport As ObservableCollection(Of ReportPurchaseInvoice)
        Public Property PurchaseInvoicesReport As ObservableCollection(Of ReportPurchaseInvoice)
            Get
                Return _purchaseInvoicesReport
            End Get
            Set(value As ObservableCollection(Of ReportPurchaseInvoice))
                SetProperty(_purchaseInvoicesReport, value)
            End Set
        End Property

        ' =======================================================
        ' Unified Summary Bar & Custom UserControl Table Properties
        ' =======================================================
        Private _currentReportTitle As String = "تقرير أرباح الأصناف"
        Public Property CurrentReportTitle As String
            Get
                Return _currentReportTitle
            End Get
            Set(value As String)
                SetProperty(_currentReportTitle, value)
            End Set
        End Property

        Private _currentReportSubtitle As String = ""
        Public Property CurrentReportSubtitle As String
            Get
                Return _currentReportSubtitle
            End Get
            Set(value As String)
                SetProperty(_currentReportSubtitle, value)
            End Set
        End Property

        Private _summaryMetrics As ObservableCollection(Of ReportSummaryMetric)
        Public Property SummaryMetrics As ObservableCollection(Of ReportSummaryMetric)
            Get
                Return _summaryMetrics
            End Get
            Set(value As ObservableCollection(Of ReportSummaryMetric))
                SetProperty(_summaryMetrics, value)
            End Set
        End Property

        Private _currentReportHeaders As ObservableCollection(Of ReportColumnHeader)
        Public Property CurrentReportHeaders As ObservableCollection(Of ReportColumnHeader)
            Get
                Return _currentReportHeaders
            End Get
            Set(value As ObservableCollection(Of ReportColumnHeader))
                SetProperty(_currentReportHeaders, value)
            End Set
        End Property

        Private _currentReportRows As ObservableCollection(Of ReportRowItem)
        Public Property CurrentReportRows As ObservableCollection(Of ReportRowItem)
            Get
                Return _currentReportRows
            End Get
            Set(value As ObservableCollection(Of ReportRowItem))
                SetProperty(_currentReportRows, value)
            End Set
        End Property

        Private _allConvertedRows As New List(Of ReportRowItem)()
        Private _filteredConvertedRows As New List(Of ReportRowItem)()

        Public ReadOnly Property AllFilteredRowsForExport As List(Of ReportRowItem)
            Get
                Return _filteredConvertedRows
            End Get
        End Property

        Public ReadOnly Property HasReportRows As Boolean
            Get
                Return _filteredConvertedRows IsNot Nothing AndAlso _filteredConvertedRows.Count > 0
            End Get
        End Property

        ' =======================================================
        ' Legacy Totals (Kept for backward compatibility)
        ' =======================================================
        Private _totalNetProfit As Decimal
        Public Property TotalNetProfit As Decimal
            Get
                Return _totalNetProfit
            End Get
            Set(value As Decimal)
                SetProperty(_totalNetProfit, value)
            End Set
        End Property

        Private _totalInventoryValue As Decimal
        Public Property TotalInventoryValue As Decimal
            Get
                Return _totalInventoryValue
            End Get
            Set(value As Decimal)
                SetProperty(_totalInventoryValue, value)
            End Set
        End Property

        Private _totalWastageValue As Decimal
        Public Property TotalWastageValue As Decimal
            Get
                Return _totalWastageValue
            End Get
            Set(value As Decimal)
                SetProperty(_totalWastageValue, value)
            End Set
        End Property

        ' =======================================================
        ' Pagination Logic (Client-Side)
        ' =======================================================
        Public Event ReportLoaded As EventHandler
        Private _allReportData As New List(Of Object)()
        Private ReadOnly PAGE_SIZE As Integer = 30
        Private _reportPage As Integer = 0

        Public Property NextReportPageCommand As ICommand
        Public Property PrevReportPageCommand As ICommand

        Public Property ReportPage As Integer
            Get
                Return _reportPage
            End Get
            Set(value As Integer)
                If value < 0 Then value = 0
                Dim maxPage = Math.Max(0, ReportTotalPages - 1)
                If value > maxPage Then value = maxPage
                SetProperty(_reportPage, value)
                UpdateReportPagination()
            End Set
        End Property

        Public ReadOnly Property ReportTotalPages As Integer
            Get
                Dim count = If(_filteredConvertedRows IsNot Nothing, _filteredConvertedRows.Count, _allReportData.Count)
                Return Math.Max(1, CInt(Math.Ceiling(count / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property ReportPageLabel As String
            Get
                Dim count = If(_filteredConvertedRows IsNot Nothing, _filteredConvertedRows.Count, _allReportData.Count)
                Return $"صفحة {ReportPage + 1} من {ReportTotalPages} ({count} سجل)"
            End Get
        End Property

        Public ReadOnly Property CanGoNextReport As Boolean
            Get
                Return ReportPage < ReportTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevReport As Boolean
            Get
                Return ReportPage > 0
            End Get
        End Property

        Private Sub ApplyInReportQuickSearchAndPaginate()
            If String.IsNullOrWhiteSpace(ReportQuickSearch) Then
                _filteredConvertedRows = _allConvertedRows.ToList()
            Else
                Dim q As String = ReportQuickSearch.Trim().ToLowerInvariant()
                _filteredConvertedRows = _allConvertedRows.Where(Function(r) r.SearchableText IsNot Nothing AndAlso r.SearchableText.ToLowerInvariant().Contains(q)).ToList()
            End If

            ' Renumber filtered rows
            For i As Integer = 0 To _filteredConvertedRows.Count - 1
                _filteredConvertedRows(i).RowNumber = i + 1
                _filteredConvertedRows(i).IsEvenRow = ((i + 1) Mod 2 = 0)
            Next

            BuildSummaryMetricsForActiveReport(_filteredConvertedRows.Select(Function(r) r.RawItem).ToList())
            UpdateReportPagination()
        End Sub

        Private Sub UpdateReportPagination()
            Try
                Dim skip = ReportPage * PAGE_SIZE
                Dim pageRows = _filteredConvertedRows.Skip(skip).Take(PAGE_SIZE).ToList()

                CurrentReportRows.Clear()
                For Each r In pageRows
                    CurrentReportRows.Add(r)
                Next

                ' Also keep typed collections synced for any legacy consumers
                Dim pageItems = pageRows.Select(Function(r) r.RawItem).Where(Function(x) x IsNot Nothing).ToList()
                ProductProfits.Clear()
                InvoiceProfits.Clear()
                SalesSummary.Clear()
                TopCustomers.Clear()
                UnpaidInvoices.Clear()
                InventoryValuation.Clear()
                SlowMovingStock.Clear()
                StockMovement.Clear()
                ExpenseAnalysis.Clear()
                QuotationStatus.Clear()
                CustomerSalesSummary.Clear()
                CustomerInvoicesDetail.Clear()
                CustomerProductSales.Clear()
                WastageReport.Clear()
                WarehouseSales.Clear()
                PurchaseInvoicesReport.Clear()

                Select Case SelectedReportTab
                    Case 0
                        For Each item In pageItems.OfType(Of ReportProductProfit)()
                            ProductProfits.Add(item)
                        Next
                    Case 1
                        For Each item In pageItems.OfType(Of ReportInvoiceProfit)()
                            InvoiceProfits.Add(item)
                        Next
                    Case 2
                        For Each item In pageItems.OfType(Of ReportSalesSummary)()
                            SalesSummary.Add(item)
                        Next
                    Case 3
                        For Each item In pageItems.OfType(Of ReportTopCustomer)()
                            TopCustomers.Add(item)
                        Next
                    Case 4
                        For Each item In pageItems.OfType(Of ReportUnpaidInvoice)()
                            UnpaidInvoices.Add(item)
                        Next
                    Case 5
                        For Each item In pageItems.OfType(Of ReportInventoryValuation)()
                            InventoryValuation.Add(item)
                        Next
                    Case 6
                        For Each item In pageItems.OfType(Of ReportSlowMovingStock)()
                            SlowMovingStock.Add(item)
                        Next
                    Case 7
                        For Each item In pageItems.OfType(Of ReportStockMovement)()
                            StockMovement.Add(item)
                        Next
                    Case 8
                        For Each item In pageItems.OfType(Of ReportExpenseAnalysis)()
                            ExpenseAnalysis.Add(item)
                        Next
                    Case 9
                        For Each item In pageItems.OfType(Of ReportQuotationStatus)()
                            QuotationStatus.Add(item)
                        Next
                    Case 10
                        For Each item In pageItems.OfType(Of ReportCustomerSalesSummary)()
                            CustomerSalesSummary.Add(item)
                        Next
                    Case 11
                        For Each item In pageItems.OfType(Of ReportCustomerInvoiceDetail)()
                            CustomerInvoicesDetail.Add(item)
                        Next
                    Case 12
                        For Each item In pageItems.OfType(Of ReportCustomerProductSale)()
                            CustomerProductSales.Add(item)
                        Next
                    Case 13
                        For Each item In pageItems.OfType(Of ReportWastageItem)()
                            WastageReport.Add(item)
                        Next
                    Case 14
                        For Each item In pageItems.OfType(Of ReportWarehouseSales)()
                            WarehouseSales.Add(item)
                        Next
                    Case 15
                        For Each item In pageItems.OfType(Of ReportPurchaseInvoice)()
                            PurchaseInvoicesReport.Add(item)
                        Next
                End Select

                OnPropertyChanged(NameOf(HasReportRows))
                OnPropertyChanged(NameOf(ReportTotalPages))
                OnPropertyChanged(NameOf(ReportPageLabel))
                OnPropertyChanged(NameOf(CanGoNextReport))
                OnPropertyChanged(NameOf(CanGoPrevReport))
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            Catch ex As Exception
            End Try
        End Sub

        ' =======================================================
        ' Commands
        ' =======================================================
        Public ReadOnly Property LoadReportCommand As ICommand
            Get
                Return New RelayCommand(AddressOf ExecuteLoadReport)
            End Get
        End Property

        Private Sub ExecuteLoadReport(parameter As Object)
            Try
                _allReportData.Clear()
                _reportPage = 0

                Select Case SelectedReportTab
                    Case 0 ' أرباح المنتجات
                        CurrentReportTitle = "📦 تقرير أرباح الأصناف والمنتجات"
                        CurrentReportSubtitle = $"تحليل الإيرادات والتكلفة وهامش الربح لكل صنف من {SelectedStartDate:yyyy/MM/dd} إلى {SelectedEndDate:yyyy/MM/dd}"
                        Dim data = _reportService.GetProductProfits(SelectedStartDate, SelectedEndDate, "ProfitDesc")
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 1 ' أرباح الفواتير
                        CurrentReportTitle = "🧾 تقرير أرباح الفواتير التفصيلي"
                        CurrentReportSubtitle = $"تحليل صافي المبيعات والتكلفة والربح لكل فاتورة من {SelectedStartDate:yyyy/MM/dd} إلى {SelectedEndDate:yyyy/MM/dd}"
                        Dim data = _reportService.GetInvoiceProfits(SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 2 ' مبيعات يومية / شهرية
                        CurrentReportTitle = "📅 ملخص المبيعات اليومية والشهرية"
                        CurrentReportSubtitle = $"إجمالي الفواتير والمبيعات والتحصيلات والآجل خلال الفترة المحددة"
                        Dim data = _reportService.GetSalesSummaryByPeriod(SelectedStartDate, SelectedEndDate, "Daily")
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 3 ' أقوى العملاء
                        CurrentReportTitle = "🏆 مبيعات العملاء - أقوى الشركاء"
                        CurrentReportSubtitle = $"ترتيب العملاء الأعلى مساهمة في المبيعات والتحصيلات"
                        Dim data = _reportService.GetTopCustomers(SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 4 ' أعمار الديون
                        CurrentReportTitle = "⏳ تقرير أعمار الديون والفواتير المتأخرة"
                        CurrentReportSubtitle = $"متابعة الذمم والمديونيات المستحقة حسب فترة التأخير"
                        Dim partnerIdParam As Integer? = If(SelectedPartnerID > 0, CType(SelectedPartnerID, Integer?), Nothing)
                        Dim data = _reportService.GetUnpaidInvoicesAging(DateTime.Now, partnerIdParam)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 5 ' تقييم المخزون
                        CurrentReportTitle = "🏢 تقرير جرد وتقييم المخزون الحالي"
                        CurrentReportSubtitle = $"تقييم الكميات المتوفرة بالتكلفة وسعر البيع"
                        Dim data = _reportService.GetInventoryValuation(SelectedWarehouseID)
                        TotalInventoryValue = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalInventoryValue += item.TotalCostValue
                        Next

                    Case 6 ' الأصناف الراكدة
                        CurrentReportTitle = "🕸️ تقرير الأصناف الراكدة"
                        CurrentReportSubtitle = $"الأصناف المتوفرة بالمخزون التي لم تسجل حركة بيع مؤخراً"
                        Dim data = _reportService.GetSlowMovingStock(3)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 7 ' حركة مستودع (الصنف)
                        CurrentReportTitle = "🔄 كارت حركة صنف في مستودع"
                        CurrentReportSubtitle = $"تتبع حركات الوارد والمنصرف والرصيد التراكمي للصنف"
                        If SelectedProductID = 0 Then
                            If Products.Count > 0 Then SelectedProductID = Products(0).ProductID
                        End If
                        Dim data = _reportService.GetStockMovement(SelectedProductID, SelectedWarehouseID, SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 8 ' تحليل المصاريف
                        CurrentReportTitle = "💸 تقرير تحليل المصروفات التشغيلية"
                        CurrentReportSubtitle = $"توزيع المصروفات المسجلة على الحسابات خلال الفترة"
                        Dim data = _reportService.GetExpensesAnalysis(SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 9 ' عروض الأسعار
                        CurrentReportTitle = "📜 تقرير حالة عروض الأسعار"
                        CurrentReportSubtitle = $"متابعة عروض الأسعار المعتمدة والمنتهية"
                        Dim data = _reportService.GetQuotationsStatus("All")
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 10 ' ملخص ربحية العملاء
                        CurrentReportTitle = "📊 ملخص ربحية العملاء الشامل"
                        CurrentReportSubtitle = $"مقارنة إجمالي المبيعات وتكلفة البضاعة وصافي الربح لكل عميل"
                        Dim data = _reportService.GetCustomerSalesSummary(SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.TotalProfit
                        Next

                    Case 11 ' فواتير العميل
                        CurrentReportTitle = "📑 تفاصيل أرباح فواتير العميل"
                        CurrentReportSubtitle = $"كشف تفصيلي بفواتير العميل المحدد وتكلفتها وربحيتها"
                        If SelectedPartnerID = 0 Then
                            Dim firstCustomer = _allPartners.FirstOrDefault(Function(p) p.PartnerID > 0)
                            If firstCustomer IsNot Nothing Then
                                SelectedPartnerID = firstCustomer.PartnerID
                            Else
                                BuildHeadersAndRowsForActiveReport()
                                ApplyInReportQuickSearchAndPaginate()
                                RaiseEvent ReportLoaded(Me, EventArgs.Empty)
                                Return
                            End If
                        End If
                        Dim data = _reportService.GetCustomerInvoicesDetail(SelectedPartnerID, SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.Profit
                        Next

                    Case 12 ' مبيعات الأصناف (عميل معين أو الكل)
                        CurrentReportTitle = "🛒 ربحية أصناف العميل"
                        CurrentReportSubtitle = $"تحليل الكميات والقيمة والربح للأصناف المسحوبة بواسطة العميل"
                        Dim data = _reportService.GetCustomerProductSales(SelectedPartnerID, SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 13 ' تقرير الهالك
                        CurrentReportTitle = "🗑️ تقرير الهالك والتوالف"
                        CurrentReportSubtitle = $"سجل الأصناف التالفة والكميات المستبعدة وتكلفتها المالية"
                        Dim whId As Integer? = If(SelectedWarehouseID = 0, Nothing, CType(SelectedWarehouseID, Integer?))
                        Dim data = _reportService.GetWastageReport(SelectedStartDate, SelectedEndDate, whId)
                        TotalWastageValue = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalWastageValue += item.TotalCost
                        Next

                    Case 14 ' تقرير مبيعات الفروع والمخازن (الجديد)
                        CurrentReportTitle = "🏬 تقرير مبيعات الفروع والمخازن"
                        CurrentReportSubtitle = $"تحليل مبيعات وتحصيلات وتكلفة وصافي أرباح كل فرع ومخزن من واقع الفواتير (WarehouseID)"
                        Dim whId As Integer? = If(SelectedWarehouseID = 0, Nothing, CType(SelectedWarehouseID, Integer?))
                        Dim data = _reportService.GetWarehouseSales(SelectedStartDate, SelectedEndDate, whId)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 15 ' تقرير فواتير المشتريات
                        CurrentReportTitle = "📥 تقرير فواتير المشتريات والموردين"
                        Dim supplierLabel As String = "جميع الموردين"
                        If SelectedPartnerID > 0 Then
                            Dim sup = _allPartners.FirstOrDefault(Function(p) p.PartnerID = SelectedPartnerID)
                            If sup IsNot Nothing Then supplierLabel = sup.PartnerName
                        End If
                        CurrentReportSubtitle = $"كشف فواتير المشتريات ({supplierLabel}) من {SelectedStartDate:yyyy/MM/dd} إلى {SelectedEndDate:yyyy/MM/dd}"
                        Dim pId As Integer? = If(SelectedPartnerID > 0, CType(SelectedPartnerID, Integer?), Nothing)
                        Dim whId As Integer? = If(SelectedWarehouseID > 0, CType(SelectedWarehouseID, Integer?), Nothing)
                        Dim data = _reportService.GetPurchaseInvoicesReport(SelectedStartDate, SelectedEndDate, pId, whId)
                        For Each item In data
                            _allReportData.Add(item)
                        Next
                End Select

                BuildHeadersAndRowsForActiveReport()
                ApplyInReportQuickSearchAndPaginate()
                RaiseEvent ReportLoaded(Me, EventArgs.Empty)
            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء تحميل التقرير: " & Environment.NewLine & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' =======================================================
        ' Top Summary Bar Builder (شريط الإجمالي أعلى كل تقرير)
        ' =======================================================
        Private Sub BuildSummaryMetricsForActiveReport(items As List(Of Object))
            SummaryMetrics.Clear()

            Select Case SelectedReportTab
                Case 0 ' أرباح الأصناف
                    Dim list = items.OfType(Of ReportProductProfit)().ToList()
                    Dim totalQty = list.Sum(Function(x) x.TotalQtySold)
                    Dim totalRev = list.Sum(Function(x) x.TotalRevenue)
                    Dim totalCost = list.Sum(Function(x) x.TotalCost)
                    Dim netProf = list.Sum(Function(x) x.NetProfit)
                    SummaryMetrics.Add(CreateMetric("عدد الأصناف المباعة", $"{list.Count:N0} صنف", $"إجمالي الكميات: {totalQty:N2}", "📦", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي إيرادات المبيعات", $"{totalRev:N2}", "قيمة المبيعات", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي التكلفة", $"{totalCost:N2}", "تكلفة البضاعة المباعة", "📉", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("صافي أرباح الأصناف", $"{netProf:N2}", If(totalRev > 0, $"نسبة الربح: {(netProf / totalRev) * 100:N1}%", "0%"), "✨", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 1 ' أرباح الفواتير
                    Dim list = items.OfType(Of ReportInvoiceProfit)().ToList()
                    Dim totalNet = list.Sum(Function(x) x.NetAmount)
                    Dim totalCost = list.Sum(Function(x) x.TotalCost)
                    Dim totalDisc = list.Sum(Function(x) x.Discount)
                    Dim netProf = list.Sum(Function(x) x.NetProfit)
                    SummaryMetrics.Add(CreateMetric("عدد الفواتير", $"{list.Count:N0} فاتورة", $"إجمالي الخصومات: {totalDisc:N2}", "🧾", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("صافي قيمة الفواتير", $"{totalNet:N2}", "بعد الخصم", "💳", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي تكلفة الفواتير", $"{totalCost:N2}", "التكلفة الفعلية", "📦", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("صافي ربح الفواتير", $"{netProf:N2}", If(totalNet > 0, $"هامش الربح: {(netProf / totalNet) * 100:N1}%", "0%"), "📈", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 2 ' المبيعات اليومية / الشهرية
                    Dim list = items.OfType(Of ReportSalesSummary)().ToList()
                    Dim invCount = list.Sum(Function(x) x.InvoiceCount)
                    Dim netSales = list.Sum(Function(x) x.TotalNetSales)
                    Dim paid = list.Sum(Function(x) x.TotalPaid)
                    Dim remAmt = list.Sum(Function(x) x.TotalRemainder)
                    SummaryMetrics.Add(CreateMetric("إجمالي الفواتير", $"{invCount:N0} فاتورة", $"خلال {list.Count} فترة/يوم", "📅", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("صافي المبيعات الكلي", $"{netSales:N2}", $"الخصومات: {list.Sum(Function(x) x.TotalDiscounts):N2}", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المحصل (المدفوع)", $"{paid:N2}", "نقد وشبكة", "✅", "#10B981", "#ECFDF5", "#A7F3D0"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الآجل المتبقي", $"{remAmt:N2}", "ذمم العملاء", "⏳", "#E11D48", "#FFF1F2", "#FECDD3"))

                Case 3 ' أقوى العملاء
                    Dim list = items.OfType(Of ReportTopCustomer)().ToList()
                    Dim totalInv = list.Sum(Function(x) x.TotalInvoices)
                    Dim totalPurchases = list.Sum(Function(x) x.TotalPurchases)
                    Dim totalPaid = list.Sum(Function(x) x.TotalPaid)
                    Dim totalRem = list.Sum(Function(x) x.TotalRemainder)
                    SummaryMetrics.Add(CreateMetric("عدد العملاء", $"{list.Count:N0} عميل", $"إجمالي الفواتير: {totalInv:N0}", "👥", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المسحوبات", $"{totalPurchases:N2}", "صافي المشتريات", "🛒", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المسدد", $"{totalPaid:N2}", "التحصيلات", "✅", "#10B981", "#ECFDF5", "#A7F3D0"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المديونية المتبقية", $"{totalRem:N2}", "الرصيد الآجل", "⚠️", "#E11D48", "#FFF1F2", "#FECDD3"))

                Case 4 ' أعمار الديون
                    Dim list = items.OfType(Of ReportUnpaidInvoice)().ToList()
                    Dim totalNet = list.Sum(Function(x) x.NetAmount)
                    Dim totalPaid = list.Sum(Function(x) x.PaidAmount)
                    Dim totalDebt = list.Sum(Function(x) x.UnpaidBalance)
                    Dim maxDays = If(list.Count > 0, list.Max(Function(x) x.DaysOverdue), 0)
                    SummaryMetrics.Add(CreateMetric("الفواتير المتأخرة", $"{list.Count:N0} فاتورة", $"أقصى تأخير: {maxDays} يوم", "⏳", "#E11D48", "#FFF1F2", "#FECDD3"))
                    SummaryMetrics.Add(CreateMetric("أصل قيمة الفواتير", $"{totalNet:N2}", "قيمة الفواتير الأصلية", "🧾", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("المسدد جزئياً", $"{totalPaid:N2}", "ما تم تحصيله", "✅", "#10B981", "#ECFDF5", "#A7F3D0"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الديون المستحقة", $"{totalDebt:N2}", "المبلغ المتبقي للتحصيل", "🚨", "#DC2626", "#FEF2F2", "#FECACA"))

                Case 5 ' جرد وتقييم المخزون
                    Dim list = items.OfType(Of ReportInventoryValuation)().ToList()
                    Dim totalQty = list.Sum(Function(x) x.CurrentQty)
                    Dim totalCostVal = list.Sum(Function(x) x.TotalCostValue)
                    SummaryMetrics.Add(CreateMetric("عدد بنود المخزون", $"{list.Count:N0} صنف", "الأصناف المسجلة بالجرد", "🏢", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الكميات المتوفرة", $"{totalQty:N2}", "مجموع الأرصدة الحالية", "📦", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي تقييم المخزون بالتكلفة", $"{totalCostVal:N2}", "بسعر التكلفة المرجح", "💎", "#7C3AED", "#F5F3FF", "#DDD6FE"))

                Case 6 ' الأصناف الراكدة
                    Dim list = items.OfType(Of ReportSlowMovingStock)().ToList()
                    Dim totalQty = list.Sum(Function(x) x.CurrentQty)
                    Dim avgDays = If(list.Count > 0, CInt(list.Average(Function(x) x.DaysSinceLastSale)), 0)
                    SummaryMetrics.Add(CreateMetric("عدد الأصناف الراكدة", $"{list.Count:N0} صنف", "أصناف بدون مبيعات نشطة", "🕸️", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الكميات الراكدة", $"{totalQty:N2}", "الرصيد المتوقف بالمخازن", "📦", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("متوسط أيام الركود", $"{avgDays:N0} يوم", "منذ آخر عملية بيع", "⏱️", "#E11D48", "#FFF1F2", "#FECDD3"))

                Case 7 ' حركة صنف في مستودع
                    Dim list = items.OfType(Of ReportStockMovement)().ToList()
                    Dim totalIn = list.Where(Function(x) x.QtyMoved > 0).Sum(Function(x) x.QtyMoved)
                    Dim totalOut = list.Where(Function(x) x.QtyMoved < 0).Sum(Function(x) Math.Abs(x.QtyMoved))
                    Dim netMove = totalIn - totalOut
                    SummaryMetrics.Add(CreateMetric("عدد الحركات المخزنية", $"{list.Count:N0} حركة", "خلال الفترة المحددة", "🔄", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الوارد (+)", $"+{totalIn:N2}", "مشتريات وتسويات إضافة", "📥", "#10B981", "#ECFDF5", "#A7F3D0"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المنصرف (-)", $"-{totalOut:N2}", "مبيعات وهالك وصرف", "📤", "#E11D48", "#FFF1F2", "#FECDD3"))
                    SummaryMetrics.Add(CreateMetric("صافي الحركة للفترة", $"{netMove:N2}", "الوارد ناقص المنصرف", "⚖️", "#7C3AED", "#F5F3FF", "#DDD6FE"))

                Case 8 ' تحليل المصروفات
                    Dim list = items.OfType(Of ReportExpenseAnalysis)().ToList()
                    Dim totalExp = list.Sum(Function(x) x.TotalExpenses)
                    Dim totalVouchers = list.Sum(Function(x) x.VoucherCount)
                    SummaryMetrics.Add(CreateMetric("عدد بنود المصروفات", $"{list.Count:N0} حساب", "حسابات المصروفات النشطة", "📂", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("عدد السندات والقيود", $"{totalVouchers:N0} عملية", "عمليات الصرف المسجلة", "🧾", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المصروفات التشغيلية", $"{totalExp:N2}", "إجمالي المبالغ المنصرفة", "💸", "#E11D48", "#FFF1F2", "#FECDD3"))

                Case 9 ' عروض الأسعار
                    Dim list = items.OfType(Of ReportQuotationStatus)().ToList()
                    Dim totalVal = list.Sum(Function(x) x.TotalAmount)
                    Dim totalItems = list.Sum(Function(x) x.ItemsCount)
                    SummaryMetrics.Add(CreateMetric("إجمالي عروض الأسعار", $"{list.Count:N0} عرض", "العروض المسجلة بالنظام", "📜", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي بنود العروض", $"{totalItems:N0} صنف", "مجموع الأصناف المسعرة", "📦", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي القيمة التقديرية", $"{totalVal:N2}", "مجموع قيم العروض", "💰", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 10 ' ملخص ربحية العملاء
                    Dim list = items.OfType(Of ReportCustomerSalesSummary)().ToList()
                    Dim totalInv = list.Sum(Function(x) x.InvoiceCount)
                    Dim totalSales = list.Sum(Function(x) x.TotalSales)
                    Dim totalCogs = list.Sum(Function(x) x.TotalCOGS)
                    Dim totalProf = list.Sum(Function(x) x.TotalProfit)
                    SummaryMetrics.Add(CreateMetric("عدد العملاء", $"{list.Count:N0} عميل", $"إجمالي الفواتير: {totalInv:N0}", "👥", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي مبيعات العملاء", $"{totalSales:N2}", "صافي المبيعات", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي التكلفة (COGS)", $"{totalCogs:N2}", "تكلفة البضاعة المباعة", "📦", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("صافي أرباح العملاء", $"{totalProf:N2}", If(totalSales > 0, $"هامش الربح: {(totalProf / totalSales) * 100:N1}%", "0%"), "✨", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 11 ' تفاصيل أرباح فواتير العميل
                    Dim list = items.OfType(Of ReportCustomerInvoiceDetail)().ToList()
                    Dim totalNet = list.Sum(Function(x) x.NetAmount)
                    Dim totalCogs = list.Sum(Function(x) x.TotalCOGS)
                    Dim totalProf = list.Sum(Function(x) x.Profit)
                    SummaryMetrics.Add(CreateMetric("عدد فواتير العميل", $"{list.Count:N0} فاتورة", $"إجمالي الخصم: {list.Sum(Function(x) x.Discount):N2}", "📑", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("صافي قيمة الفواتير", $"{totalNet:N2}", "إجمالي مسحوبات العميل", "💳", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي التكلفة", $"{totalCogs:N2}", "تكلفة الفواتير", "📦", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("صافي الربح من العميل", $"{totalProf:N2}", If(totalNet > 0, $"هامش الربح: {(totalProf / totalNet) * 100:N1}%", "0%"), "📈", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 12 ' ربحية أصناف العميل
                    Dim list = items.OfType(Of ReportCustomerProductSale)().ToList()
                    Dim totalQty = list.Sum(Function(x) x.TotalQty)
                    Dim totalSales = list.Sum(Function(x) x.TotalSalesValue)
                    Dim totalCost = list.Sum(Function(x) x.TotalCostValue)
                    Dim totalProf = list.Sum(Function(x) x.NetProfit)
                    SummaryMetrics.Add(CreateMetric("عدد الأصناف المسحوبة", $"{list.Count:N0} صنف", $"إجمالي الكميات: {totalQty:N2}", "🛒", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("إجمالي قيمة المبيعات", $"{totalSales:N2}", "قيمة البيع للعميل", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي التكلفة", $"{totalCost:N2}", "تكلفة الأصناف", "📦", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("صافي الربح المحقق", $"{totalProf:N2}", If(totalSales > 0, $"هامش الربح: {(totalProf / totalSales) * 100:N1}%", "0%"), "✨", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 13 ' تقرير الهالك والتوالف
                    Dim list = items.OfType(Of ReportWastageItem)().ToList()
                    Dim totalQty = list.Sum(Function(x) x.Quantity)
                    Dim totalLoss = list.Sum(Function(x) x.TotalCost)
                    SummaryMetrics.Add(CreateMetric("عدد سجلات الهالك", $"{list.Count:N0} سجل", "بنود التوالف المسجلة", "🗑️", "#E11D48", "#FFF1F2", "#FECDD3"))
                    SummaryMetrics.Add(CreateMetric("إجمالي الكميات التالفة", $"{totalQty:N3}", "مجموع الكميات المستبعدة", "📉", "#D97706", "#FFFBEB", "#FDE68A"))
                    SummaryMetrics.Add(CreateMetric("إجمالي تكلفة الهالك", $"{totalLoss:N3}", "القيمة المالية للخسائر", "🚨", "#DC2626", "#FEF2F2", "#FECACA"))

                Case 14 ' تقرير مبيعات الفروع والمخازن (الجديد)
                    Dim list = items.OfType(Of ReportWarehouseSales)().ToList()
                    Dim totalInv = list.Sum(Function(x) x.InvoiceCount)
                    Dim totalNet = list.Sum(Function(x) x.TotalNetSales)
                    Dim totalPaid = list.Sum(Function(x) x.TotalPaid)
                    Dim totalProf = list.Sum(Function(x) x.NetProfit)
                    SummaryMetrics.Add(CreateMetric("عدد الفروع والمخازن", $"{list.Count:N0} فرع/مخزن", $"إجمالي الفواتير: {totalInv:N0} فاتورة", "🏬", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("صافي مبيعات الفروع", $"{totalNet:N2}", $"الخصومات: {list.Sum(Function(x) x.TotalDiscounts):N2}", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المحصل بالفروع", $"{totalPaid:N2}", $"الآجل المتبقي: {list.Sum(Function(x) x.TotalRemainder):N2}", "✅", "#7C3AED", "#F5F3FF", "#DDD6FE"))
                    SummaryMetrics.Add(CreateMetric("صافي أرباح الفروع", $"{totalProf:N2}", If(totalNet > 0, $"هامش الربح العام: {(totalProf / totalNet) * 100:N1}%", "0%"), "✨", "#10B981", "#ECFDF5", "#A7F3D0"))

                Case 15 ' تقرير فواتير المشتريات
                    Dim list = items.OfType(Of ReportPurchaseInvoice)().ToList()
                    Dim totalDisc = list.Sum(Function(x) x.Discount)
                    Dim totalNet = list.Sum(Function(x) x.NetAmount)
                    Dim totalPaid = list.Sum(Function(x) x.PaidAmount)
                    Dim totalRem = list.Sum(Function(x) x.Remainder)
                    Dim suppliersCount = list.Select(Function(x) x.SupplierName).Distinct().Count()
                    SummaryMetrics.Add(CreateMetric("عدد فواتير المشتريات", $"{list.Count:N0} فاتورة", $"عدد الموردين: {suppliersCount:N0} مورد", "📥", "#2563EB", "#EFF6FF", "#BFDBFE"))
                    SummaryMetrics.Add(CreateMetric("صافي قيمة المشتريات", $"{totalNet:N2}", $"الخصومات المكتسبة: {totalDisc:N2}", "💰", "#0284C7", "#F0F9FF", "#BAE6FD"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المدفوع للموردين", $"{totalPaid:N2}", "المسدد نقداً أو بنكي", "✅", "#10B981", "#ECFDF5", "#A7F3D0"))
                    SummaryMetrics.Add(CreateMetric("إجمالي المتبقي للموردين", $"{totalRem:N2}", "ذمم الموردين المستحقة", "⏳", "#E11D48", "#FFF1F2", "#FECDD3"))
            End Select
        End Sub

        Private Function CreateMetric(title As String, valueText As String, subText As String, icon As String, accent As String, bg As String, border As String) As ReportSummaryMetric
            Return New ReportSummaryMetric() With {
                .Title = title,
                .ValueText = valueText,
                .SubText = subText,
                .Icon = icon,
                .AccentColor = accent,
                .BgColor = bg,
                .BorderColor = border
            }
        End Function

        ' =======================================================
        ' Custom UserControl Header & Row Builder for All 15 Reports
        ' =======================================================
        Private Sub BuildHeadersAndRowsForActiveReport()
            CurrentReportHeaders.Clear()
            _allConvertedRows.Clear()

            Select Case SelectedReportTab
                Case 0 ' أرباح الأصناف
                    AddHeader("الباركود", 1.1)
                    AddHeader("اسم الصنف", 2.2)
                    AddHeader("الكمية المباعة", 1.0)
                    AddHeader("إجمالي الإيرادات", 1.2)
                    AddHeader("إجمالي التكلفة", 1.2)
                    AddHeader("صافي الربح", 1.2, True, "#10B981")
                    AddHeader("هامش الربح %", 1.0)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportProductProfit)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.Barcode} {item.ProductName}"}
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.Barcode), "-", item.Barcode), 1.1, "#475569"))
                        row.Cells.Add(CreateCell(item.ProductName, 2.2, "#0F172A", True))
                        row.Cells.Add(CreateCell(item.TotalQtySold.ToString("N2"), 1.0, "#1E293B", True, "Center"))
                        row.Cells.Add(CreateCell(item.TotalRevenue.ToString("N2"), 1.2, "#0284C7", True))
                        row.Cells.Add(CreateCell(item.TotalCost.ToString("N2"), 1.2, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.NetProfit, 1.2))
                        row.Cells.Add(CreateBadgeCell($"{item.ProfitMarginPercent:N1}%", 1.0, If(item.ProfitMarginPercent >= 0, "#0369A1", "#B91C1C"), If(item.ProfitMarginPercent >= 0, "#E0F2FE", "#FEE2E2"), If(item.ProfitMarginPercent >= 0, "#BAE6FD", "#FECACA")))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 1 ' أرباح الفواتير
                    AddHeader("رقم الفاتورة", 0.9)
                    AddHeader("التاريخ", 1.2)
                    AddHeader("العميل", 1.8)
                    AddHeader("الكاشير", 1.2)
                    AddHeader("الإجمالي", 1.0)
                    AddHeader("الخصم", 0.9)
                    AddHeader("الصافي", 1.1)
                    AddHeader("التكلفة", 1.1)
                    AddHeader("صافي الربح", 1.2, True, "#10B981")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportInvoiceProfit)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.InvID} {item.CustomerName} {item.CashierName} {item.InvDate:yyyy/MM/dd}"}
                        row.Cells.Add(CreateBadgeCell($"#{item.InvID}", 0.9, "#1E40AF", "#DBEAFE", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.InvDate.ToString("yyyy/MM/dd HH:mm"), 1.2, "#475569"))
                        row.Cells.Add(CreateCell(item.CustomerName, 1.8, "#0F172A", True))
                        row.Cells.Add(CreateCell(item.CashierName, 1.2, "#475569"))
                        row.Cells.Add(CreateCell(item.TotalAmount.ToString("N2"), 1.0, "#334155"))
                        row.Cells.Add(CreateCell(item.Discount.ToString("N2"), 0.9, "#E11D48"))
                        row.Cells.Add(CreateCell(item.NetAmount.ToString("N2"), 1.1, "#0284C7", True))
                        row.Cells.Add(CreateCell(item.TotalCost.ToString("N2"), 1.1, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.NetProfit, 1.2))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 2 ' المبيعات اليومية / الشهرية
                    AddHeader("الفترة / التاريخ", 1.4)
                    AddHeader("عدد الفواتير", 1.0)
                    AddHeader("المبيعات الكلية", 1.2)
                    AddHeader("إجمالي الخصم", 1.0)
                    AddHeader("صافي المبيعات", 1.3, True, "#2563EB")
                    AddHeader("المدفوع (كاش/شبكة)", 1.3, True, "#10B981")
                    AddHeader("الآجل المتبقي", 1.2, True, "#E11D48")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportSalesSummary)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.PeriodLabel}"}
                        row.Cells.Add(CreateCell(item.PeriodLabel, 1.4, "#0F172A", True))
                        row.Cells.Add(CreateBadgeCell($"{item.InvoiceCount} فاتورة", 1.0, "#1E40AF", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.TotalGrossSales.ToString("N2"), 1.2, "#334155"))
                        row.Cells.Add(CreateCell(item.TotalDiscounts.ToString("N2"), 1.0, "#D97706"))
                        row.Cells.Add(CreateCell(item.TotalNetSales.ToString("N2"), 1.3, "#2563EB", True))
                        row.Cells.Add(CreateBadgeCell(item.TotalPaid.ToString("N2"), 1.3, "#047857", "#ECFDF5", "#A7F3D0"))
                        row.Cells.Add(CreateBadgeCell(item.TotalRemainder.ToString("N2"), 1.2, If(item.TotalRemainder > 0, "#BE123C", "#475569"), If(item.TotalRemainder > 0, "#FFF1F2", "#F1F5F9"), If(item.TotalRemainder > 0, "#FECDD3", "#E2E8F0")))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 3 ' أقوى العملاء
                    AddHeader("اسم العميل", 2.0)
                    AddHeader("رقم الهاتف", 1.2)
                    AddHeader("عدد الفواتير", 1.0)
                    AddHeader("إجمالي المشتريات", 1.3, True, "#2563EB")
                    AddHeader("إجمالي المسدد", 1.3, True, "#10B981")
                    AddHeader("المتبقي بالذمة", 1.3, True, "#E11D48")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportTopCustomer)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.PartnerName} {item.Phone}"}
                        row.Cells.Add(CreateCell(item.PartnerName, 2.0, "#0F172A", True))
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.Phone), "-", item.Phone), 1.2, "#475569"))
                        row.Cells.Add(CreateBadgeCell($"{item.TotalInvoices} فاتورة", 1.0, "#1E40AF", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.TotalPurchases.ToString("N2"), 1.3, "#2563EB", True))
                        row.Cells.Add(CreateCell(item.TotalPaid.ToString("N2"), 1.3, "#10B981", True))
                        row.Cells.Add(CreateBadgeCell(item.TotalRemainder.ToString("N2"), 1.3, If(item.TotalRemainder > 0, "#BE123C", "#047857"), If(item.TotalRemainder > 0, "#FFF1F2", "#ECFDF5"), If(item.TotalRemainder > 0, "#FECDD3", "#A7F3D0")))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 4 ' أعمار الديون
                    AddHeader("رقم الفاتورة", 0.9)
                    AddHeader("التاريخ", 1.1)
                    AddHeader("اسم العميل", 1.8)
                    AddHeader("الهاتف", 1.1)
                    AddHeader("أصل الفاتورة", 1.1)
                    AddHeader("المدفوع", 1.1)
                    AddHeader("الدين المتبقي", 1.2, True, "#E11D48")
                    AddHeader("أيام التأخير", 1.0)
                    AddHeader("الفئة العمرية", 1.3)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportUnpaidInvoice)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.InvID} {item.CustomerName} {item.Phone} {item.AgingCategory}"}
                        row.Cells.Add(CreateBadgeCell($"#{item.InvID}", 0.9, "#1E40AF", "#DBEAFE", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.InvDate.ToString("yyyy/MM/dd"), 1.1, "#475569"))
                        row.Cells.Add(CreateCell(item.CustomerName, 1.8, "#0F172A", True))
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.Phone), "-", item.Phone), 1.1, "#475569"))
                        row.Cells.Add(CreateCell(item.NetAmount.ToString("N2"), 1.1, "#334155"))
                        row.Cells.Add(CreateCell(item.PaidAmount.ToString("N2"), 1.1, "#10B981"))
                        row.Cells.Add(CreateBadgeCell(item.UnpaidBalance.ToString("N2"), 1.2, "#BE123C", "#FFF1F2", "#FECDD3"))
                        row.Cells.Add(CreateCell($"{item.DaysOverdue} يوم", 1.0, "#D97706", True, "Center"))
                        row.Cells.Add(CreateBadgeCell(item.AgingCategory, 1.3, "#9A3412", "#FFEDD5", "#FED7AA"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 5 ' جرد وتقييم المخزون
                    AddHeader("المستودع / الفرع", 1.4)
                    AddHeader("الباركود", 1.1)
                    AddHeader("اسم الصنف", 2.0)
                    AddHeader("التصنيف", 1.2)
                    AddHeader("الوحدة", 0.9)
                    AddHeader("الكمية المتوفرة", 1.1, True, "#2563EB")
                    AddHeader("متوسط التكلفة", 1.1)
                    AddHeader("إجمالي قيمة التكلفة", 1.4, True, "#7C3AED")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportInventoryValuation)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.WarehouseName} {item.Barcode} {item.ProductName} {item.CategoryName}"}
                        row.Cells.Add(CreateBadgeCell(item.WarehouseName, 1.4, "#1E40AF", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.Barcode), "-", item.Barcode), 1.1, "#475569"))
                        row.Cells.Add(CreateCell(item.ProductName, 2.0, "#0F172A", True))
                        row.Cells.Add(CreateCell(item.CategoryName, 1.2, "#475569"))
                        row.Cells.Add(CreateCell(item.UnitName, 0.9, "#64748B", False, "Center"))
                        row.Cells.Add(CreateCell(item.CurrentQty.ToString("N2"), 1.1, "#2563EB", True, "Center"))
                        row.Cells.Add(CreateCell(item.AvgCostPrice.ToString("N2"), 1.1, "#334155"))
                        row.Cells.Add(CreateBadgeCell(item.TotalCostValue.ToString("N2"), 1.4, "#6D28D9", "#F5F3FF", "#DDD6FE"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 6 ' الأصناف الراكدة
                    AddHeader("الباركود", 1.2)
                    AddHeader("اسم الصنف", 2.2)
                    AddHeader("التصنيف", 1.4)
                    AddHeader("الرصيد الحالي بالمخازن", 1.3)
                    AddHeader("تاريخ آخر بيع", 1.3)
                    AddHeader("أيام التوقف والركود", 1.3, True, "#E11D48")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportSlowMovingStock)()
                        Dim lastDateStr As String = If(item.LastSaleDate.HasValue, item.LastSaleDate.Value.ToString("yyyy/MM/dd"), "لم يُبع مطلقاً")
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.Barcode} {item.ProductName} {item.CategoryName}"}
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.Barcode), "-", item.Barcode), 1.2, "#475569"))
                        row.Cells.Add(CreateCell(item.ProductName, 2.2, "#0F172A", True))
                        row.Cells.Add(CreateCell(item.CategoryName, 1.4, "#475569"))
                        row.Cells.Add(CreateCell(item.CurrentQty.ToString("N2"), 1.3, "#2563EB", True, "Center"))
                        row.Cells.Add(CreateCell(lastDateStr, 1.3, "#64748B"))
                        row.Cells.Add(CreateBadgeCell($"{item.DaysSinceLastSale} يوم", 1.3, "#BE123C", "#FFF1F2", "#FECDD3"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 7 ' حركة صنف في مستودع
                    AddHeader("التاريخ والوقت", 1.3)
                    AddHeader("نوع الحركة", 1.4)
                    AddHeader("رقم المرجع", 0.9)
                    AddHeader("الطرف المعني", 1.6)
                    AddHeader("الكمية المتحركة", 1.1)
                    AddHeader("الرصيد التراكمي", 1.2, True, "#2563EB")
                    AddHeader("السعر", 1.0)
                    AddHeader("الكاشير / الموظف", 1.2)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportStockMovement)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.MovementType} {item.InvID} {item.PartnerName} {item.CashierName}"}
                        row.Cells.Add(CreateCell(item.MovementDate.ToString("yyyy/MM/dd HH:mm"), 1.3, "#475569"))
                        row.Cells.Add(CreateBadgeCell(item.MovementType, 1.4, If(item.QtyMoved >= 0, "#047857", "#BE123C"), If(item.QtyMoved >= 0, "#ECFDF5", "#FFF1F2"), If(item.QtyMoved >= 0, "#A7F3D0", "#FECDD3")))
                        row.Cells.Add(CreateCell($"#{item.InvID}", 0.9, "#334155", True, "Center"))
                        row.Cells.Add(CreateCell(item.PartnerName, 1.6, "#0F172A", True))
                        Dim qtyStr As String = If(item.QtyMoved > 0, $"+{item.QtyMoved:N2}", item.QtyMoved.ToString("N2"))
                        row.Cells.Add(CreateCell(qtyStr, 1.1, If(item.QtyMoved >= 0, "#10B981", "#E11D48"), True, "Center"))
                        row.Cells.Add(CreateBadgeCell(item.RunningBalance.ToString("N2"), 1.2, "#1D4ED8", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.UnitPrice.ToString("N2"), 1.0, "#334155"))
                        row.Cells.Add(CreateCell(item.CashierName, 1.2, "#64748B"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 8 ' تحليل المصروفات
                    AddHeader("كود الحساب", 1.1)
                    AddHeader("اسم حساب المصروف", 2.2)
                    AddHeader("عدد السندات / القيود", 1.2)
                    AddHeader("إجمالي المصروفات المنصرفة", 1.5, True, "#E11D48")
                    AddHeader("تاريخ آخر صرف", 1.3)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportExpenseAnalysis)()
                        Dim lastDateStr As String = If(item.LastExpenseDate > DateTime.MinValue, item.LastExpenseDate.ToString("yyyy/MM/dd"), "-")
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.AccountCode} {item.ExpenseCategory}"}
                        row.Cells.Add(CreateBadgeCell(item.AccountCode, 1.1, "#475569", "#F1F5F9", "#E2E8F0"))
                        row.Cells.Add(CreateCell(item.ExpenseCategory, 2.2, "#0F172A", True))
                        row.Cells.Add(CreateCell($"{item.VoucherCount} عملية", 1.2, "#334155", True, "Center"))
                        row.Cells.Add(CreateBadgeCell(item.TotalExpenses.ToString("N2"), 1.5, "#BE123C", "#FFF1F2", "#FECDD3"))
                        row.Cells.Add(CreateCell(lastDateStr, 1.3, "#64748B"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 9 ' عروض الأسعار
                    AddHeader("رقم العرض", 0.9)
                    AddHeader("تاريخ العرض", 1.2)
                    AddHeader("تاريخ الانتهاء", 1.2)
                    AddHeader("اسم العميل", 2.0)
                    AddHeader("عدد الأصناف", 1.0)
                    AddHeader("إجمالي قيمة العرض", 1.3, True, "#2563EB")
                    AddHeader("حالة العرض", 1.2)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportQuotationStatus)()
                        Dim expStr As String = If(item.ExpiryDate.HasValue, item.ExpiryDate.Value.ToString("yyyy/MM/dd"), "-")
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.QuoteID} {item.CustomerName} {item.QuoteStatus}"}
                        row.Cells.Add(CreateBadgeCell($"#{item.QuoteID}", 0.9, "#1E40AF", "#DBEAFE", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.QuoteDate.ToString("yyyy/MM/dd"), 1.2, "#475569"))
                        row.Cells.Add(CreateCell(expStr, 1.2, "#64748B"))
                        row.Cells.Add(CreateCell(item.CustomerName, 2.0, "#0F172A", True))
                        row.Cells.Add(CreateCell($"{item.ItemsCount} صنف", 1.0, "#334155", True, "Center"))
                        row.Cells.Add(CreateCell(item.TotalAmount.ToString("N2"), 1.3, "#2563EB", True))
                        row.Cells.Add(CreateBadgeCell(item.QuoteStatus, 1.2, "#047857", "#ECFDF5", "#A7F3D0"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 10 ' ملخص ربحية العملاء
                    AddHeader("اسم العميل", 2.2)
                    AddHeader("عدد الفواتير", 1.0)
                    AddHeader("إجمالي المبيعات", 1.4, True, "#2563EB")
                    AddHeader("تكلفة البضاعة المباعة", 1.4)
                    AddHeader("صافي الربح المحقق", 1.4, True, "#10B981")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportCustomerSalesSummary)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.PartnerName}"}
                        row.Cells.Add(CreateCell(item.PartnerName, 2.2, "#0F172A", True))
                        row.Cells.Add(CreateBadgeCell($"{item.InvoiceCount} فاتورة", 1.0, "#1E40AF", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.TotalSales.ToString("N2"), 1.4, "#2563EB", True))
                        row.Cells.Add(CreateCell(item.TotalCOGS.ToString("N2"), 1.4, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.TotalProfit, 1.4))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 11 ' تفاصيل أرباح فواتير العميل
                    AddHeader("رقم الفاتورة", 1.0)
                    AddHeader("التاريخ", 1.3)
                    AddHeader("رقم المرجع", 1.1)
                    AddHeader("الإجمالي", 1.2)
                    AddHeader("الخصم", 1.0)
                    AddHeader("الصافي", 1.2, True, "#2563EB")
                    AddHeader("تكلفة البضاعة", 1.2)
                    AddHeader("صافي الربح", 1.3, True, "#10B981")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportCustomerInvoiceDetail)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.InvID} {item.ReferenceNo} {item.InvDate:yyyy/MM/dd}"}
                        row.Cells.Add(CreateBadgeCell($"#{item.InvID}", 1.0, "#1E40AF", "#DBEAFE", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.InvDate.ToString("yyyy/MM/dd HH:mm"), 1.3, "#475569"))
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.ReferenceNo), "-", item.ReferenceNo), 1.1, "#64748B"))
                        row.Cells.Add(CreateCell(item.TotalAmount.ToString("N2"), 1.2, "#334155"))
                        row.Cells.Add(CreateCell(item.Discount.ToString("N2"), 1.0, "#E11D48"))
                        row.Cells.Add(CreateCell(item.NetAmount.ToString("N2"), 1.2, "#2563EB", True))
                        row.Cells.Add(CreateCell(item.TotalCOGS.ToString("N2"), 1.2, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.Profit, 1.3))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 12 ' ربحية أصناف العميل
                    AddHeader("اسم العميل", 1.8)
                    AddHeader("اسم الصنف", 2.0)
                    AddHeader("إجمالي الكمية", 1.1)
                    AddHeader("إجمالي قيمة المبيعات", 1.3, True, "#2563EB")
                    AddHeader("إجمالي التكلفة", 1.3)
                    AddHeader("صافي الربح", 1.3, True, "#10B981")

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportCustomerProductSale)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.PartnerName} {item.ProductName}"}
                        row.Cells.Add(CreateCell(item.PartnerName, 1.8, "#0F172A", True))
                        row.Cells.Add(CreateCell(item.ProductName, 2.0, "#1E293B", True))
                        row.Cells.Add(CreateCell(item.TotalQty.ToString("N2"), 1.1, "#2563EB", True, "Center"))
                        row.Cells.Add(CreateCell(item.TotalSalesValue.ToString("N2"), 1.3, "#0284C7", True))
                        row.Cells.Add(CreateCell(item.TotalCostValue.ToString("N2"), 1.3, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.NetProfit, 1.3))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 13 ' تقرير الهالك والتوالف
                    AddHeader("رقم السند", 0.8)
                    AddHeader("التاريخ", 1.1)
                    AddHeader("المخزن", 1.3)
                    AddHeader("الباركود", 1.1)
                    AddHeader("اسم الصنف", 1.8)
                    AddHeader("الكمية التالفة", 1.0)
                    AddHeader("تكلفة الوحدة", 1.0)
                    AddHeader("إجمالي الخسارة", 1.2, True, "#E11D48")
                    AddHeader("الحالة", 0.9)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportWastageItem)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.WastageID} {item.WarehouseName} {item.ProductCode} {item.ProductName} {item.Notes}"}
                        row.Cells.Add(CreateBadgeCell($"#{item.WastageID}", 0.8, "#475569", "#F1F5F9", "#E2E8F0"))
                        row.Cells.Add(CreateCell(item.WastageDate.ToString("yyyy/MM/dd"), 1.1, "#475569"))
                        row.Cells.Add(CreateCell(item.WarehouseName, 1.3, "#1E293B", True))
                        row.Cells.Add(CreateCell(If(String.IsNullOrEmpty(item.ProductCode), "-", item.ProductCode), 1.1, "#64748B"))
                        row.Cells.Add(CreateCell(item.ProductName, 1.8, "#0F172A", True, "Left", item.Notes))
                        row.Cells.Add(CreateCell(item.Quantity.ToString("N3"), 1.0, "#D97706", True, "Center"))
                        row.Cells.Add(CreateCell(item.CostPrice.ToString("N3"), 1.0, "#475569"))
                        row.Cells.Add(CreateBadgeCell(item.TotalCost.ToString("N3"), 1.2, "#BE123C", "#FFF1F2", "#FECDD3"))
                        row.Cells.Add(CreateBadgeCell(item.StatusText, 0.9, If(item.IsPosted, "#047857", "#B45309"), If(item.IsPosted, "#ECFDF5", "#FFFBEB"), If(item.IsPosted, "#A7F3D0", "#FDE68A")))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 14 ' تقرير مبيعات الفروع والمخازن (الجديد)
                    AddHeader("الفرع / المخزن", 1.8)
                    AddHeader("عدد الفواتير", 1.0)
                    AddHeader("إجمالي المبيعات", 1.2)
                    AddHeader("الخصومات", 0.9)
                    AddHeader("صافي المبيعات", 1.3, True, "#2563EB")
                    AddHeader("المحصل (مدفوع)", 1.2, True, "#10B981")
                    AddHeader("الآجل المتبقي", 1.1, True, "#E11D48")
                    AddHeader("التكلفة", 1.1)
                    AddHeader("صافي الربح", 1.3, True, "#10B981")
                    AddHeader("حصة الفرع %", 1.0)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportWarehouseSales)()
                        Dim row As New ReportRowItem() With {.RowNumber = idx, .IsEvenRow = (idx Mod 2 = 0), .RawItem = item, .SearchableText = $"{item.WarehouseID} {item.WarehouseName}"}
                        row.Cells.Add(CreateCell($"🏬 {item.WarehouseName}", 1.8, "#0F172A", True, "Left", $"كود الفرع/المخزن: #{item.WarehouseID}"))
                        row.Cells.Add(CreateBadgeCell($"{item.InvoiceCount} فاتورة", 1.0, "#1E40AF", "#EFF6FF", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.TotalGrossSales.ToString("N2"), 1.2, "#334155"))
                        row.Cells.Add(CreateCell(item.TotalDiscounts.ToString("N2"), 0.9, "#D97706"))
                        row.Cells.Add(CreateCell(item.TotalNetSales.ToString("N2"), 1.3, "#2563EB", True))
                        row.Cells.Add(CreateCell(item.TotalPaid.ToString("N2"), 1.2, "#059669", True))
                        row.Cells.Add(CreateCell(item.TotalRemainder.ToString("N2"), 1.1, If(item.TotalRemainder > 0, "#E11D48", "#64748B"), item.TotalRemainder > 0))
                        row.Cells.Add(CreateCell(item.TotalCost.ToString("N2"), 1.1, "#64748B"))
                        row.Cells.Add(CreateProfitBadgeCell(item.NetProfit, 1.3))
                        row.Cells.Add(CreateBadgeCell($"{item.SalesSharePercent:N1}%", 1.0, "#6D28D9", "#F5F3FF", "#DDD6FE"))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next

                Case 15 ' تقرير فواتير المشتريات
                    AddHeader("رقم الفاتورة", 0.9)
                    AddHeader("التاريخ", 1.2)
                    AddHeader("المورد", 1.8)
                    AddHeader("المخزن", 1.2)
                    AddHeader("الأصناف", 0.8)
                    AddHeader("الإجمالي", 1.0)
                    AddHeader("الخصم", 0.9)
                    AddHeader("الصافي", 1.1, True, "#2563EB")
                    AddHeader("المدفوع", 1.1, True, "#10B981")
                    AddHeader("المتبقي", 1.1, True, "#E11D48")
                    AddHeader("الحالة", 0.9)

                    Dim idx As Integer = 1
                    For Each item In _allReportData.OfType(Of ReportPurchaseInvoice)()
                        Dim subInfo As String = If(Not String.IsNullOrWhiteSpace(item.ReferenceNo) AndAlso item.ReferenceNo <> "-", $"مرجع: {item.ReferenceNo}", "")
                        If Not String.IsNullOrWhiteSpace(item.Notes) Then
                            subInfo = If(String.IsNullOrEmpty(subInfo), item.Notes, $"{subInfo} | {item.Notes}")
                        End If
                        Dim row As New ReportRowItem() With {
                            .RowNumber = idx,
                            .IsEvenRow = (idx Mod 2 = 0),
                            .RawItem = item,
                            .SearchableText = $"{item.InvID} {item.ReferenceNo} {item.SupplierName} {item.SupplierPhone} {item.WarehouseName} {item.UserName} {item.InvDate:yyyy/MM/dd}"
                        }
                        row.Cells.Add(CreateBadgeCell($"#{item.InvID}", 0.9, "#1E40AF", "#DBEAFE", "#BFDBFE"))
                        row.Cells.Add(CreateCell(item.InvDate.ToString("yyyy/MM/dd HH:mm"), 1.2, "#475569"))
                        row.Cells.Add(CreateCell(item.SupplierName, 1.8, "#0F172A", True, "Left", subInfo))
                        row.Cells.Add(CreateCell(item.WarehouseName, 1.2, "#475569"))
                        row.Cells.Add(CreateCell($"{item.ItemsCount} صنف", 0.8, "#334155", True, "Center"))
                        row.Cells.Add(CreateCell(item.TotalAmount.ToString("N2"), 1.0, "#334155"))
                        row.Cells.Add(CreateCell(item.Discount.ToString("N2"), 0.9, "#D97706"))
                        row.Cells.Add(CreateCell(item.NetAmount.ToString("N2"), 1.1, "#2563EB", True))
                        row.Cells.Add(CreateCell(item.PaidAmount.ToString("N2"), 1.1, "#059669", True))
                        row.Cells.Add(CreateBadgeCell(item.Remainder.ToString("N2"), 1.1, If(item.Remainder > 0, "#BE123C", "#475569"), If(item.Remainder > 0, "#FFF1F2", "#F1F5F9"), If(item.Remainder > 0, "#FECDD3", "#E2E8F0")))
                        row.Cells.Add(CreateBadgeCell(item.StatusText, 0.9, If(item.IsPosted, "#047857", "#B45309"), If(item.IsPosted, "#ECFDF5", "#FFFBEB"), If(item.IsPosted, "#A7F3D0", "#FDE68A")))
                        _allConvertedRows.Add(row)
                        idx += 1
                    Next
            End Select
        End Sub

        Private Sub AddHeader(title As String, weight As Double, Optional isHighlight As Boolean = False, Optional accentColor As String = "#334155")
            CurrentReportHeaders.Add(New ReportColumnHeader() With {
                .Title = title,
                .WidthWeight = weight,
                .IsHighlight = isHighlight,
                .AccentColor = accentColor
            })
        End Sub

        Private Function CreateCell(text As String, weight As Double, Optional fg As String = "#1E293B", Optional isBold As Boolean = False, Optional align As String = "Left", Optional subText As String = "") As ReportCellInfo
            Return New ReportCellInfo() With {
                .Text = If(text, ""),
                .SubText = If(subText, ""),
                .WidthWeight = weight,
                .ForegroundColor = fg,
                .IsBold = isBold,
                .IsBadge = False,
                .HorizontalAlign = align
            }
        End Function

        Private Function CreateBadgeCell(text As String, weight As Double, fg As String, bg As String, border As String, Optional align As String = "Center") As ReportCellInfo
            Return New ReportCellInfo() With {
                .Text = If(text, ""),
                .WidthWeight = weight,
                .ForegroundColor = fg,
                .IsBold = True,
                .IsBadge = True,
                .BadgeBgColor = bg,
                .BadgeBorderColor = border,
                .HorizontalAlign = align
            }
        End Function

        Private Function CreateProfitBadgeCell(profit As Decimal, weight As Double) As ReportCellInfo
            If profit >= 0 Then
                Return CreateBadgeCell(profit.ToString("N2"), weight, "#047857", "#ECFDF5", "#A7F3D0")
            Else
                Return CreateBadgeCell(profit.ToString("N2"), weight, "#BE123C", "#FFF1F2", "#FECDD3")
            End If
        End Function

    End Class
End Namespace
