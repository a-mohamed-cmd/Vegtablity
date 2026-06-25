Imports System.Collections.ObjectModel
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
            
            ' New Customer Reports
            CustomerSalesSummary = New ObservableCollection(Of ReportCustomerSalesSummary)()
            CustomerInvoicesDetail = New ObservableCollection(Of ReportCustomerInvoiceDetail)()
            CustomerProductSales = New ObservableCollection(Of ReportCustomerProductSale)()
            WastageReport = New ObservableCollection(Of ReportWastageItem)()

            NextReportPageCommand = New RelayCommand(Sub() ReportPage += 1, Function() CanGoNextReport)
            PrevReportPageCommand = New RelayCommand(Sub() ReportPage -= 1, Function() CanGoPrevReport)

            ' Filter options
            Dim warehouseList = _warehouseService.GetAllWarehouses()
            Warehouses = New ObservableCollection(Of Warehouse)()
            Warehouses.Add(New Warehouse() With {.WarehouseID = 0, .WarehouseName = "الكل"})
            If warehouseList IsNot Nothing Then
                For Each w In warehouseList
                    Warehouses.Add(w)
                Next
            End If
            
            SelectedWarehouseID = 0
            Dim productList = _productService.GetAllProducts()
            If productList IsNot Nothing Then
                Products = New ObservableCollection(Of Product)(productList)
            Else
                Products = New ObservableCollection(Of Product)()
            End If

            ' Load Customers for Filters
            Dim customerList = _partnerService.GetAllPartners("Customer")
            Partners = New ObservableCollection(Of Partner)()
            Partners.Add(New Partner() With {.PartnerID = 0, .PartnerName = "اختر عميل..."})
            If customerList IsNot Nothing Then
                For Each c In customerList
                    Partners.Add(c)
                Next
            End If
            SelectedPartnerID = 0

            ' By default, select the first report tab
            SelectedReportTab = 0
            
            ' Load data for the initial tab
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
                If SetProperty(_selectedReportTab, value) Then
                    ExecuteLoadReport(Nothing) ' Auto load when switching tabs
                End If
            End Set
        End Property

        ' For Inventory Valuation / Stock Movement
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
        ' Data Collections (Bound to DataGrids)
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

        ' =======================================================
        ' Totals (Bound to UI summary cards)
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
                Return Math.Max(1, CInt(Math.Ceiling(_allReportData.Count / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property ReportPageLabel As String
            Get
                Return $"صفحة {ReportPage + 1} من {ReportTotalPages} ({_allReportData.Count} سجل)"
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

        Private Sub UpdateReportPagination()
            Try
                Dim skip = ReportPage * PAGE_SIZE
                Dim pageItems = _allReportData.Skip(skip).Take(PAGE_SIZE).ToList()

                ' Clear all collections first
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

                Select Case SelectedReportTab
                    Case 0
                        For Each item In pageItems.Cast(Of ReportProductProfit)()
                            ProductProfits.Add(item)
                        Next
                    Case 1
                        For Each item In pageItems.Cast(Of ReportInvoiceProfit)()
                            InvoiceProfits.Add(item)
                        Next
                    Case 2
                        For Each item In pageItems.Cast(Of ReportSalesSummary)()
                            SalesSummary.Add(item)
                        Next
                    Case 3
                        For Each item In pageItems.Cast(Of ReportTopCustomer)()
                            TopCustomers.Add(item)
                        Next
                    Case 4
                        For Each item In pageItems.Cast(Of ReportUnpaidInvoice)()
                            UnpaidInvoices.Add(item)
                        Next
                    Case 5
                        For Each item In pageItems.Cast(Of ReportInventoryValuation)()
                            InventoryValuation.Add(item)
                        Next
                    Case 6
                        For Each item In pageItems.Cast(Of ReportSlowMovingStock)()
                            SlowMovingStock.Add(item)
                        Next
                    Case 7
                        For Each item In pageItems.Cast(Of ReportStockMovement)()
                            StockMovement.Add(item)
                        Next
                    Case 8
                        For Each item In pageItems.Cast(Of ReportExpenseAnalysis)()
                            ExpenseAnalysis.Add(item)
                        Next
                    Case 9
                        For Each item In pageItems.Cast(Of ReportQuotationStatus)()
                            QuotationStatus.Add(item)
                        Next
                    Case 10
                        For Each item In pageItems.Cast(Of ReportCustomerSalesSummary)()
                            CustomerSalesSummary.Add(item)
                        Next
                    Case 11
                        For Each item In pageItems.Cast(Of ReportCustomerInvoiceDetail)()
                            CustomerInvoicesDetail.Add(item)
                        Next
                    Case 12
                        For Each item In pageItems.Cast(Of ReportCustomerProductSale)()
                            CustomerProductSales.Add(item)
                        Next
                    Case 13
                        For Each item In pageItems.Cast(Of ReportWastageItem)()
                            WastageReport.Add(item)
                        Next
                End Select

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

                ' This switch matches the TabControl index in XAML
                Select Case SelectedReportTab
                    Case 0 ' أرباح المنتجات
                        Dim data = _reportService.GetProductProfits(SelectedStartDate, SelectedEndDate, "ProfitDesc")
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 1 ' أرباح الفواتير
                        Dim data = _reportService.GetInvoiceProfits(SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 2 ' مبيعات يومية
                        Dim data = _reportService.GetSalesSummaryByPeriod(SelectedStartDate, SelectedEndDate, "Daily")
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 3 ' أقوى العملاء
                        Dim data = _reportService.GetTopCustomers(SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 4 ' أعمار الديون
                        Dim data = _reportService.GetUnpaidInvoicesAging(DateTime.Now)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 5 ' تقييم المخزون
                        Dim data = _reportService.GetInventoryValuation(SelectedWarehouseID)
                        TotalInventoryValue = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalInventoryValue += item.TotalCostValue
                        Next

                    Case 6 ' الأصناف الراكدة
                        Dim data = _reportService.GetSlowMovingStock(3) ' 3 months inactive default
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 7 ' حركة مستودع (الصنف)
                        If SelectedProductID = 0 Then
                            ' Optional: Select first product if none selected
                            If Products.Count > 0 Then SelectedProductID = Products(0).ProductID
                        End If
                        Dim data = _reportService.GetStockMovement(SelectedProductID, SelectedWarehouseID, SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 8 ' تحليل المصاريف
                        Dim data = _reportService.GetExpensesAnalysis(SelectedStartDate, SelectedEndDate)
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 9 ' عروض الأسعار
                        Dim data = _reportService.GetQuotationsStatus("All")
                        For Each item In data
                            _allReportData.Add(item)
                        Next

                    Case 10 ' ملخص ربحية العملاء
                        Dim data = _reportService.GetCustomerSalesSummary(SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.TotalProfit
                        Next

                    Case 11 ' فواتير العميل
                        If SelectedPartnerID = 0 Then
                            MessageBox.Show("يرجى اختيار عميل أولاً لعرض مبيعاته.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Information)
                            Return
                        End If
                        Dim data = _reportService.GetCustomerInvoicesDetail(SelectedPartnerID, SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.Profit
                        Next

                    Case 12 ' مبيعات الأصناف (عميل معين أو الكل)
                        Dim data = _reportService.GetCustomerProductSales(SelectedPartnerID, SelectedStartDate, SelectedEndDate)
                        TotalNetProfit = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalNetProfit += item.NetProfit
                        Next

                    Case 13 ' تقرير الهالك
                        Dim whId As Integer? = If(SelectedWarehouseID = 0, Nothing, CType(SelectedWarehouseID, Integer?))
                        Dim data = _reportService.GetWastageReport(SelectedStartDate, SelectedEndDate, whId)
                        TotalWastageValue = 0
                        For Each item In data
                            _allReportData.Add(item)
                            TotalWastageValue += item.TotalCost
                        Next
                End Select

                UpdateReportPagination()
                RaiseEvent ReportLoaded(Me, EventArgs.Empty)
            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء تحميل التقرير: " & Environment.NewLine & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' Print Commands or Export CSV can be added easily here
    End Class
End Namespace
