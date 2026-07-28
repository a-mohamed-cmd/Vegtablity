Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports System.Linq
Imports System.ComponentModel
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class PurchaseInvoiceViewModel
        Inherits BaseViewModel

        Private ReadOnly _invoiceService As InvoiceService
        Private ReadOnly _partnerService As PartnerService
        Private ReadOnly _productService As ProductService
        Private ReadOnly _warehouseService As WarehouseService
        Private ReadOnly _accountingService As AccountingService
        Private ReadOnly _purchaseQuoteService As PurchaseQuoteService  ' ← عروض أسعار الموردين

        ' --- Collections for UI Dropdowns ---
        Public Property AllPartners As List(Of Partner)          ' المصدر الكامل (لا يتغير)
        Public Property FilteredPartners As ObservableCollection(Of Partner)  ' المعروض في القائمة
        Public Property Warehouses As ObservableCollection(Of Warehouse)
        Public Property CashAccounts As ObservableCollection(Of Account)  ' حسابات النقدية (11xx)

        ' --- Partner Search Text ---
        Private _partnerSearchText As String = ""
        Public Property PartnerSearchText As String
            Get
                Return _partnerSearchText
            End Get
            Set(value As String)
                _partnerSearchText = If(value, "")
                OnPropertyChanged(NameOf(PartnerSearchText))
            End Set
        End Property

        ' --- Invoice Date Text (إدخال يدوي مرن) ---
        Private _invDateText As String = ""
        Public Property InvDateText As String
            Get
                Return _invDateText
            End Get
            Set(value As String)
                _invDateText = If(value, "")
                OnPropertyChanged(NameOf(InvDateText))
            End Set
        End Property

        Public Sub SyncDateText()
            If CurrentInvoice IsNot Nothing Then
                InvDateText = CurrentInvoice.InvDate.ToString("dd/MM/yyyy")
            End If
        End Sub

        Public Sub ApplyPartnerFilter(Optional searchText As String = "")
            Dim txt = searchText.Trim()
            
            Dim settingsSvc As New Vegtablity.Services.SettingsService()
            Dim compInfo = settingsSvc.GetCompanyInfo()
            Dim isUnified = If(compInfo IsNot Nothing, compInfo.UnifiedPartnerSearch, True)

            Dim partnerList As System.Collections.Generic.List(Of Partner)
            If isUnified Then
                partnerList = _partnerService.SearchAllPartners(txt)
            Else
                partnerList = _partnerService.SearchPartners("Supplier", txt)
            End If

            FilteredPartners = New ObservableCollection(Of Partner)(partnerList)
            OnPropertyChanged(NameOf(FilteredPartners))
        End Sub

        ' Event raised to ask the View to show a Snackbar notification
        Public Event RequestSnackbar As Action(Of String)

        ''' <summary>يُطلَق بعد تحميل فاتورة أو إنشاء جديدة لتحديث الـ View (التاريخ + الشريك)</summary>
        Public Event InvoiceLoaded As Action(Of Integer?, String)
        Public Property Products As ObservableCollection(Of Product)

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

        ''' <summary>True while invoice is not posted — controls field editability.</summary>
        Public ReadOnly Property IsEditAllowed As Boolean
            Get
                Return Not IsInvoicePosted
            End Get
        End Property

        ''' <summary>Used by DataGrid.IsReadOnly binding.</summary>
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
        Public Property UnpostInvoiceCommand As ICommand
        Public Property ImportExcelCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand
        Public Property ExportPdfCommand As ICommand

        ' --- Invoice Details: Memory-backed client-side pagination ---
        Private _allInvoiceDetails As New List(Of InvoiceDetail)()
        Private ReadOnly PAGE_SIZE As Integer = 10
        Private _detailsPage As Integer = 0

        ' Pagination Commands
        Public Property NextDetailsPageCommand As ICommand
        Public Property PrevDetailsPageCommand As ICommand

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                AllPartners = New List(Of Partner)()
                FilteredPartners = New ObservableCollection(Of Partner)()
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
            _accountingService = New AccountingService()
            _purchaseQuoteService = New PurchaseQuoteService()  ' ← عروض أسعار الموردين

            AllPartners = New List(Of Partner)()
            FilteredPartners = New ObservableCollection(Of Partner)()
            Warehouses = New ObservableCollection(Of Warehouse)()
            Products = New ObservableCollection(Of Product)()
            CashAccounts = New ObservableCollection(Of Account)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            PostCommand = New RelayCommand(AddressOf ExecutePost, AddressOf CanExecutePost)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem, AddressOf CanExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)
            UnpostInvoiceCommand = New RelayCommand(AddressOf ExecuteUnpostInvoice, AddressOf CanExecuteUnpostInvoice)
            ImportExcelCommand = New RelayCommand(AddressOf ExecuteImportExcel, AddressOf CanExecuteImportExcel)
            DownloadTemplateCommand = New RelayCommand(Sub(p) ExcelImporter.DownloadTemplate())
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanExecuteExportPdf)

            NextDetailsPageCommand = New RelayCommand(Sub() DetailsPage += 1, Function() CanGoNextDetails)
            PrevDetailsPageCommand = New RelayCommand(Sub() DetailsPage -= 1, Function() CanGoPrevDetails)

            LoadLookups()
            LoadPermissions("Purchases")
            ExecuteNew(Nothing)
        End Sub

        Private Sub LoadLookups()
            Dim settingsSvc As New Vegtablity.Services.SettingsService()
            Dim compInfo = settingsSvc.GetCompanyInfo()
            Dim isUnified = If(compInfo IsNot Nothing, compInfo.UnifiedPartnerSearch, True)

            Dim partnerList As System.Collections.Generic.List(Of Partner)
            If isUnified Then
                partnerList = _partnerService.SearchAllPartners()
            Else
                partnerList = _partnerService.GetAllPartners("Supplier")
            End If
            
            AllPartners = partnerList
            FilteredPartners = New ObservableCollection(Of Partner)(partnerList)
            OnPropertyChanged(NameOf(FilteredPartners))

            Dim warehouseList = _warehouseService.GetAllWarehouses()
            Warehouses.Clear()
            For Each w In warehouseList
                Warehouses.Add(w)
            Next

            Dim productList = _productService.GetProductsForPurchase()
            Products.Clear()
            For Each p In productList
                Products.Add(p)
            Next

            Dim cashList = _accountingService.GetCashAccounts()
            CashAccounts.Clear()
            For Each a In cashList
                CashAccounts.Add(a)
            Next
        End Sub

        Private Sub OnInvoicePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(InvoiceHeader.IsPosted) Then
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
            End If
            If e.PropertyName = NameOf(InvoiceHeader.PaidAmount) Then
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
                ' Clear payment account if amount becomes 0
                If CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PaidAmount = 0 Then
                    CurrentInvoice.PaymentAccountID = Nothing
                End If
            End If
            ' Command re-evaluations
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub ExecuteNew(parameter As Object)
            _allInvoiceDetails.Clear()
            _detailsPage = 0
            CurrentInvoice = New InvoiceHeader() With {
                .InvType = "Purchase",
                .InvDate = DateTime.Now,
                .CreatedAt = DateTime.Now,
                .ReferenceNo = "",
                .Discount = 0,
                .PaidAmount = 0,
                .Details = New ObservableCollection(Of InvoiceDetail)()
            }
            If Warehouses.Any() Then
                CurrentInvoice.WarehouseID = Warehouses.First().WarehouseID
            End If
            
            ' Automatically add an empty row for the new invoice
            ExecuteAddItem(Nothing)

            ' أبلغ الـ View بمسح الشريك وتحديث التاريخ
            SyncDateText()
            RaiseEvent InvoiceLoaded(Nothing, Nothing)
        End Sub

        ''' <summary>Load an existing invoice by ID (called from Invoice Dashboard)</summary>
        Public Sub LoadInvoice(invID As Integer)
            Try
                Dim loaded = _invoiceService.LoadInvoiceForEdit(invID)
                If loaded IsNot Nothing Then
                    _allInvoiceDetails.Clear()
                    _detailsPage = 0
                    For Each d In loaded.Details
                        AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                        _allInvoiceDetails.Add(d)
                    Next
                    loaded.Details = New ObservableCollection(Of InvoiceDetail)()
                    CurrentInvoice = loaded
                    If Not CurrentInvoice.IsPosted AndAlso _allInvoiceDetails.Count = 0 Then
                        ExecuteAddItem(Nothing)
                    Else
                        UpdateDetailsPagination()
                    End If

                    ' أبلغ الـ View بتحديث التاريخ واسم الشريك
                    SyncDateText()
                    RaiseEvent InvoiceLoaded(CurrentInvoice.PartnerID, CurrentInvoice.PartnerName)
                Else
                    System.Windows.MessageBox.Show($"عذراً، تعذر العثور على فاتورة المشتريات رقم {invID} أو بياناتها ناقصة.", "خطأ في التحميل", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                End If
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ غير متوقع أثناء تحميل فاتورة المشتريات: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
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
            Catch ex As Exception
            End Try
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            If CurrentInvoice.InvID = 0 AndAlso Not CurrentPermissions.CanAdd Then Return False
            If CurrentInvoice.InvID > 0 AndAlso Not CurrentPermissions.CanEdit Then Return False
            If Not CurrentInvoice.PartnerID.HasValue Then Return False
            If Not CurrentInvoice.WarehouseID.HasValue Then Return False
            If _allInvoiceDetails.Count = 0 Then Return False
            If CurrentInvoice.PaidAmount > 0 AndAlso Not CurrentInvoice.PaymentAccountID.HasValue Then Return False
            Return True
        End Function

        Private Sub ExecuteSave(parameter As Object)
            Try
                Dim emptyRows = _allInvoiceDetails.Where(Function(d) d.ProductID = 0 OrElse d.Quantity = 0).ToList()
                For Each row In emptyRows
                    RemoveHandler row.PropertyChanged, AddressOf OnDetailPropertyChanged
                    _allInvoiceDetails.Remove(row)
                Next

                If _allInvoiceDetails.Count = 0 Then
                    System.Windows.MessageBox.Show("يجب إضافة صنف واحد على الأقل لحفظ الفاتورة.", "تحذير", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                    Return
                End If

                CurrentInvoice.Details = New ObservableCollection(Of InvoiceDetail)(_allInvoiceDetails)
                RecalculateTotals()

                If Services.Session.CurrentUser IsNot Nothing Then
                    CurrentInvoice.UserID = Services.Session.CurrentUser.UserID
                End If

                Dim invId = _invoiceService.SaveInvoice(CurrentInvoice)
                If CurrentInvoice.InvID = 0 Then
                    CurrentInvoice.InvID = invId
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
            If CurrentInvoice.InvID = 0 Then Return False
            Return True
        End Function

        Private Sub ExecutePost(parameter As Object)
            Dim result = System.Windows.MessageBox.Show("هل أنت متأكد من ترحيل الفاتورة؟ لن يمكنك التعديل عليها أو حذفها بعد الترحيل، وسيتم تحديث المخزون وتوليد القيود المحاسبية الآلية.", "تأكيد الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            If result = System.Windows.MessageBoxResult.Yes Then
                Try
                    Dim userID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0)
                    _invoiceService.PostInvoice(CurrentInvoice.InvID, userID)
                    
                    ' Reload To Refresh UI state (IsPosted, JournalEntries, etc.)
                    LoadInvoice(CurrentInvoice.InvID)
                    
                    RaiseEvent RequestSnackbar("✅ تم ترحيل الفاتورة بنجاح")
                Catch ex As Exception
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
                "تحذير: إلغاء الترحيل سيعكس المخزون ويحذف القيود." & vbCrLf &
                "ستعود الفاتورة لوضع مسودة حيث يمكنك تعديلها ثم إعادة الترحيل." & vbCrLf & vbCrLf &
                "هل أنت متأكد؟",
                "إلغاء الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            If warn <> System.Windows.MessageBoxResult.Yes Then Return

            Try
                Dim userID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0)
                _invoiceService.UnpostInvoice(CurrentInvoice.InvID, userID)
                LoadInvoice(CurrentInvoice.InvID)
                RaiseEvent RequestSnackbar("✅ تم إلغاء الترحيل — الفاتورة مفتوحة للتعديل")
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء إلغاء الترحيل: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

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
            If e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                ' ─────────────────────────────────────────────────────────────
                '  تحميل بيانات الصنف عند اختياره:
                '  1. السعر: يُؤخذ من عرض أسعار المورد المحدد إن وُجد
                '            وإلا يُستخدم PurchasePrice الافتراضي للصنف
                '  2. باقي البيانات: الاسم والباركود والوحدة
                ' ─────────────────────────────────────────────────────────────
                Dim detail = TryCast(sender, InvoiceDetail)
                If detail IsNot Nothing AndAlso detail.ProductID > 0 Then
                    Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                    If prod IsNot Nothing Then
                        ' Keep existing quantity if already set, otherwise default to 1
                        If detail.Quantity <= 0 Then detail.Quantity = 1

                        ' ── تحديد السعر: عرض الأسعار أولاً ثم السعر الافتراضي ──
                        Dim resolvedPrice As Decimal = prod.PurchasePrice  ' الافتراضي

                        ' هل يوجد مورد محدد على الفاتورة الحالية؟
                        If CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PartnerID.HasValue Then
                            Dim quotePrice = _purchaseQuoteService.GetProductPriceForPartner(
                                                CurrentInvoice.PartnerID.Value, detail.ProductID)
                            If quotePrice.HasValue AndAlso quotePrice.Value > 0 Then
                                resolvedPrice = quotePrice.Value  ' ← سعر عرض الأسعار
                            Else
                                ' ⚠️ الصنف غير مدرج في عرض أسعار هذا المورد — نُبلّغ المستخدم
                                RaiseEvent RequestSnackbar($"⚠️ الصنف [{prod.ProductName}] غير موجود في عرض أسعار المورد — تم استخدام سعر الشراء الافتراضي")
                            End If
                        End If

                        detail.UnitPrice = resolvedPrice
                        detail.Barcode = prod.Barcode
                        detail.ProductName = prod.ProductName
                        detail.ProductNameEn = prod.ProductNameEn
                        detail.UnitName = prod.UnitName
                    End If
                End If
            End If

            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse
               e.PropertyName = NameOf(InvoiceDetail.UnitPrice) OrElse
               e.PropertyName = NameOf(InvoiceDetail.TotalPrice) Then
                RecalculateTotals()
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
                Dim productList = _productService.GetProductsForPurchase()
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
                        If detail.UnitPrice = 0 Then detail.UnitPrice = matched.PurchasePrice
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
                            Dim newId = invService.QuickAddProduct(row.Barcode, row.ProductName, row.UnitPrice, 0)
                            
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

        Private Function CanExecuteExportPdf(parameter As Object) As Boolean
            Return CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.InvID > 0
        End Function

        Private Sub ExecuteExportPdf(parameter As Object)
            Try
                Dim reportData = _invoiceService.GetInvoiceForReport(CurrentInvoice.InvID)
                If reportData Is Nothing OrElse reportData.Header Is Nothing Then
                    RaiseEvent RequestSnackbar("⚠️ لا يمكن تحميل بيانات التصدير، تأكد من حفظ الفاتورة أولاً")
                    Return
                End If
                Helpers.ReportExporter.ExportInvoiceToPdf(reportData, isPurchase:=True)
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء تحضير التصدير: " & ex.Message, "خطأ",
                                               System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

    End Class
End Namespace
