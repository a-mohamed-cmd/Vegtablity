Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports System.Linq
Imports System.ComponentModel
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class SalesInvoiceViewModel
        Inherits BaseViewModel

        Private ReadOnly _invoiceService As InvoiceService
        Private ReadOnly _partnerService As PartnerService
        Private ReadOnly _productService As ProductService
        Private ReadOnly _warehouseService As WarehouseService
        Private ReadOnly _inventoryService As InventoryService
        Private ReadOnly _accountingService As AccountingService

        ' --- Collections for UI Dropdowns ---
        Public Property Customers As ObservableCollection(Of Partner)
        Public Property Warehouses As ObservableCollection(Of Warehouse)
        Public Property Products As ObservableCollection(Of Product)
        Public Property CashAccounts As ObservableCollection(Of Account)

        ' --- Pagination & Selection Caching ---
        Private _selectedProductsMap As New Dictionary(Of Integer, Product)()
        
        ' --- Invoice Details: Memory-backed client-side pagination ---
        Private _allInvoiceDetails As New List(Of InvoiceDetail)()
        Private ReadOnly PAGE_SIZE As Integer = 10
        Private _detailsPage As Integer = 0

        Private _productPage As Integer = 1
        Private ReadOnly _productPageSize As Integer = 20
        Private _productTotalCount As Integer = 0
        
        Private _historyPage As Integer = 0
        Private ReadOnly _historyPageSize As Integer = 20
        Private _historyTotalCount As Integer = 0
        Public Property InvoicesHistory As ObservableCollection(Of InvoiceHeader)

        ' Event raised to ask the View to show a Snackbar notification
        Public Event RequestSnackbar As Action(Of String)

        ' --- Current Invoice Data ---
        Private _currentInvoice As InvoiceHeader
        Public Property CurrentInvoice As InvoiceHeader
            Get
                Return _currentInvoice
            End Get
            Set(value As InvoiceHeader)
                If _currentInvoice IsNot Nothing Then
                    RemoveHandler _currentInvoice.PropertyChanged, AddressOf OnInvoicePropertyChanged
                End If
                SetProperty(_currentInvoice, value)
                If _currentInvoice IsNot Nothing Then
                    AddHandler _currentInvoice.PropertyChanged, AddressOf OnInvoicePropertyChanged
                End If
                ' Notify all derived UI state properties when invoice is replaced (e.g. New Invoice)
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
            End Set
        End Property

        Public ReadOnly Property IsInvoicePosted As Boolean
            Get
                If CurrentInvoice IsNot Nothing Then Return CurrentInvoice.IsPosted
                Return False
            End Get
        End Property

        Public ReadOnly Property IsEditAllowed As Boolean
            Get
                Return Not IsInvoicePosted
            End Get
        End Property

        ''' <summary>Used by DataGrid.IsReadOnly</summary>
        Public ReadOnly Property IsDataGridReadOnly As Boolean
            Get
                Return IsInvoicePosted
            End Get
        End Property

        Public ReadOnly Property IsPaymentAccountEnabled As Boolean
            Get
                Return IsEditAllowed AndAlso CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PaidAmount > 0
            End Get
        End Property

        ' --- Commands ---
        Public Property SaveCommand As ICommand
        Public Property PostCommand As ICommand
        Public Property NewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property RemoveItemCommand As ICommand
        Public Property PrintCommand As ICommand
        Public Property UnpostInvoiceCommand As ICommand
        Public Property ImportExcelCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand

        ' Pagination Commands
        Public Property NextProductPageCommand As ICommand
        Public Property PrevProductPageCommand As ICommand
        Public Property NextDetailsPageCommand As ICommand
        Public Property PrevDetailsPageCommand As ICommand
        Public Property LoadHistoryCommand As ICommand
        Public Property NextHistoryPageCommand As ICommand
        Public Property PrevHistoryPageCommand As ICommand

        Private ReadOnly _quoteService As QuoteService

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                Customers = New ObservableCollection(Of Partner)()
                Warehouses = New ObservableCollection(Of Warehouse)()
                Products = New ObservableCollection(Of Product)()
                CurrentInvoice = New InvoiceHeader() With {
                    .InvDate = DateTime.Now,
                    .Details = New ObservableCollection(Of InvoiceDetail)() 
                }
                Return
            End If

            _invoiceService = New InvoiceService()
            _partnerService = New PartnerService()
            _productService = New ProductService()
            _warehouseService = New WarehouseService()
            _inventoryService = New InventoryService()
            _accountingService = New AccountingService()
            _quoteService = New QuoteService()

            Customers = New ObservableCollection(Of Partner)()
            Warehouses = New ObservableCollection(Of Warehouse)()
            Products = New ObservableCollection(Of Product)()
            CashAccounts = New ObservableCollection(Of Account)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            PostCommand = New RelayCommand(AddressOf ExecutePost, AddressOf CanExecutePost)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem, AddressOf CanExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)
            PrintCommand = New RelayCommand(AddressOf ExecutePrint, AddressOf CanExecutePrint)
            UnpostInvoiceCommand = New RelayCommand(AddressOf ExecuteUnpostInvoice, AddressOf CanExecuteUnpostInvoice)
            ImportExcelCommand = New RelayCommand(AddressOf ExecuteImportExcel, AddressOf CanExecuteImportExcel)
            DownloadTemplateCommand = New RelayCommand(Sub(p) ExcelImporter.DownloadTemplate())

            ' Pagination Commands
            NextProductPageCommand = New RelayCommand(Sub() ProductPage += 1, Function() CanGoNextProduct)
            PrevProductPageCommand = New RelayCommand(Sub() ProductPage -= 1, Function() CanGoPrevProduct)
            NextDetailsPageCommand = New RelayCommand(Sub() DetailsPage += 1, Function() CanGoNextDetails)
            PrevDetailsPageCommand = New RelayCommand(Sub() DetailsPage -= 1, Function() CanGoPrevDetails)
            LoadHistoryCommand = New RelayCommand(AddressOf ExecuteLoadHistory)
            NextHistoryPageCommand = New RelayCommand(Sub() HistoryPage += 1, Function() CanGoNextHistory)
            PrevHistoryPageCommand = New RelayCommand(Sub() HistoryPage -= 1, Function() CanGoPrevHistory)

            LoadLookups()
            LoadPermissions("Sales")
            ExecuteNew(Nothing)
        End Sub

        Private Sub LoadLookups()
            Try
                Dim customerList = _partnerService.GetAllPartners("Customer")
                Customers = New ObservableCollection(Of Partner)(customerList)
                OnPropertyChanged(NameOf(Customers))

                Dim warehouseList = _warehouseService.GetAllWarehouses()
                Warehouses = New ObservableCollection(Of Warehouse)(warehouseList)
                OnPropertyChanged(NameOf(Warehouses))

                Dim cashList = _accountingService.GetCashAccounts()
                CashAccounts = New ObservableCollection(Of Account)(cashList)
                OnPropertyChanged(NameOf(CashAccounts))

                ' Initial Page Load for Products
                UpdateProductPagination()
            Catch ex As Exception
                ' Log
            End Try
        End Sub

        Private Sub OnInvoicePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(InvoiceHeader.IsPosted) Then
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
                OnPropertyChanged(NameOf(IsCanChangeHistoryPage))
            End If
            If e.PropertyName = NameOf(InvoiceHeader.PaidAmount) Then
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
                ' Clear payment account if amount becomes 0
                If CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PaidAmount = 0 Then
                    CurrentInvoice.PaymentAccountID = Nothing
                End If
            End If
            If e.PropertyName = NameOf(InvoiceHeader.WarehouseID) Then
                ' Revalidate stock for all items if warehouse changes
                ValidateStockForAllItems()
            End If
            ' Command re-evaluations
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

#Region "Pagination Logic"
        
        Public Property ProductPage As Integer
            Get
                Return _productPage
            End Get
            Set(value As Integer)
                If value < 1 Then value = 1
                SetProperty(_productPage, value)
                UpdateProductPagination()
            End Set
        End Property

        Public ReadOnly Property ProductPageLabel As String
            Get
                Dim totalPages = Math.Max(1, CInt(Math.Ceiling(_productTotalCount / _productPageSize)))
                Return $"صفحة {ProductPage} من {totalPages} ({_productTotalCount} صنف)"
            End Get
        End Property

        Public ReadOnly Property CanGoNextProduct As Boolean
            Get
                Dim totalPages = Math.Max(1, CInt(Math.Ceiling(_productTotalCount / _productPageSize)))
                Return ProductPage < totalPages
            End Get
        End Property

        Public ReadOnly Property CanGoPrevProduct As Boolean
            Get
                Return ProductPage > 1
            End Get
        End Property

        Private Sub UpdateProductPagination()
            Try
                ' Fetch only items for current page from DB
                Dim paged = _productService.GetProductsPaged(ProductPage, _productPageSize)
                _productTotalCount = paged.TotalCount

                Dim combinedList = New List(Of Product)(paged.Data)

                ' Crucial: Add currently selected products from the GRID that might not be in the current page
                If CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.Details IsNot Nothing Then
                    For Each detail In CurrentInvoice.Details
                        If detail.ProductID > 0 AndAlso Not combinedList.Any(Function(p) p.ProductID = detail.ProductID) Then
                            ' Check if we have the full product object in our map
                            Dim cachedProd As Product = Nothing
                            If _selectedProductsMap.TryGetValue(detail.ProductID, cachedProd) Then
                                combinedList.Add(cachedProd)
                            End If
                        End If
                    Next
                End If

                Products = New ObservableCollection(Of Product)(combinedList.OrderBy(Function(p) p.ProductName))
                OnPropertyChanged(NameOf(Products))
                OnPropertyChanged(NameOf(ProductPageLabel))
                OnPropertyChanged(NameOf(CanGoNextProduct))
                OnPropertyChanged(NameOf(CanGoPrevProduct))
            Catch ex As Exception
                ' Log
            End Try
        End Sub

        Public Property HistoryPage As Integer
            Get
                Return _historyPage
            End Get
            Set(value As Integer)
                If value < 1 Then value = 1
                SetProperty(_historyPage, value)
                UpdateHistoryPagination()
            End Set
        End Property

        Public ReadOnly Property HistoryPageLabel As String
            Get
                Dim totalPages = Math.Max(1, CInt(Math.Ceiling(_historyTotalCount / _historyPageSize)))
                Return $"صفحة {HistoryPage} من {totalPages}"
            End Get
        End Property

        Public ReadOnly Property CanGoNextHistory As Boolean
            Get
                Dim totalPages = Math.Max(1, CInt(Math.Ceiling(_historyTotalCount / _historyPageSize)))
                Return HistoryPage < totalPages
            End Get
        End Property

        Public ReadOnly Property CanGoPrevHistory As Boolean
            Get
                Return HistoryPage > 1
            End Get
        End Property

        Public ReadOnly Property IsCanChangeHistoryPage As Boolean
            Get
                Return True
            End Get
        End Property

        Private Sub UpdateHistoryPagination()
            Dim paged = _invoiceService.GetInvoicesPaged(HistoryPage, _historyPageSize, "Sales")
            _historyTotalCount = paged.TotalCount
            InvoicesHistory = New ObservableCollection(Of InvoiceHeader)(paged.Data)
            OnPropertyChanged(NameOf(InvoicesHistory))
            OnPropertyChanged(NameOf(HistoryPageLabel))
            OnPropertyChanged(NameOf(CanGoNextHistory))
            OnPropertyChanged(NameOf(CanGoPrevHistory))
        End Sub

        Public Sub GlobalFindProduct(term As String)
            If String.IsNullOrWhiteSpace(term) Then Return
            
            ' Perform a quick paged search for 1 item (global search)
            Dim result = _productService.GetProductsPaged(1, 1, term)
            If result.Data.Any() Then
                Dim prod = result.Data.First()
                ' Ensure it's in the map and current list so the UI can binding it
                If Not _selectedProductsMap.ContainsKey(prod.ProductID) Then 
                    _selectedProductsMap.Add(prod.ProductID, prod)
                End If
                
                If Not Products.Any(Function(p) p.ProductID = prod.ProductID) Then
                    Products.Add(prod)
                End If
            End If
        End Sub

        ' ========================
        ' Details Pagination
        ' ========================
        Public Property DetailsPage As Integer
            Get
                Return _detailsPage
            End Get
            Set(value As Integer)
                If value < 0 Then value = 0
                Dim maxPage = Math.Max(0, DetailsTotalPages - 1)
                If value > maxPage Then value = maxPage
                SetProperty(_detailsPage, value)
                UpdateDetailsPagination()
            End Set
        End Property

        Public ReadOnly Property DetailsTotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(_allInvoiceDetails.Count / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property DetailsPageLabel As String
            Get
                Return $"صفحة {DetailsPage + 1} من {DetailsTotalPages} ({_allInvoiceDetails.Count} صنف)"
            End Get
        End Property

        Public ReadOnly Property CanGoNextDetails As Boolean
            Get
                Return DetailsPage < DetailsTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevDetails As Boolean
            Get
                Return DetailsPage > 0
            End Get
        End Property

        Private Sub UpdateDetailsPagination()
            If CurrentInvoice Is Nothing Then Return
            Try
                Dim skip = DetailsPage * PAGE_SIZE
                Dim pageItems = _allInvoiceDetails.Skip(skip).Take(PAGE_SIZE).ToList()
                CurrentInvoice.Details.Clear()
                For Each d In pageItems
                    CurrentInvoice.Details.Add(d)
                Next
                OnPropertyChanged(NameOf(DetailsTotalPages))
                OnPropertyChanged(NameOf(DetailsPageLabel))
                OnPropertyChanged(NameOf(CanGoNextDetails))
                OnPropertyChanged(NameOf(CanGoPrevDetails))
                UpdateProductPagination()
            Catch ex As Exception
            End Try
        End Sub

#End Region

        Private Sub ExecuteNew(parameter As Object)
            _allInvoiceDetails.Clear()
            _detailsPage = 0
            CurrentInvoice = New InvoiceHeader() With {
                .InvType = "Sales",
                .InvDate = DateTime.Now,
                .CreatedAt = DateTime.Now,
                .ReferenceNo = Nothing,
                .Discount = 0,
                .PaidAmount = 0,
                .Details = New ObservableCollection(Of InvoiceDetail)()
            }
            If Warehouses.Any() Then
                CurrentInvoice.WarehouseID = Warehouses.First().WarehouseID
            End If
            
            ' Automatically add an empty row for the new invoice
            ExecuteAddItem(Nothing)
        End Sub

        ''' <summary>Load an existing invoice by ID (called from Invoice Dashboard)</summary>
        Public Sub LoadInvoice(invID As Integer)
            Dim loaded = _invoiceService.LoadInvoiceForEdit(invID)
            If loaded IsNot Nothing Then
                _allInvoiceDetails.Clear()
                _detailsPage = 0
                ' Move all loaded details to in-memory list
                For Each d In loaded.Details
                    AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                    _allInvoiceDetails.Add(d)
                Next
                ' Replace Details with an empty observable (UpdateDetailsPagination will populate it)
                loaded.Details = New ObservableCollection(Of InvoiceDetail)()
                CurrentInvoice = loaded
                
                If Not CurrentInvoice.IsPosted AndAlso _allInvoiceDetails.Count = 0 Then
                    ExecuteAddItem(Nothing)
                Else
                    UpdateDetailsPagination()
                End If
            End If
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            ' Permission Check
            If CurrentInvoice.InvID = 0 AndAlso Not CurrentPermissions.CanAdd Then Return False
            If CurrentInvoice.InvID > 0 AndAlso Not CurrentPermissions.CanEdit Then Return False

            If Not CurrentInvoice.PartnerID.HasValue Then Return False
            If Not CurrentInvoice.WarehouseID.HasValue Then Return False
            If CurrentInvoice.Details Is Nothing OrElse CurrentInvoice.Details.Count = 0 Then Return False
            If CurrentInvoice.PaidAmount > 0 AndAlso Not CurrentInvoice.PaymentAccountID.HasValue Then Return False

            Return True
        End Function

        Private Sub ExecuteSave(parameter As Object)
            Try
                ' Remove empty rows from ALL details
                Dim emptyRows = _allInvoiceDetails.Where(Function(d) d.ProductID = 0 OrElse d.Quantity = 0).ToList()
                For Each row In emptyRows
                    RemoveHandler row.PropertyChanged, AddressOf OnDetailPropertyChanged
                    _allInvoiceDetails.Remove(row)
                Next

                If _allInvoiceDetails.Count = 0 Then
                    System.Windows.MessageBox.Show("يجب إضافة صنف واحد على الأقل لحفظ الفاتورة.", "تحذير", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                    Return
                End If

                ' Build full list for saving
                CurrentInvoice.Details = New ObservableCollection(Of InvoiceDetail)(_allInvoiceDetails)
                RecalculateTotals()

                ' Validate Stock (soft warning)
                If Not ValidateStockForAllItems() Then
                    Dim answer = System.Windows.MessageBox.Show("بعض الأصناف تتجاوز المخزون المتاح، هل تريد الحفظ كمسودة؟", "تحذير المخزون", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
                    If answer = System.Windows.MessageBoxResult.No Then
                        UpdateDetailsPagination()
                        Return
                    End If
                End If

                If Services.Session.CurrentUser IsNot Nothing Then
                    CurrentInvoice.UserID = Services.Session.CurrentUser.UserID
                End If

                Dim invId = _invoiceService.SaveInvoice(CurrentInvoice)

                If CurrentInvoice.InvID = 0 Then
                    CurrentInvoice.InvID = invId
                    Dim freshInvoice = _invoiceService.GetInvoiceByID(invId)
                    If freshInvoice IsNot Nothing Then
                        CurrentInvoice.ReferenceNo = freshInvoice.ReferenceNo
                        CurrentInvoice.CreatedAt = freshInvoice.CreatedAt
                    End If
                End If

                UpdateDetailsPagination()
                RaiseEvent RequestSnackbar("✅ تم حفظ الفاتورة بنجاح")
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanExecutePost(parameter As Object) As Boolean
            If Not CurrentPermissions.CanEdit Then Return False
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            If CurrentInvoice.InvID = 0 Then Return False ' Must be saved first
            Return True
        End Function

        Private Sub ExecutePost(parameter As Object)
            ' Hard Validation: Prevent Posting if Stock is Insufficient
            If Not ValidateStockForAllItems() Then
                System.Windows.MessageBox.Show("لا يمكن ترحيل الفاتورة! توجد أصناف تتجاوز المخزون المتاح في المستودع المختار. يرجى تعديل الكميات.", "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
                Return
            End If

            Dim result = System.Windows.MessageBox.Show("هل أنت متأكد من ترحيل فاتورة المبيعات؟ سيتم خصم المخزون وتوليد القيود بشكل نهائي.", "تأكيد الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            If result = System.Windows.MessageBoxResult.Yes Then
                Try
                    CurrentInvoice.IsPosted = True
                    _invoiceService.SaveInvoice(CurrentInvoice)
                    RaiseEvent RequestSnackbar("✅ تم ترحيل الفاتورة بنجاح")
                Catch ex As Exception
                    CurrentInvoice.IsPosted = False ' Revert on failure
                    System.Windows.MessageBox.Show("خطأ أثناء الترحيل: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Function CanExecuteUnpostInvoice(parameter As Object) As Boolean
            If Not CurrentPermissions.CanEdit Then Return False
            Return CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.IsPosted AndAlso CurrentInvoice.InvID > 0
        End Function

        Private Sub ExecuteUnpostInvoice(parameter As Object)
            Dim warn = System.Windows.MessageBox.Show(
                "تحذير: إلغاء الترحيل سيعكس جميع حركات المخزون ويحذف جميع القيود المحاسبية." & vbCrLf &
                "ستعود الفاتورة لوضع مسودة حيث يمكنك تعديلها ثم إعادة الترحيل من جديد." & vbCrLf & vbCrLf &
                "هل أنت متأكد؟",
                "إلغاء الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            If warn <> System.Windows.MessageBoxResult.Yes Then Return

            Try
                Dim userID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0)
                _invoiceService.UnpostInvoice(CurrentInvoice.InvID, userID)
                ' أعد تحميل الفاتورة كمسودة قابلة للتعديل
                LoadInvoice(CurrentInvoice.InvID)
                RaiseEvent RequestSnackbar("✅ تم إلغاء الترحيل — الفاتورة مفتوحة للتعديل")
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء إلغاء الترحيل: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanExecutePrint(parameter As Object) As Boolean
            If Not CurrentPermissions.CanPrint Then Return False
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.InvID = 0 Then Return False
            Return True
        End Function

        Private Function CanExecuteImportExcel(parameter As Object) As Boolean
            Return IsEditAllowed AndAlso CurrentInvoice IsNot Nothing
        End Function

        Private Sub ExecuteImportExcel(parameter As Object)
            Try
                Dim importedRows = ExcelImporter.ReadExcelRows()
                If importedRows Is Nothing OrElse importedRows.Count = 0 Then
                    Return
                End If

                ' جلب كل الأصناف مباشرة من قاعدة البيانات لضمان عدم التأثر بنظام الـ Pagination
                Dim productList = _productService.GetAllProducts()
                Dim unknownRows As New List(Of ImportedRow)()
                Dim newDetails As New List(Of InvoiceDetail)()

                For Each row In importedRows
                    Dim matched As Product = Nothing
                    If Not String.IsNullOrWhiteSpace(row.Barcode) Then
                        matched = productList.FirstOrDefault(Function(p) p.Barcode IsNot Nothing AndAlso p.Barcode.Trim().ToLower() = row.Barcode.ToLower())
                    End If
                    If matched Is Nothing AndAlso Not String.IsNullOrWhiteSpace(row.ProductName) Then
                        matched = productList.FirstOrDefault(Function(p) p.ProductName IsNot Nothing AndAlso p.ProductName.Trim().ToLower() = row.ProductName.ToLower())
                    End If

                    Dim detail As New InvoiceDetail() With {
                        .Barcode = row.Barcode,
                        .Quantity = row.Quantity,
                        .UnitPrice = row.UnitPrice,
                        .TotalPrice = row.Quantity * row.UnitPrice
                    }

                    If matched IsNot Nothing Then
                        detail.ProductID = matched.ProductID
                        detail.ProductName = matched.ProductName
                        detail.CostPrice = matched.PurchasePrice
                        If detail.UnitPrice = 0 Then detail.UnitPrice = matched.SalePrice
                        detail.CalculateTotal()
                        detail.IsUnknown = False
                    Else
                        detail.ProductName = row.ProductName
                        detail.IsUnknown = True
                        unknownRows.Add(row)
                    End If

                    newDetails.Add(detail)
                Next

                ' Add all to grid
                For Each d In newDetails
                    AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                    _allInvoiceDetails.Add(d)
                Next

                If unknownRows.Count > 0 Then
                    Dim dlg As New Views.UnknownProductsDialog(unknownRows)
                    If dlg.ShowDialog() = True AndAlso dlg.Approved Then
                        ' Auto-add
                        Dim invService As New Services.InventoryService()
                        For Each row In unknownRows
                            Dim newId = invService.QuickAddProduct(row.Barcode, row.ProductName, 0, row.UnitPrice)
                            
                            ' Link in grid
                            Dim matchingDetails = _allInvoiceDetails.Where(Function(d) d.IsUnknown AndAlso d.Barcode = row.Barcode AndAlso d.ProductName = row.ProductName).ToList()
                            For Each d In matchingDetails
                                d.ProductID = newId
                                d.IsUnknown = False
                            Next
                        Next
                        ' Refresh products
                        LoadLookups()
                    Else
                        ' Remove unknown rows
                        Dim rowsToRemove = _allInvoiceDetails.Where(Function(d) d.IsUnknown).ToList()
                        For Each r In rowsToRemove
                            RemoveHandler r.PropertyChanged, AddressOf OnDetailPropertyChanged
                            _allInvoiceDetails.Remove(r)
                        Next
                    End If
                End If

                _detailsPage = Math.Max(0, DetailsTotalPages - 1)
                UpdateDetailsPagination()
                RecalculateTotals()

            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء الاستيراد: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecutePrint(parameter As Object)
            Dim customerName As String = ""
            If CurrentInvoice.PartnerID.HasValue Then
                Dim partner = Customers.FirstOrDefault(Function(p) p.PartnerID = CurrentInvoice.PartnerID.Value)
                If partner IsNot Nothing Then
                    customerName = partner.PartnerName
                End If
            End If

            Dim printer As New InvoicePrinter()
            printer.PrintSalesInvoice(CurrentInvoice, customerName)
        End Sub

        Private Function ValidateStockForAllItems() As Boolean
            If CurrentInvoice Is Nothing Then Return True
            If Not CurrentInvoice.WarehouseID.HasValue Then Return True
            
            Dim isAllValid As Boolean = True
            For Each detail In _allInvoiceDetails
                If detail.ProductID > 0 Then
                    Dim availableQty = _inventoryService.GetStockByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                    If detail.Quantity > availableQty Then
                        isAllValid = False
                    End If
                End If
            Next
            Return isAllValid
        End Function

        Private Function CanExecuteAddItem(parameter As Object) As Boolean
            Return IsEditAllowed
        End Function

        Private Sub ExecuteAddItem(parameter As Object)
            Dim newItem = New InvoiceDetail() With {.Quantity = 1, .UnitPrice = 0}
            AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
            _allInvoiceDetails.Add(newItem)

            Dim newPage = Math.Max(0, DetailsTotalPages - 1)
            If DetailsPage <> newPage Then
                DetailsPage = newPage
            Else
                UpdateDetailsPagination()
            End If
            RecalculateTotals()
        End Sub

        Private Function CanExecuteRemoveItem(parameter As Object) As Boolean
            Dim item = TryCast(parameter, InvoiceDetail)
            Return IsEditAllowed AndAlso item IsNot Nothing
        End Function

        Private Sub ExecuteRemoveItem(parameter As Object)
            Dim item = TryCast(parameter, InvoiceDetail)
            If item IsNot Nothing Then
                RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allInvoiceDetails.Remove(item)
                If DetailsPage >= DetailsTotalPages AndAlso DetailsPage > 0 Then
                    DetailsPage -= 1
                Else
                    UpdateDetailsPagination()
                End If
                RecalculateTotals()
            End If
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            Dim detail = CType(sender, InvoiceDetail)
            
            If e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                ' Auto-fill Price and reset Quantity based on Product Select for Sales
                ' Try to find product in current list OR in our global selection map
                Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod Is Nothing Then
                    _selectedProductsMap.TryGetValue(detail.ProductID, prod)
                End If

                If prod IsNot Nothing Then
                    ' Store in map if not already there
                    If Not _selectedProductsMap.ContainsKey(prod.ProductID) Then
                        _selectedProductsMap.Add(prod.ProductID, prod)
                    End If

                    detail.Quantity = 1
                    
                    ' Check for Custom Quoted Price First
                    Dim quotedPrice As Decimal? = Nothing
                    If CurrentInvoice.PartnerID.HasValue Then
                        quotedPrice = _quoteService.GetActiveQuotePrice(CurrentInvoice.PartnerID.Value, detail.ProductID)
                    End If

                    If quotedPrice.HasValue Then
                        detail.UnitPrice = quotedPrice.Value
                        RaiseEvent RequestSnackbar($"تم تطبيق سعر عرض خاص ({quotedPrice.Value:N3}) للصنف: {prod.ProductName}")
                    Else
                        detail.UnitPrice = prod.SalePrice
                        ' Only warn if a customer is selected and no quote was found
                        If CurrentInvoice.PartnerID.HasValue Then
                            RaiseEvent RequestSnackbar($"تنبيه: لا يوجد سعر مخصص في عروض الأسعار للصنف {prod.ProductName}. تم إدراج السعر الافتراضي.")
                        End If
                    End If

                    ' Use weighted average cost from ProductStock for this warehouse;
                    ' fallback to static PurchasePrice if no stock record exists yet.
                    If CurrentInvoice.WarehouseID.HasValue AndAlso CurrentInvoice.WarehouseID.Value > 0 Then
                        Dim avgCost = _inventoryService.GetAvgCostByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                        detail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                    Else
                        detail.CostPrice = prod.PurchasePrice ' fallback: no warehouse selected yet
                    End If
                    detail.Barcode = prod.Barcode ' Sync Barcode
                End If
            End If

            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse e.PropertyName = NameOf(InvoiceDetail.UnitPrice) OrElse e.PropertyName = NameOf(InvoiceDetail.TotalPrice) Then
                RecalculateTotals()
            End If
            
            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                If CurrentInvoice.WarehouseID.HasValue AndAlso detail.ProductID > 0 Then
                     Dim available = _inventoryService.GetStockByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                     If detail.Quantity > available Then
                          ' Warning logic here (Could add a property to InvoiceDetail like "IsStockWarning")
                     End If
                End If
            End If
            
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub RecalculateTotals()
            If CurrentInvoice Is Nothing Then Return
            
            Dim total As Decimal = 0
            For Each item In _allInvoiceDetails
                total += item.TotalPrice
            Next
            CurrentInvoice.TotalAmount = total
        End Sub

        Private Sub ExecuteLoadHistory(parameter As Object)
            HistoryPage = 1 ' This triggers UpdateHistoryPagination
        End Sub

    End Class
End Namespace
