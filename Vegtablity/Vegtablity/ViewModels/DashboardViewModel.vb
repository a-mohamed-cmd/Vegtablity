Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports LiveCharts
Imports LiveCharts.Wpf
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace ViewModels
    Public Class DashboardViewModel
        Inherits BaseViewModel

        Private ReadOnly _permissionService As New Services.PermissionService()
        Private ReadOnly _dashboardService As New Services.DashboardService()

        Private _menuItems As ObservableCollection(Of MenuItem)
        Private _selectedMenuItem As MenuItem
        Private _currentUserName As String
        Private _currentRoleName As String
        Private _isSidebarExpanded As Boolean = True
        Private _currentPageTitle As String = "الرئيسية"
        Private _currentPage As Object
        Private _isHomePage As Boolean = True
        Private _currencySymbol As String = "د.ك"

        ' --- Dashboard Metrics ---
        Private _todaySales As Decimal
        Private _todayPurchases As Decimal
        Private _todaySalesFormatted As String
        Private _todayPurchasesFormatted As String
        Private _totalProducts As Integer
        Private _totalCustomers As Integer

        ' --- Dashboard Collections ---
        Private _alertProducts As ObservableCollection(Of DashboardAlertProduct)
        Private _customerDebts As ObservableCollection(Of DashboardPartnerDebt)
        Private _supplierDebts As ObservableCollection(Of DashboardPartnerDebt)
        Private _salesSeries As SeriesCollection
        Private _salesLabels As List(Of String)
        Private _yFormatter As Func(Of Double, String)

        Public Sub New()
            If Services.Session.CurrentUser IsNot Nothing Then
                CurrentUserName = Services.Session.CurrentUser.FullName
                CurrentRoleName = Services.Session.CurrentUser.RoleName
            End If
            
            AlertProducts = New ObservableCollection(Of DashboardAlertProduct)()
            CustomerDebts = New ObservableCollection(Of DashboardPartnerDebt)()
            SupplierDebts = New ObservableCollection(Of DashboardPartnerDebt)()
            SalesSeries = New SeriesCollection()
            SalesLabels = New List(Of String)()

            Dim settingsSvc As New Services.SettingsService()
            Dim companyInfo = settingsSvc.GetCompanyInfo()
            If companyInfo IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(companyInfo.CurrencySymbol) Then
                If companyInfo.CurrencySymbol.Contains("/") Then
                    CurrencySymbol = companyInfo.CurrencySymbol.Split("/"c)(0).Trim()
                Else
                    CurrencySymbol = companyInfo.CurrencySymbol.Trim()
                End If
            End If

            YFormatter = Function(value) value.ToString("N3") & " " & CurrencySymbol

            ' Avoid DB calls at design time
            If Not System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                LoadMenuItems()
                LoadDashboardData()
            End If
        End Sub

        Public Property MenuItems As ObservableCollection(Of MenuItem)
            Get
                Return _menuItems
            End Get
            Set(value As ObservableCollection(Of MenuItem))
                SetProperty(_menuItems, value)
            End Set
        End Property

        Public Property SelectedMenuItem As MenuItem
            Get
                Return _selectedMenuItem
            End Get
            Set(value As MenuItem)
                If _selectedMenuItem IsNot Nothing Then _selectedMenuItem.IsSelected = False
                SetProperty(_selectedMenuItem, value)
                If _selectedMenuItem IsNot Nothing Then
                    _selectedMenuItem.IsSelected = True
                    CurrentPageTitle = _selectedMenuItem.Title
                End If
            End Set
        End Property

        Public Property CurrentUserName As String
            Get
                Return _currentUserName
            End Get
            Set(value As String)
                SetProperty(_currentUserName, value)
            End Set
        End Property

        Public Property CurrentRoleName As String
            Get
                Return _currentRoleName
            End Get
            Set(value As String)
                SetProperty(_currentRoleName, value)
            End Set
        End Property

        Public Property IsSidebarExpanded As Boolean
            Get
                Return _isSidebarExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isSidebarExpanded, value)
            End Set
        End Property

        Public Property CurrentPageTitle As String
            Get
                Return _currentPageTitle
            End Get
            Set(value As String)
                SetProperty(_currentPageTitle, value)
            End Set
        End Property

        ''' <summary>
        ''' الصفحة الحالية المعروضة في منطقة المحتوى (UserControl)
        ''' </summary>
        Public Property CurrentPage As Object
            Get
                Return _currentPage
            End Get
            Set(value As Object)
                SetProperty(_currentPage, value)
            End Set
        End Property

        ''' <summary>
        ''' هل الصفحة الرئيسية معروضة (لإظهار/إخفاء الكروت)
        ''' </summary>
        Public Property IsHomePage As Boolean
            Get
                Return _isHomePage
            End Get
            Set(value As Boolean)
                SetProperty(_isHomePage, value)
                If _isHomePage Then
                    LoadDashboardData() ' Refresh dashboard when returning home
                End If
            End Set
        End Property

        Public Property CurrencySymbol As String
            Get
                Return _currencySymbol
            End Get
            Set(value As String)
                SetProperty(_currencySymbol, value)
            End Set
        End Property

        ' --- Dashboard Properties ---
        Public Property TodaySales As Decimal
            Get
                Return _todaySales
            End Get
            Set(value As Decimal)
                SetProperty(_todaySales, value)
                TodaySalesFormatted = value.ToString("N3") & " " & CurrencySymbol
            End Set
        End Property

        Public Property TodaySalesFormatted As String
            Get
                Return _todaySalesFormatted
            End Get
            Set(value As String)
                SetProperty(_todaySalesFormatted, value)
            End Set
        End Property

        Public Property TodayPurchases As Decimal
            Get
                Return _todayPurchases
            End Get
            Set(value As Decimal)
                SetProperty(_todayPurchases, value)
                TodayPurchasesFormatted = value.ToString("N3") & " " & CurrencySymbol
            End Set
        End Property

        Public Property TodayPurchasesFormatted As String
            Get
                Return _todayPurchasesFormatted
            End Get
            Set(value As String)
                SetProperty(_todayPurchasesFormatted, value)
            End Set
        End Property

        Public Property TotalProducts As Integer
            Get
                Return _totalProducts
            End Get
            Set(value As Integer)
                SetProperty(_totalProducts, value)
            End Set
        End Property

        Public Property TotalCustomers As Integer
            Get
                Return _totalCustomers
            End Get
            Set(value As Integer)
                SetProperty(_totalCustomers, value)
            End Set
        End Property

        Public Property AlertProducts As ObservableCollection(Of DashboardAlertProduct)
            Get
                Return _alertProducts
            End Get
            Set(value As ObservableCollection(Of DashboardAlertProduct))
                SetProperty(_alertProducts, value)
            End Set
        End Property

        Public Property CustomerDebts As ObservableCollection(Of DashboardPartnerDebt)
            Get
                Return _customerDebts
            End Get
            Set(value As ObservableCollection(Of DashboardPartnerDebt))
                SetProperty(_customerDebts, value)
            End Set
        End Property

        Public Property SupplierDebts As ObservableCollection(Of DashboardPartnerDebt)
            Get
                Return _supplierDebts
            End Get
            Set(value As ObservableCollection(Of DashboardPartnerDebt))
                SetProperty(_supplierDebts, value)
            End Set
        End Property

        Public Property SalesSeries As SeriesCollection
            Get
                Return _salesSeries
            End Get
            Set(value As SeriesCollection)
                SetProperty(_salesSeries, value)
            End Set
        End Property

        Public Property SalesLabels As List(Of String)
            Get
                Return _salesLabels
            End Get
            Set(value As List(Of String))
                SetProperty(_salesLabels, value)
            End Set
        End Property

        Public Property YFormatter As Func(Of Double, String)
            Get
                Return _yFormatter
            End Get
            Set(value As Func(Of Double, String))
                SetProperty(_yFormatter, value)
            End Set
        End Property

        Public ReadOnly Property ToggleSidebarCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsSidebarExpanded = Not IsSidebarExpanded)
            End Get
        End Property

        Public ReadOnly Property LogoutCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteLogout)
            End Get
        End Property

        Public ReadOnly Property NavigateCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNavigate)
            End Get
        End Property

        Public ReadOnly Property ToggleExpandCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteToggleExpand)
            End Get
        End Property

        Public ReadOnly Property PayCustomerDebtCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePayCustomerDebt)
            End Get
        End Property

        Public ReadOnly Property PaySupplierDebtCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePaySupplierDebt)
            End Get
        End Property

        Private Sub LoadMenuItems()
            Dim allItems As New List(Of MenuItem)()

            ' Define all navigation sections
            allItems.Add(New MenuItem With {.Title = "الرئيسية", .Icon = "🏠", .FormName = "Dashboard", .IsVisible = True})
            
            Dim salesChildren As New ObservableCollection(Of MenuItem)()
            salesChildren.Add(New MenuItem With {.Title = "فاتورة مبيعات", .Icon = "🛒", .FormName = "Sales", .IsVisible = True})
            salesChildren.Add(New MenuItem With {.Title = "عروض الأسعار", .Icon = "📜", .FormName = "Quotes", .IsVisible = True})

            allItems.Add(New MenuItem With {
                .Title = "المبيعات",
                .Icon = "🛒",
                .FormName = "SalesParent",
                .IsVisible = True,
                .IsParent = True,
                .IsExpanded = False,
                .Children = salesChildren
            })

            allItems.Add(New MenuItem With {.Title = "الورديات", .Icon = "🕒", .FormName = "Shifts", .IsVisible = True})


            Dim purchaseChildren As New ObservableCollection(Of MenuItem)()
            purchaseChildren.Add(New MenuItem With {.Title = "فاتورة مشتريات", .Icon = "📦", .FormName = "Purchases", .IsVisible = True})
            purchaseChildren.Add(New MenuItem With {.Title = "عروض المشتريات", .Icon = "📜", .FormName = "PurchaseQuotes", .IsVisible = True})

            allItems.Add(New MenuItem With {
                .Title = "المشتريات",
                .Icon = "📦",
                .FormName = "PurchasesParent",
                .IsVisible = True,
                .IsParent = True,
                .IsExpanded = False,
                .Children = purchaseChildren
            })
            Dim settingsService As New Services.SettingsService()
            Dim compInfo = settingsService.GetCompanyInfo()
            Dim isProductionMode As Boolean = (compInfo IsNot Nothing AndAlso compInfo.ProductionMode)

            Dim inventoryChildren As New ObservableCollection(Of MenuItem)()
            inventoryChildren.Add(New MenuItem With {.Title = "المنتجات والمخزون", .Icon = "📦", .FormName = "Inventory", .IsVisible = True})
            If isProductionMode Then
                inventoryChildren.Add(New MenuItem With {.Title = "وصفات المنتجات", .Icon = "📜", .FormName = "Recipes", .IsVisible = True})
            End If
            inventoryChildren.Add(New MenuItem With {.Title = "الهوالك والتوالف", .Icon = "🗑️", .FormName = "Wastage", .IsVisible = True})
            inventoryChildren.Add(New MenuItem With {.Title = "الجرد الآلي", .Icon = "📝", .FormName = "StockTaking", .IsVisible = True})

            allItems.Add(New MenuItem With {
                .Title = "إدارة المخزون",
                .Icon = "🏪",
                .FormName = "InventoryParent",
                .IsVisible = True,
                .IsParent = True,
                .IsExpanded = False,
                .Children = inventoryChildren
            })

            ' === قسم الحسابات (قابل للتوسيع) ===
            Dim accountingChildren As New ObservableCollection(Of MenuItem)()
            accountingChildren.Add(New MenuItem With {.Title = "شجرة الحسابات", .Icon = "🌳", .FormName = "ChartOfAccounts", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "سند قبض", .Icon = "📥", .FormName = "ReceiptVoucher", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "سند صرف", .Icon = "📤", .FormName = "PaymentVoucher", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "قيود اليومية", .Icon = "📋", .FormName = "JournalEntries", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "كشف حساب", .Icon = "📄", .FormName = "AccountStatement", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "ميزان المراجعة", .Icon = "⚖", .FormName = "TrialBalance", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "المركز المالي", .Icon = "🏦", .FormName = "BalanceSheet", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "أرباح وخسائر", .Icon = "📊", .FormName = "ProfitLoss", .IsVisible = True})
            accountingChildren.Add(New MenuItem With {.Title = "الإقفال السنوي", .Icon = "🔒", .FormName = "YearEndClose", .IsVisible = True})

            allItems.Add(New MenuItem With {
                .Title = "الحسابات",
                .Icon = "📊",
                .FormName = "Accounting",
                .IsVisible = True,
                .IsParent = True,
                .IsExpanded = False,
                .Children = accountingChildren
            })

            allItems.Add(New MenuItem With {.Title = "العملاء والموردين", .Icon = "👥", .FormName = "Partners", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "لوحة الفواتير", .Icon = "🧾", .FormName = "InvoiceDashboard", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "الطلبات اليومية", .Icon = "🚚", .FormName = "DailyOrders", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "التقارير", .Icon = "📈", .FormName = "Reports", .IsVisible = True})

            ' === قسم الإعدادات (قابل للتوسيع) ===
            Dim settingsChildren As New ObservableCollection(Of MenuItem)()
            settingsChildren.Add(New MenuItem With {.Title = "إعدادات عامة", .Icon = "⚙", .FormName = "Settings", .IsVisible = True})
            settingsChildren.Add(New MenuItem With {.Title = "بيانات الشركة", .Icon = "🏢", .FormName = "CompanySettings", .IsVisible = True})
            settingsChildren.Add(New MenuItem With {.Title = "تحديث قاعدة البيانات", .Icon = "🛠️", .FormName = "DbUpdater", .IsVisible = True})

            allItems.Add(New MenuItem With {
                .Title = "الإعدادات",
                .Icon = "⚙",
                .FormName = "SettingsParent",
                .IsVisible = True,
                .IsParent = True,
                .IsExpanded = False,
                .Children = settingsChildren
            })

            allItems.Add(New MenuItem With {.Title = "إدارة المستخدمين", .Icon = "🔐", .FormName = "UserManagement", .IsVisible = True})

            ' Filter by permissions
            Dim visibleItems As New ObservableCollection(Of MenuItem)()

            Dim ProcessItem As Func(Of MenuItem, MenuItem) = Nothing
            ProcessItem = Function(item As MenuItem) As MenuItem
                              ' Check permission from DB for ALL forms
                              Dim canView As Boolean = False
                              If Services.Session.CurrentUser IsNot Nothing Then
                                  Try
                                      canView = _permissionService.CanViewForm(Services.Session.CurrentUser.RoleID, item.FormName)
                                  Catch
                                      canView = True ' Fallback
                                  End Try
                              End If

                              ' If it's a parent, we only keep it if it has at least one visible child
                              If item.IsParent AndAlso item.Children IsNot Nothing Then
                                  Dim visibleChildren As New ObservableCollection(Of MenuItem)()
                                  For Each child In item.Children
                                      Dim processedChild = ProcessItem(child)
                                      If processedChild IsNot Nothing Then
                                          visibleChildren.Add(processedChild)
                                      End If
                                  Next

                                  If visibleChildren.Count > 0 Then
                                      item.Children = visibleChildren
                                      Return item
                                  End If

                                  ' If no children are visible, hide parent entirely unless parent itself has explicit permission setup
                                  ' Wait, parents like 'Accounting' don't have their own forms, we just rely on children.
                                  Return Nothing
                              End If

                              ' For normal items, return item if canView=True
                              If canView Then Return item
                              Return Nothing
                          End Function

            For Each item In allItems
                Dim filtered = ProcessItem(item)
                If filtered IsNot Nothing Then
                    visibleItems.Add(filtered)
                End If
            Next

            MenuItems = visibleItems

            ' Select first item (Dashboard)
            If MenuItems.Count > 0 Then
                SelectedMenuItem = MenuItems(0)
            End If
        End Sub

        Private Sub LoadDashboardData()
            Try
                ' 1. Load Summary
                Dim summary = _dashboardService.GetDashboardSummary()
                If summary IsNot Nothing Then
                    TodaySales = summary.TodaySales
                    TodayPurchases = summary.TodayPurchases
                    TotalProducts = summary.TotalProducts
                    TotalCustomers = summary.TotalCustomers
                End If

                ' 2. Load Sales Chart (Last 7 Days)
                Dim chartData = _dashboardService.GetSalesChartData(7).ToList()
                Dim seriesValues As New ChartValues(Of Double)
                Dim labels As New List(Of String)
                
                For Each dp In chartData
                    seriesValues.Add(Convert.ToDouble(dp.TotalSales))
                    labels.Add(dp.DateValue.ToString("dd MMM")) ' e.g., "15 Oct"
                Next
                
                SalesSeries.Clear()
                SalesSeries.Add(New LineSeries With {
                    .Title = "المبيعات",
                    .Values = seriesValues,
                    .PointGeometry = DefaultGeometries.Circle,
                    .PointGeometrySize = 10
                })
                SalesLabels = labels
                
                ' 3. Load Alert Products
                Dim alerts = _dashboardService.GetAlertProducts()
                AlertProducts.Clear()
                For Each item In alerts
                    AlertProducts.Add(item)
                Next
                
                ' 4. Load Customer Debts
                Dim custDebts = _dashboardService.GetCustomerDebts()
                CustomerDebts.Clear()
                For Each item In custDebts
                    CustomerDebts.Add(item)
                Next

                ' 5. Load Supplier Debts
                Dim suppDebts = _dashboardService.GetSupplierDebts()
                SupplierDebts.Clear()
                For Each item In suppDebts
                    SupplierDebts.Add(item)
                Next
                
            Catch ex As Exception
                MessageBox.Show("خطأ في تحميل بيانات لوحة المعلومات: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteToggleExpand(parameter As Object)
            Dim item = TryCast(parameter, MenuItem)
            If item IsNot Nothing AndAlso item.IsParent Then
                item.IsExpanded = Not item.IsExpanded
            End If
        End Sub

        Private Sub ExecuteNavigate(parameter As Object)
            Dim item = TryCast(parameter, MenuItem)
            If item IsNot Nothing Then
                ' If it's a parent item, toggle expand instead of navigate
                If item.IsParent Then
                    item.IsExpanded = Not item.IsExpanded
                    Return
                End If

                SelectedMenuItem = item

                ' Check permissions right before navigation
                If Services.Session.CurrentUser IsNot Nothing Then
                    If Not _permissionService.CanViewForm(Services.Session.CurrentUser.RoleID, item.FormName) Then
                        MessageBox.Show("عفواً، ليس لديك صلاحية لعرض هذه الشاشة.", "رسالة نظام", MessageBoxButton.OK, MessageBoxImage.Warning)
                        Return
                    End If
                End If

                ' Navigate to page based on FormName
                Select Case item.FormName
                    Case "Dashboard"
                        CurrentPage = Nothing
                        IsHomePage = True

                    Case "UserManagement"
                        CurrentPage = New Views.UserManagementPage()
                        IsHomePage = False

                    Case "Sales"
                        CurrentPage = New Views.SalesInvoicePage()
                        IsHomePage = False

                    Case "Quotes"
                        CurrentPage = New Views.QuotePage()
                        IsHomePage = False

                    Case "Purchases"
                        CurrentPage = New Views.PurchaseInvoicePage()
                        IsHomePage = False

                    Case "PurchaseQuotes"
                        CurrentPage = New Views.PurchaseQuotePage()
                        IsHomePage = False

                    Case "Settings"
                        CurrentPage = New Views.SettingsPage()
                        IsHomePage = False

                    Case "Inventory"
                        CurrentPage = New Views.InventoryPage()
                        IsHomePage = False

                    Case "Wastage"
                        CurrentPage = New Views.WastagePage()
                        IsHomePage = False

                    Case "StockTaking"
                        CurrentPage = New Views.StockTakePage()
                        IsHomePage = False

                    Case "Recipes"
                        CurrentPage = New Views.RecipePage()
                        IsHomePage = False
                    Case "Partners"
                        CurrentPage = New Views.PartnersPage()
                        IsHomePage = False

                    Case "CompanySettings"
                        CurrentPage = New Views.CompanySettingsPage()
                        IsHomePage = False

                    Case "ChartOfAccounts"
                        CurrentPage = New Views.AccountingPage()
                        IsHomePage = False

                    Case "ReceiptVoucher"
                        CurrentPage = New Views.ReceiptVoucherPage()
                        IsHomePage = False

                    Case "PaymentVoucher"
                        CurrentPage = New Views.PaymentVoucherPage()
                        IsHomePage = False

                    Case "JournalEntries"
                        CurrentPage = New Views.JournalEntryPage()
                        IsHomePage = False

                    Case "AccountStatement"
                        CurrentPage = New Views.AccountStatementPage()
                        IsHomePage = False

                    Case "TrialBalance"
                        CurrentPage = New Views.TrialBalancePage()
                        IsHomePage = False

                    Case "BalanceSheet"
                        CurrentPage = New Views.BalanceSheetPage()
                        IsHomePage = False

                    Case "ProfitLoss"
                        CurrentPage = New Views.ProfitLossPage()
                        IsHomePage = False

                    Case "YearEndClose"
                        CurrentPage = New Views.YearEndClosePage()
                        IsHomePage = False

                    Case "InvoiceDashboard"
                        CurrentPage = New Views.InvoiceDashboardPage()
                        IsHomePage = False

                    Case "Reports"
                        CurrentPage = New Views.ReportsPage()
                        IsHomePage = False

                    Case "DbUpdater"
                        CurrentPage = New Views.DbUpdaterPage()
                        IsHomePage = False

                    Case "Shifts"
                        CurrentPage = New Views.ShiftsPage()
                        IsHomePage = False

                    Case "DailyOrders"
                        CurrentPage = New Views.DailyOrdersPage()
                        IsHomePage = False

                    Case Else
                        ' Future pages will be added here
                        CurrentPage = Nothing
                        IsHomePage = True
                End Select
            End If
        End Sub

        Private Sub ExecutePayCustomerDebt(parameter As Object)
            Dim debt = TryCast(parameter, DashboardPartnerDebt)
            If debt IsNot Nothing Then
                If Services.Session.CurrentUser IsNot Nothing AndAlso Not _permissionService.CanViewForm(Services.Session.CurrentUser.RoleID, "ReceiptVoucher") Then
                    MessageBox.Show("عفواً، لا توجد لديك صلاحية لفتح سندات القبض.", "صلاحيات الوصول", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If
                Dim page As New Views.ReceiptVoucherPage()
                Dim vm = TryCast(page.DataContext, ViewModels.VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.EditReceiptPartnerID = debt.PartnerID
                End If
                CurrentPage = page
                IsHomePage = False
            End If
        End Sub

        Private Sub ExecutePaySupplierDebt(parameter As Object)
            Dim debt = TryCast(parameter, DashboardPartnerDebt)
            If debt IsNot Nothing Then
                If Services.Session.CurrentUser IsNot Nothing AndAlso Not _permissionService.CanViewForm(Services.Session.CurrentUser.RoleID, "PaymentVoucher") Then
                    MessageBox.Show("عفواً، لا توجد لديك صلاحية لفتح سندات الصرف.", "صلاحيات الوصول", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If
                Dim page As New Views.PaymentVoucherPage()
                Dim vm = TryCast(page.DataContext, ViewModels.VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.EditPaymentPartnerID = debt.PartnerID
                End If
                CurrentPage = page
                IsHomePage = False
            End If
        End Sub

        Private Sub ExecuteLogout(obj As Object)
            Services.Session.CurrentUser = Nothing
            Dim loginWin As New Views.LoginWindow()
            loginWin.Show()

            For Each win As Window In Application.Current.Windows
                If TypeOf win Is Views.DashboardWindow Then
                    win.Close()
                    Exit For
                End If
            Next
        End Sub
    End Class
End Namespace
