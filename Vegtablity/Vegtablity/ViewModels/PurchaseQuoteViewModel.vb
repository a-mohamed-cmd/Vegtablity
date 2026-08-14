Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports System.Linq

Namespace ViewModels
    Public Class PurchaseQuoteViewModel
        Inherits BaseViewModel

        Private ReadOnly _quoteService As New PurchaseQuoteService()
        Private ReadOnly _partnerService As New PartnerService()
        Private ReadOnly _productService As New ProductService()
        Private _isUpdatingDetail As Boolean = False

        ' ── Pagination ─────────────────────────────────────────
        Private Const PAGE_SIZE As Integer = 20

        ' Master list — lives in memory, never cleared between pages
        Private _allDetails As New List(Of PurchaseQuoteDetail)()

        Private _detailsPage As Integer = 0
        Private _detailsTotalCount As Integer = 0

        Private _historyPage As Integer = 1
        Private _historyTotalCount As Integer = 0
        Private _historyPageSize As Integer = 20
        Private _historySearchText As String = ""

        ' ── Collections ────────────────────────────────────────
        Private _filteredPartners As ObservableCollection(Of Partner)
        Public Property FilteredPartners As ObservableCollection(Of Partner)
            Get
                Return _filteredPartners
            End Get
            Set(value As ObservableCollection(Of Partner))
                SetProperty(_filteredPartners, value)
            End Set
        End Property

        ' Loaded ONCE at startup — pagination is pure in-memory (no extra DB calls)
        Public Property Products As ObservableCollection(Of Product)
        Public Property QuotesHistory As ObservableCollection(Of PurchaseQuoteHeader)

        ' ── Events ─────────────────────────────────────────────
        Public Event RequestSnackbar As Action(Of String)
        Public Event InvoiceLoaded(partnerID As Integer?, partnerName As String)
        Public Event DetailsRefreshed As Action   ' triggers fade animation in View

        ' ── Date Texts ─────────────────────────────────────────
        Private _quoteDateText As String
        Public Property QuoteDateText As String
            Get
                Return _quoteDateText
            End Get
            Set(value As String)
                SetProperty(_quoteDateText, value)
            End Set
        End Property

        Private _expiryDateText As String
        Public Property ExpiryDateText As String
            Get
                Return _expiryDateText
            End Get
            Set(value As String)
                SetProperty(_expiryDateText, value)
            End Set
        End Property

        Public Sub SyncDateText()
            If CurrentQuote IsNot Nothing Then
                QuoteDateText = CurrentQuote.QuoteDate.ToString("dd/MM/yyyy")
                ExpiryDateText = If(CurrentQuote.ExpiryDate.HasValue,
                                    CurrentQuote.ExpiryDate.Value.ToString("dd/MM/yyyy"), "")
            End If
        End Sub

        ' ── Current Quote ───────────────────────────────────────
        Private _currentQuote As PurchaseQuoteHeader
        Public Property CurrentQuote As PurchaseQuoteHeader
            Get
                Return _currentQuote
            End Get
            Set(value As PurchaseQuoteHeader)
                If _currentQuote IsNot Nothing Then
                    RemoveHandler _currentQuote.PropertyChanged, AddressOf OnQuotePropertyChanged
                End If
                SetProperty(_currentQuote, value)
                If _currentQuote IsNot Nothing Then
                    AddHandler _currentQuote.PropertyChanged, AddressOf OnQuotePropertyChanged
                End If
            End Set
        End Property

        ' ── Commands ───────────────────────────────────────────
        Public Property SaveCommand As ICommand
        Public Property NewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property RemoveItemCommand As ICommand
        Public Property LoadHistoryCommand As ICommand
        Public Property EditQuoteCommand As ICommand
        Public Property AddItemByBarcodeCommand As ICommand
        Public Property NextDetailsPageCommand As ICommand
        Public Property PrevDetailsPageCommand As ICommand
        Public Property NextHistoryPageCommand As ICommand
        Public Property PrevHistoryPageCommand As ICommand
        Public Property ExportCsvCommand As ICommand
        Public Property ExportPdfCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand
        Public Property ImportFromExcelCommand As ICommand

        ' ── Barcode Search ─────────────────────────────────────
        Private _barcodeSearch As String = ""
        Public Property BarcodeSearch As String
            Get
                Return _barcodeSearch
            End Get
            Set(value As String)
                SetProperty(_barcodeSearch, value)
            End Set
        End Property

        ' ── History Pagination Properties ──────────────────────
        Public Property HistorySearchText As String
            Get
                Return _historySearchText
            End Get
            Set(value As String)
                SetProperty(_historySearchText, value)
                _historyPage = 1 ' Reset to page 1 on new search
                ExecuteLoadHistory(Nothing)
                OnPropertyChanged(NameOf(HistoryPageLabel))
            End Set
        End Property

        Public Property HistoryPage As Integer
            Get
                Return _historyPage
            End Get
            Set(value As Integer)
                If value < 1 Then value = 1
                SetProperty(_historyPage, value)
                ExecuteLoadHistory(Nothing)
                OnPropertyChanged(NameOf(HistoryPageLabel))
                OnPropertyChanged(NameOf(CanGoNextHistory))
                OnPropertyChanged(NameOf(CanGoPrevHistory))
            End Set
        End Property

        Public ReadOnly Property HistoryTotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(_historyTotalCount / _historyPageSize)))
            End Get
        End Property

        Public ReadOnly Property HistoryPageLabel As String
            Get
                Return $"صفحة {HistoryPage} من {HistoryTotalPages}"
            End Get
        End Property

        Public ReadOnly Property CanGoNextHistory As Boolean
            Get
                Return HistoryPage < HistoryTotalPages
            End Get
        End Property

        Public ReadOnly Property CanGoPrevHistory As Boolean
            Get
                Return HistoryPage > 1
            End Get
        End Property

        ' ── Details Pagination Properties ──────────────────────
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
                Return $"صفحة {_detailsPage + 1} من {DetailsTotalPages}"
            End Get
        End Property

        Public ReadOnly Property DetailsTotalCount As Integer
            Get
                Return _detailsTotalCount
            End Get
        End Property

        Public ReadOnly Property CanGoNextDetails As Boolean
            Get
                Return _detailsPage < DetailsTotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrevDetails As Boolean
            Get
                Return _detailsPage > 0
            End Get
        End Property

        ' ── Constructor ────────────────────────────────────────
        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                Return
            End If

            FilteredPartners = New ObservableCollection(Of Partner)()
            Products = New ObservableCollection(Of Product)()
            QuotesHistory = New ObservableCollection(Of PurchaseQuoteHeader)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)
            LoadHistoryCommand = New RelayCommand(AddressOf ExecuteLoadHistory)
            EditQuoteCommand = New RelayCommand(AddressOf ExecuteEditQuote)
            AddItemByBarcodeCommand = New RelayCommand(AddressOf ExecuteAddItemByBarcode)
            NextDetailsPageCommand = New RelayCommand(Sub() DetailsPage += 1, Function() CanGoNextDetails)
            PrevDetailsPageCommand = New RelayCommand(Sub() DetailsPage -= 1, Function() CanGoPrevDetails)
            NextHistoryPageCommand = New RelayCommand(Sub() HistoryPage += 1, Function() CanGoNextHistory)
            PrevHistoryPageCommand = New RelayCommand(Sub() HistoryPage -= 1, Function() CanGoPrevHistory)
            ExportCsvCommand = New RelayCommand(AddressOf ExecuteExportCsv, AddressOf CanExport)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanExport)
            DownloadTemplateCommand = New RelayCommand(AddressOf ExecuteDownloadTemplate)
            ImportFromExcelCommand = New RelayCommand(AddressOf ExecuteImportFromExcel)

            ' Load all lookups ONCE — products stay in memory
            LoadLookups()
            ExecuteNew(Nothing)
            LoadPermissions("PurchaseQuotes")
        End Sub

        ' ── LoadLookups: single DB call at startup ──────────────
        Private Sub LoadLookups()
            Try
                Dim settingsSvc As New Services.SettingsService()
                Dim compInfo = settingsSvc.GetCompanyInfo()
                Dim isUnified = If(compInfo IsNot Nothing, compInfo.UnifiedPartnerSearch, True)

                Dim results As System.Collections.Generic.List(Of Partner)
                If isUnified Then
                    results = _partnerService.SearchAllPartners("")
                Else
                    results = _partnerService.GetAllPartners("Supplier")
                End If
                FilteredPartners = New ObservableCollection(Of Partner)(results)

                ' ✅ تحميل الأصناف مرة واحدة فقط — لا استدعاء DB عند التنقل بين الصفحات
                Dim allProducts = _productService.GetProductsForPurchase()
                Products = New ObservableCollection(Of Product)(allProducts)
            Catch
            End Try
        End Sub

        Public Sub ApplyPartnerFilter(Optional searchText As String = "")
            Dim txt = searchText.Trim()
            Try
                Dim settingsSvc As New Services.SettingsService()
                Dim compInfo = settingsSvc.GetCompanyInfo()
                Dim isUnified = If(compInfo IsNot Nothing, compInfo.UnifiedPartnerSearch, True)
                
                Dim results As System.Collections.Generic.List(Of Partner)
                If isUnified Then
                    results = _partnerService.SearchAllPartners(txt)
                Else
                    results = _partnerService.SearchPartners("Supplier", txt)
                End If

                FilteredPartners = New ObservableCollection(Of Partner)(results)
                OnPropertyChanged(NameOf(FilteredPartners))
            Catch
            End Try
        End Sub

        ' ── UpdateDetailsPagination: pure in-memory slicing ────
        Private Sub UpdateDetailsPagination()
            If CurrentQuote Is Nothing Then Return

            _detailsTotalCount = _allDetails.Count

            ' Guard page bounds
            If _detailsPage >= DetailsTotalPages AndAlso DetailsTotalPages > 0 Then
                _detailsPage = DetailsTotalPages - 1
            End If

            Dim skip = _detailsPage * PAGE_SIZE
            Dim pageItems = _allDetails.Skip(skip).Take(PAGE_SIZE).ToList()

            CurrentQuote.Details.Clear()
            For Each d In pageItems
                CurrentQuote.Details.Add(d)
            Next

            OnPropertyChanged(NameOf(DetailsTotalPages))
            OnPropertyChanged(NameOf(DetailsPageLabel))
            OnPropertyChanged(NameOf(CanGoNextDetails))
            OnPropertyChanged(NameOf(CanGoPrevDetails))
            OnPropertyChanged(NameOf(DetailsTotalCount))

            ' Notify View to play fade animation
            RaiseEvent DetailsRefreshed()
        End Sub

        ' ── Commands Implementation ─────────────────────────────
        Private Sub ExecuteNew(parameter As Object)
            _allDetails.Clear()
            CurrentQuote = New PurchaseQuoteHeader() With {
                .QuoteDate = DateTime.Now,
                .Details = New ObservableCollection(Of PurchaseQuoteDetail)()
            }
            _detailsPage = 0
            _detailsTotalCount = 0
            UpdateDetailsPagination()
            SyncDateText()
            RaiseEvent InvoiceLoaded(Nothing, Nothing)
        End Sub

        Private Sub ExecuteLoadHistory(parameter As Object)
            Dim paged = _quoteService.GetQuotesPaged(HistoryPage, _historyPageSize, HistorySearchText)
            _historyTotalCount = paged.TotalCount
            
            QuotesHistory.Clear()
            If paged.Data IsNot Nothing Then
                For Each q In paged.Data
                    QuotesHistory.Add(q)
                Next
            End If
            
            OnPropertyChanged(NameOf(HistoryTotalPages))
            OnPropertyChanged(NameOf(HistoryPageLabel))
            OnPropertyChanged(NameOf(CanGoNextHistory))
            OnPropertyChanged(NameOf(CanGoPrevHistory))
        End Sub

        Private Sub ExecuteEditQuote(parameter As Object)
            Dim q = TryCast(parameter, PurchaseQuoteHeader)
            If q IsNot Nothing Then
                _allDetails.Clear()
                
                ' تحميل التفاصيل من قاعدة البيانات باستخدام SP الجديد
                Dim details = _quoteService.GetQuoteDetails(q.PurchaseQuoteID)
                If details IsNot Nothing Then
                    For Each d In details
                        AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                        _allDetails.Add(d)
                    Next
                End If
                
                CurrentQuote = q
                CurrentQuote.Details = New ObservableCollection(Of PurchaseQuoteDetail)()
                _detailsPage = 0
                UpdateDetailsPagination()
                SyncDateText()
                RaiseEvent InvoiceLoaded(CurrentQuote.PartnerID, CurrentQuote.PartnerName)
            End If
        End Sub

        Private Sub ExecuteAddItem(parameter As Object)
            Dim newItem = New PurchaseQuoteDetail()
            AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
            _allDetails.Add(newItem)

            ' Jump to last page so new row is visible
            Dim newPage = Math.Max(0, DetailsTotalPages - 1)
            If _detailsPage <> newPage Then
                DetailsPage = newPage
            Else
                UpdateDetailsPagination()
            End If
        End Sub

        Private Sub ExecuteAddItemByBarcode(parameter As Object)
            If String.IsNullOrWhiteSpace(BarcodeSearch) Then Return

            ' Search in-memory first (already loaded at startup)
            Dim found = Products.FirstOrDefault(Function(p) p.Barcode IsNot Nothing AndAlso
                                                             p.Barcode.Equals(BarcodeSearch.Trim(), StringComparison.OrdinalIgnoreCase))

            ' Fallback to DB only if not found in memory (e.g. new product added later)
            If found Is Nothing Then
                found = _productService.GetProductByBarcode(BarcodeSearch)
                If found IsNot Nothing Then Products.Add(found) ' cache it
            End If

            If found IsNot Nothing Then
                Dim newItem As New PurchaseQuoteDetail() With {
                    .ProductID = found.ProductID,
                    .Barcode = found.Barcode,
                    .ProductName = found.ProductName,
                    .UnitName = found.UnitName,
                    .UnitPrice = found.PurchasePrice,
                    .Quantity = 1
                }
                AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allDetails.Add(newItem)

                Dim newPage = Math.Max(0, DetailsTotalPages - 1)
                If _detailsPage <> newPage Then
                    DetailsPage = newPage
                Else
                    UpdateDetailsPagination()
                End If
                RaiseEvent RequestSnackbar($"✅ تمت إضافة: {found.ProductName}")
            Else
                RaiseEvent RequestSnackbar($"❌ لم يتم العثور على الصنف: {BarcodeSearch}")
            End If
            BarcodeSearch = ""
        End Sub

        Private Function CanExecuteRemoveItem(parameter As Object) As Boolean
            Return TryCast(parameter, PurchaseQuoteDetail) IsNot Nothing
        End Function

        Private Sub ExecuteRemoveItem(parameter As Object)
            Dim item = TryCast(parameter, PurchaseQuoteDetail)
            If item IsNot Nothing Then
                RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allDetails.Remove(item)
                If _detailsPage >= DetailsTotalPages AndAlso _detailsPage > 0 Then
                    DetailsPage = _detailsPage - 1
                Else
                    UpdateDetailsPagination()
                End If
            End If
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            Return CurrentQuote IsNot Nothing AndAlso
                   CurrentQuote.PartnerID > 0 AndAlso
                   _allDetails.Any(Function(d) d.ProductID > 0)
        End Function

        Private Sub ExecuteSave(parameter As Object)
            Try
                Dim finalDetails = _allDetails.Where(Function(d) d.ProductID > 0).ToList()
                If finalDetails.Count = 0 Then
                    RaiseEvent RequestSnackbar("⚠️ يجب إضافة صنف واحد على الأقل")
                    Return
                End If

                CurrentQuote.Details = New ObservableCollection(Of PurchaseQuoteDetail)(finalDetails)
                Dim id = _quoteService.SaveQuote(CurrentQuote)
                RaiseEvent RequestSnackbar("✅ تم حفظ عرض المشتريات بنجاح واعتماده!")
                ExecuteNew(Nothing)
            Catch ex As Exception
                System.Windows.MessageBox.Show(ex.Message, "خطأ في الحفظ")
            End Try
        End Sub

        ' ── Property Change Handlers ────────────────────────────
        Private Sub OnQuotePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If _isUpdatingDetail Then Return

            Dim detail = CType(sender, PurchaseQuoteDetail)

            ' Auto-fill from in-memory Products when ProductID changes (ComboBox selection)
            If e.PropertyName = NameOf(PurchaseQuoteDetail.ProductID) Then
                If detail.ProductID <= 0 Then Return
                Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod IsNot Nothing Then
                    _isUpdatingDetail = True
                    Try
                        detail.ProductName = prod.ProductName
                        detail.UnitName    = prod.UnitName
                        detail.UnitPrice   = prod.PurchasePrice
                        detail.Barcode     = prod.Barcode
                        If detail.Quantity <= 0 Then detail.Quantity = 1
                    Finally
                        _isUpdatingDetail = False
                    End Try
                End If
            End If

            CommandManager.InvalidateRequerySuggested()
        End Sub

        ' ── Export/Import Logic ────────────────────────────────
        Private Function CanExport(parameter As Object) As Boolean
            Return _allDetails IsNot Nothing AndAlso _allDetails.Any(Function(d) d.ProductID > 0)
        End Function

        Private Function GetCurrentSupplierName() As String
            If CurrentQuote Is Nothing OrElse CurrentQuote.PartnerID = 0 Then Return "مورد"
            Dim partner = FilteredPartners.FirstOrDefault(Function(p) p.PartnerID = CurrentQuote.PartnerID)
            Return If(partner IsNot Nothing, partner.PartnerName, "مورد")
        End Function

        Private Sub ExecuteExportCsv(parameter As Object)
            ' Ensure master details are sync'd to CurrentQuote for exporter
            CurrentQuote.Details = New ObservableCollection(Of PurchaseQuoteDetail)(_allDetails)
            Helpers.ReportExporter.ExportPurchaseQuoteToCsv(CurrentQuote, GetCurrentSupplierName())
            UpdateDetailsPagination()
        End Sub

        Private Sub ExecuteExportPdf(parameter As Object)
            CurrentQuote.Details = New ObservableCollection(Of PurchaseQuoteDetail)(_allDetails)
            Helpers.ReportExporter.ExportPurchaseQuoteToPdf(CurrentQuote, GetCurrentSupplierName())
            UpdateDetailsPagination()
        End Sub

        Private Sub ExecuteDownloadTemplate(parameter As Object)
            Helpers.ReportExporter.ExportPurchaseQuoteTemplate()
        End Sub

        Private Sub ExecuteImportFromExcel(parameter As Object)
            Dim imported = Helpers.ReportExporter.ImportPurchaseQuoteFromExcel(Products, _productService)
            If imported Is Nothing OrElse imported.Count = 0 Then Return

            ' Clear and load imported items
            _allDetails.Clear()
            For Each item In imported
                AddHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                _allDetails.Add(item)
            Next

            _detailsPage = 0
            UpdateDetailsPagination()
            RaiseEvent RequestSnackbar($"✅ تم استيراد {imported.Count} صنف بنجاح!")
        End Sub
    End Class
End Namespace
