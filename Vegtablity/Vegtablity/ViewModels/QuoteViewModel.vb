Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class QuoteViewModel
        Inherits BaseViewModel

        Private ReadOnly _quoteService As QuoteService
        Private ReadOnly _partnerService As PartnerService
        Private ReadOnly _productService As ProductService

        Public Property Customers As ObservableCollection(Of Partner)
        Public Property Products As ObservableCollection(Of Product)
        Public Property QuotesHistory As ObservableCollection(Of QuoteHeader)

        Public Event RequestSnackbar As Action(Of String)

        Private _currentQuote As QuoteHeader
        Public Property CurrentQuote As QuoteHeader
            Get
                Return _currentQuote
            End Get
            Set(value As QuoteHeader)
                If _currentQuote IsNot Nothing Then
                    RemoveHandler _currentQuote.PropertyChanged, AddressOf OnQuotePropertyChanged
                End If
                SetProperty(_currentQuote, value)
                If _currentQuote IsNot Nothing Then
                    AddHandler _currentQuote.PropertyChanged, AddressOf OnQuotePropertyChanged
                End If
            End Set
        End Property

        Public Property SaveCommand As ICommand
        Public Property NewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property RemoveItemCommand As ICommand
        Public Property LoadHistoryCommand As ICommand
        Public Property EditQuoteCommand As ICommand
        
        Public Property NextProductPageCommand As ICommand
        Public Property PrevProductPageCommand As ICommand
        Public Property NextHistoryPageCommand As ICommand
        Public Property PrevHistoryPageCommand As ICommand
        Public Property NextDetailsPageCommand As ICommand
        Public Property PrevDetailsPageCommand As ICommand
        Public Property AddItemByBarcodeCommand As ICommand
        Public Property ExportCsvCommand As ICommand
        Public Property ExportPdfCommand As ICommand
        Public Property ImportFromExcelCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand
        
        ' --- Pagination ---
        Private Const PAGE_SIZE As Integer = 20
        
        ' Products Pagination
        Private _productPage As Integer = 0
        Private _productTotalCount As Integer = 0
        Private _selectedProductsMap As New Dictionary(Of Integer, Product)()
        
        ' History Pagination
        Private _historyPage As Integer = 0
        Private _historyTotalCount As Integer = 0
        
        ' Details Pagination
        Private _detailsPage As Integer = 0
        Private _detailsTotalCount As Integer = 0

        ' Master list for the current quote to preserve items across pages
        Private _allQuoteDetails As New ObservableCollection(Of QuoteDetail)()

        Public Property ProductPage As Integer
            Get
                Return _productPage
            End Get
            Set(value As Integer)
                SetProperty(_productPage, value)
                UpdateProductPagination()
                OnPropertyChanged(NameOf(ProductPageLabel))
                OnPropertyChanged(NameOf(CanGoNextProduct))
                OnPropertyChanged(NameOf(CanGoPrevProduct))
            End Set
        End Property

        Public ReadOnly Property ProductTotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(CDbl(_productTotalCount) / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property ProductPageLabel As String
            Get
                Return $"صفحة {ProductPage + 1} من {ProductTotalPages}"
            End Get
        End Property

        Public ReadOnly Property CanGoNextProduct As Boolean
            Get
                Return ProductPage < ProductTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevProduct As Boolean
            Get
                Return ProductPage > 0
            End Get
        End Property

        ' History Properties
        Public Property HistoryPage As Integer
            Get
                Return _historyPage
            End Get
            Set(value As Integer)
                SetProperty(_historyPage, value)
                UpdateHistoryPagination()
                OnPropertyChanged(NameOf(HistoryPageLabel))
                OnPropertyChanged(NameOf(CanGoNextHistory))
                OnPropertyChanged(NameOf(CanGoPrevHistory))
            End Set
        End Property

        Public ReadOnly Property HistoryTotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(_historyTotalCount / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property HistoryPageLabel As String
            Get
                Return $"صفحة {HistoryPage + 1} من {HistoryTotalPages}"
            End Get
        End Property

        Public ReadOnly Property CanGoNextHistory As Boolean
            Get
                Return HistoryPage < HistoryTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevHistory As Boolean
            Get
                Return HistoryPage > 0
            End Get
        End Property

        ' Details Properties
        Public Property DetailsPage As Integer
            Get
                Return _detailsPage
            End Get
            Set(value As Integer)
                SetProperty(_detailsPage, value)
                UpdateDetailsPagination()
                OnPropertyChanged(NameOf(DetailsPageLabel))
                OnPropertyChanged(NameOf(CanGoNextDetails))
                OnPropertyChanged(NameOf(CanGoPrevDetails))
            End Set
        End Property

        Public ReadOnly Property DetailsTotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(CDbl(_detailsTotalCount) / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property DetailsPageLabel As String
            Get
                Return $"صفحة {DetailsPage + 1} من {DetailsTotalPages}"
            End Get
        End Property

        Public ReadOnly Property CanGoNextDetails As Boolean
            Get
                If CurrentQuote Is Nothing OrElse CurrentQuote.QuoteID = 0 Then Return False
                Return DetailsPage < DetailsTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevDetails As Boolean
            Get
                Return DetailsPage > 0
            End Get
        End Property

        Private _historySearch As String = ""
        Public Property HistorySearch As String
            Get
                Return _historySearch
            End Get
            Set(value As String)
                If SetProperty(_historySearch, value) Then
                    HistoryPage = 0
                    ' No need to call update here as HistoryPage setter does it
                End If
            End Set
        End Property

        Private _barcodeSearch As String = ""
        Public Property BarcodeSearch As String
            Get
                Return _barcodeSearch
            End Get
            Set(value As String)
                SetProperty(_barcodeSearch, value)
            End Set
        End Property

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                Return
            End If

            _quoteService = New QuoteService()
            _partnerService = New PartnerService()
            _productService = New ProductService()

            Customers = New ObservableCollection(Of Partner)()
            Products = New ObservableCollection(Of Product)()
            QuotesHistory = New ObservableCollection(Of QuoteHeader)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)
            LoadHistoryCommand = New RelayCommand(AddressOf ExecuteLoadHistory)
            EditQuoteCommand = New RelayCommand(AddressOf ExecuteEditQuote)
            AddItemByBarcodeCommand = New RelayCommand(AddressOf ExecuteAddItemByBarcode)
            ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv, AddressOf CanExport)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanExport)
            ImportFromExcelCommand = New RelayCommand(AddressOf ExecuteImportFromExcel)
            DownloadTemplateCommand = New RelayCommand(AddressOf ExecuteDownloadTemplate)
            
            NextProductPageCommand = New RelayCommand(Sub() ProductPage += 1, Function() CanGoNextProduct)
            PrevProductPageCommand = New RelayCommand(Sub() ProductPage -= 1, Function() CanGoPrevProduct)
            NextHistoryPageCommand = New RelayCommand(Sub() HistoryPage += 1, Function() CanGoNextHistory)
            PrevHistoryPageCommand = New RelayCommand(Sub() HistoryPage -= 1, Function() CanGoPrevHistory)

            NextDetailsPageCommand = New RelayCommand(Sub() DetailsPage += 1, Function() CanGoNextDetails)
            PrevDetailsPageCommand = New RelayCommand(Sub() DetailsPage -= 1, Function() CanGoPrevDetails)

            LoadLookups()
            ExecuteNew(Nothing)
            LoadPermissions("Quotes")
        End Sub

        Private Sub LoadLookups()
            Dim customerList = _partnerService.GetAllPartners("Customer")
            Customers.Clear()
            For Each c In customerList
                Customers.Add(c)
            Next

            ProductPage = 0
            UpdateProductPagination()
        End Sub

        Private _productFilter As String = ""
        Public Property ProductFilter As String
            Get
                Return _productFilter
            End Get
            Set(value As String)
                If SetProperty(_productFilter, value) Then
                    ProductPage = 0
                    UpdateProductPagination()
                End If
            End Set
        End Property

        Public Function GlobalFindProduct(term As String) As Product
            If String.IsNullOrWhiteSpace(term) Then Return Nothing
            ' Perform a specialized paged search for 1 item to find it globally
            Dim paged = _productService.GetProductsPaged(1, 1, term)
            Return paged.Data.FirstOrDefault()
        End Function

        Public Sub SearchProducts(term As String)
            ProductFilter = term
        End Sub

        Private Sub UpdateProductPagination()
            If Products Is Nothing Then Return
            
            ' Fetch from DB
            Dim paged = _productService.GetProductsPaged(ProductPage + 1, PAGE_SIZE, ProductFilter)
            _productTotalCount = paged.TotalCount
            
            ' Which IDs are currently in use?
            Dim usedIds As New HashSet(Of Integer)()
            If CurrentQuote IsNot Nothing AndAlso CurrentQuote.Details IsNot Nothing Then
                For Each d In CurrentQuote.Details
                    If d.ProductID > 0 Then 
                        usedIds.Add(d.ProductID)
                    End If
                Next
            End If
            
            Products.Clear()
            ' 1. Add page items
            For Each p In paged.Data
                Products.Add(p)
                usedIds.Remove(p.ProductID) ' Mark as added
                ' Cache for detail lookup/preservation
                If Not _selectedProductsMap.ContainsKey(p.ProductID) Then
                    _selectedProductsMap(p.ProductID) = p
                End If
            Next
            
            ' 2. Add remaining used items from cache (to avoid blank ComboBoxes)
            For Each id In usedIds
                If _selectedProductsMap.ContainsKey(id) Then
                    Products.Add(_selectedProductsMap(id))
                End If
            Next
            
            OnPropertyChanged(NameOf(Products))
            OnPropertyChanged(NameOf(ProductTotalPages))
            OnPropertyChanged(NameOf(ProductPageLabel))
        End Sub

        Private Sub UpdateHistoryPagination()
            If QuotesHistory Is Nothing Then Return
            
            Dim partnerId As Integer? = Nothing
            If CurrentQuote IsNot Nothing AndAlso CurrentQuote.PartnerID > 0 Then
                partnerId = CurrentQuote.PartnerID
            End If

            Dim paged = _quoteService.GetQuotesPaged(HistoryPage + 1, PAGE_SIZE, HistorySearch, partnerId)
            _historyTotalCount = paged.TotalCount

            QuotesHistory.Clear()
            For Each q In paged.Data
                QuotesHistory.Add(q)
            Next
            
            OnPropertyChanged(NameOf(QuotesHistory))
            OnPropertyChanged(NameOf(HistoryTotalPages))
            OnPropertyChanged(NameOf(HistoryPageLabel))
        End Sub

        Private Sub ExecuteLoadHistory(parameter As Object)
            _historyPage = 0 ' Set backing field
            UpdateHistoryPagination() ' Force refresh
            OnPropertyChanged(NameOf(HistoryPage))
            OnPropertyChanged(NameOf(HistoryPageLabel))
            OnPropertyChanged(NameOf(CanGoNextHistory))
            OnPropertyChanged(NameOf(CanGoPrevHistory))
        End Sub

        Private Sub ExecuteNew(parameter As Object)
            CurrentQuote = New QuoteHeader() With {
                .QuoteDate = DateTime.Now,
                .ExpiryDate = DateTime.Now.AddMonths(1),
                .IsActive = True,
                .Details = New ObservableCollection(Of QuoteDetail)()
            }
            _allQuoteDetails.Clear()
        End Sub

        Private Sub UpdateDetailsPagination()
            If CurrentQuote Is Nothing Then Return
            
            Try
                _detailsTotalCount = _allQuoteDetails.Count
                
                Dim skip = DetailsPage * PAGE_SIZE
                Dim pageItems = _allQuoteDetails.Skip(skip).Take(PAGE_SIZE).ToList()
                
                CurrentQuote.Details.Clear()
                For Each d In pageItems
                    CurrentQuote.Details.Add(d)
                Next
                
                OnPropertyChanged(NameOf(DetailsTotalPages))
                OnPropertyChanged(NameOf(DetailsPageLabel))
                OnPropertyChanged(NameOf(CanGoNextDetails))
                OnPropertyChanged(NameOf(CanGoPrevDetails))
                UpdateProductPagination()
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ في تحديث صفحات العرض: " & ex.Message, "خطأ")
            End Try
        End Sub

        Private Sub ExecuteEditQuote(parameter As Object)
            Dim q = TryCast(parameter, QuoteHeader)
            If q IsNot Nothing Then
                Try
                    ' Initial load of ALL items to ensure no data is lost during pagination/saving
                    _detailsPage = 0
                    Dim paged = _quoteService.GetQuoteDetails(q.QuoteID, 1, 10000) ' Fetch all
                    _detailsTotalCount = paged.Data.Count
                    
                    _allQuoteDetails.Clear()
                    For Each d In paged.Data
                        If Not _selectedProductsMap.ContainsKey(d.ProductID) Then
                            Dim prodRes = _productService.GetProductsPaged(1, 1, d.ProductID.ToString())
                            Dim prod = prodRes.Data.FirstOrDefault(Function(x) x.ProductID = d.ProductID)
                            If prod IsNot Nothing Then _selectedProductsMap(d.ProductID) = prod
                        End If
                        
                        AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                        _allQuoteDetails.Add(d)
                    Next
                    
                    CurrentQuote = q
                    UpdateDetailsPagination()
                    
                    OnPropertyChanged(NameOf(DetailsPage))
                    OnPropertyChanged(NameOf(DetailsPageLabel))
                    OnPropertyChanged(NameOf(CanGoNextDetails))
                    OnPropertyChanged(NameOf(CanGoPrevDetails))
                Catch ex As Exception
                    System.Windows.MessageBox.Show(ex.Message, "Error loading details")
                End Try
            End If
        End Sub

        ''' <summary>
        ''' Public entry-point called by PartnersPage code-behind after navigating here.
        ''' Loads the given QuoteHeader for editing, exactly like double-clicking in the history grid.
        ''' </summary>
        Public Sub LoadQuoteForEditing(q As QuoteHeader)
            ExecuteEditQuote(q)
        End Sub

        Private Sub OnQuotePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(QuoteHeader.PartnerID) Then
                HistoryPage = 0
                UpdateHistoryPagination()
            End If
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            If CurrentQuote Is Nothing Then Return False
            If CurrentQuote.PartnerID = 0 Then Return False
            If CurrentQuote.Details Is Nothing OrElse CurrentQuote.Details.Count = 0 Then Return False
            Return True
        End Function

        Private Sub ExecuteSave(parameter As Object)
            Try
                ' Clean empty rows
                Dim emptyRows = _allQuoteDetails.Where(Function(d) d.ProductID = 0).ToList()
                For Each row In emptyRows
                    _allQuoteDetails.Remove(row)
                Next

                If _allQuoteDetails.Count = 0 Then
                    System.Windows.MessageBox.Show("يجب إضافة صنف واحد على الأقل لحفظ عرض السعر.", "تحذير", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                    Return
                End If

                CurrentQuote.Details = New ObservableCollection(Of QuoteDetail)(_allQuoteDetails)
                _quoteService.SaveQuote(CurrentQuote)
                RaiseEvent RequestSnackbar("✅ تم حفظ عرض السعر بنجاح واعتماده للعميل!")
                ExecuteLoadHistory(Nothing)
                ExecuteNew(Nothing)
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanExport(parameter As Object) As Boolean
            Return CurrentQuote IsNot Nothing AndAlso
                   CurrentQuote.Details IsNot Nothing AndAlso
                   CurrentQuote.Details.Count > 0
        End Function

        Private Function GetCurrentCustomerName() As String
            Dim partner = Customers.FirstOrDefault(Function(c) c.PartnerID = CurrentQuote.PartnerID)
            Return If(partner IsNot Nothing, partner.PartnerName, "عميل")
        End Function

        Private Sub ExecuteExportCsv(parameter As Object)
            ReportExporter.ExportQuoteToCsv(CurrentQuote, GetCurrentCustomerName())
        End Sub

        Private Sub ExecuteExportPdf(parameter As Object)
            ReportExporter.ExportQuoteToPdf(CurrentQuote, GetCurrentCustomerName())
        End Sub

        Private Sub ExecuteDownloadTemplate(parameter As Object)
            Helpers.ReportExporter.ExportQuoteTemplate()
        End Sub

        Private Sub ExecuteImportFromExcel(parameter As Object)
            Dim imported = Helpers.ReportExporter.ImportQuoteFromExcel(Products)
            If imported Is Nothing Then Return ' user cancelled

            If imported.Count = 0 Then
                System.Windows.MessageBox.Show("لم يتم العثور على أي أصناف قابلة للاستيراد في الملف.", "تنبيه",
                                               System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                Return
            End If

            ' Clear blank placeholder rows first
            Dim emptyRows = _allQuoteDetails.Where(Function(d) d.ProductID = 0 AndAlso Not d.IsUnmatched).ToList()
            For Each row In emptyRows
                _allQuoteDetails.Remove(row)
            Next

            ' Add imported rows with PropertyChanged wired
            Dim unmatchedCount As Integer = 0
            For Each d In imported
                AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allQuoteDetails.Add(d)
                If d.IsUnmatched Then unmatchedCount += 1
            Next

            DetailsPage = Math.Max(0, DetailsTotalPages - 1)

            Dim msg As String = $"✅ تم استيراد {imported.Count} صنف بنجاح."
            If unmatchedCount > 0 Then
                msg &= $" ⚠️ {unmatchedCount} صنف غير معروف (مميز باللون الأحمر) — يرجى مراجعته وحذفه أو تصحيحه."
            End If
            RaiseEvent RequestSnackbar(msg)
        End Sub

        Private Sub ExecuteAddItem(parameter As Object)
            Dim newItem = New QuoteDetail() With {.QuotedPrice = 0}
            AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
            _allQuoteDetails.Add(newItem)
            
            Dim newPage = Math.Max(0, DetailsTotalPages - 1)
            If DetailsPage <> newPage Then
                DetailsPage = newPage
            Else
                UpdateDetailsPagination()
            End If
        End Sub

        Private Sub ExecuteAddItemByBarcode(parameter As Object)
            If String.IsNullOrWhiteSpace(BarcodeSearch) Then Return

            ' Search globally
            Dim found = GlobalFindProduct(BarcodeSearch)

            If found IsNot Nothing Then
                ' Check if already added
                Dim existing = _allQuoteDetails.FirstOrDefault(Function(d) d.ProductID = found.ProductID)
                If existing IsNot Nothing Then
                    RaiseEvent RequestSnackbar($"⚠️ الصنف ({found.ProductName}) مضاف بالفعل في جدول العرض")
                Else
                    ' Cache it
                    _selectedProductsMap(found.ProductID) = found
                    
                    Dim newItem As New QuoteDetail() With {
                        .ProductID = found.ProductID,
                        .Barcode = found.Barcode,
                        .UnitName = found.UnitName,
                        .QuotedPrice = found.SalePrice
                    }
                    AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
                    _allQuoteDetails.Add(newItem)
                    
                    Dim newPage = Math.Max(0, DetailsTotalPages - 1)
                    If DetailsPage <> newPage Then
                        DetailsPage = newPage
                    Else
                        UpdateDetailsPagination()
                    End If
                    RaiseEvent RequestSnackbar($"✅ تمت إضافة الصنف: {found.ProductName}")
                End If
            Else
                RaiseEvent RequestSnackbar($"❌ لم يُعثر على صنف بهذا الكود: {BarcodeSearch}")
            End If

            BarcodeSearch = "" ' Clear search box
        End Sub

        Private Function CanExecuteRemoveItem(parameter As Object) As Boolean
            Dim item = TryCast(parameter, QuoteDetail)
            Return item IsNot Nothing
        End Function

        Private Sub ExecuteRemoveItem(parameter As Object)
            Dim item = TryCast(parameter, QuoteDetail)
            If item IsNot Nothing Then
                RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allQuoteDetails.Remove(item)
                
                If DetailsPage >= DetailsTotalPages AndAlso DetailsPage > 0 Then
                    DetailsPage -= 1
                Else
                    UpdateDetailsPagination()
                End If
            End If
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            Dim detail = CType(sender, QuoteDetail)
            
            If e.PropertyName = NameOf(QuoteDetail.ProductID) Then
                ' Default the quote price to the global standard sale price on first select
                Dim prod As Product = Nothing
                If _selectedProductsMap.TryGetValue(detail.ProductID, prod) Then
                    detail.QuotedPrice = prod.SalePrice
                    detail.Barcode = prod.Barcode
                    detail.UnitName = prod.UnitName
                End If
            End If
            
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

    End Class
End Namespace
