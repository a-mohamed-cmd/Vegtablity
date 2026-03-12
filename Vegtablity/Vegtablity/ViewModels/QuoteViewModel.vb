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
        Public Property AddItemByBarcodeCommand As ICommand
        Public Property ExportCsvCommand As ICommand
        Public Property ExportPdfCommand As ICommand
        Public Property ImportFromExcelCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand

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

            Dim productList = _productService.GetAllProducts()
            Products.Clear()
            For Each p In productList
                Products.Add(p)
            Next
        End Sub

        Private Sub ExecuteLoadHistory(parameter As Object)
            Try
                Dim list = _quoteService.GetAllQuotes()
                QuotesHistory.Clear()
                For Each q In list
                    QuotesHistory.Add(q)
                Next
            Catch ex As Exception
                System.Windows.MessageBox.Show(ex.Message, "Error fetching history")
            End Try
        End Sub

        Private Sub ExecuteNew(parameter As Object)
            CurrentQuote = New QuoteHeader() With {
                .QuoteDate = DateTime.Now,
                .ExpiryDate = DateTime.Now.AddMonths(1),
                .IsActive = True,
                .Details = New ObservableCollection(Of QuoteDetail)()
            }
            ExecuteAddItem(Nothing)
        End Sub

        Private Sub ExecuteEditQuote(parameter As Object)
            Dim q = TryCast(parameter, QuoteHeader)
            If q IsNot Nothing Then
                Try
                    ' Reload full details from DB
                    Dim fullDetails = _quoteService.GetQuoteDetails(q.QuoteID)
                    q.Details.Clear()
                    For Each d In fullDetails
                        AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                        q.Details.Add(d)
                    Next
                    CurrentQuote = q
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
                Dim emptyRows = CurrentQuote.Details.Where(Function(d) d.ProductID = 0).ToList()
                For Each row In emptyRows
                    CurrentQuote.Details.Remove(row)
                Next

                If CurrentQuote.Details.Count = 0 Then
                    System.Windows.MessageBox.Show("يجب إضافة صنف واحد على الأقل لحفظ عرض السعر.", "تحذير", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                    Return
                End If

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
            Dim emptyRows = CurrentQuote.Details.Where(Function(d) d.ProductID = 0 AndAlso Not d.IsUnmatched).ToList()
            For Each row In emptyRows
                CurrentQuote.Details.Remove(row)
            Next

            ' Add imported rows with PropertyChanged wired
            Dim unmatchedCount As Integer = 0
            For Each d In imported
                AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                CurrentQuote.Details.Add(d)
                If d.IsUnmatched Then unmatchedCount += 1
            Next

            Dim msg As String = $"✅ تم استيراد {imported.Count} صنف بنجاح."
            If unmatchedCount > 0 Then
                msg &= $" ⚠️ {unmatchedCount} صنف غير معروف (مميز باللون الأحمر) — يرجى مراجعته وحذفه أو تصحيحه."
            End If
            RaiseEvent RequestSnackbar(msg)
        End Sub

        Private Sub ExecuteAddItem(parameter As Object)
            Dim newItem = New QuoteDetail() With {.QuotedPrice = 0}
            AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
            CurrentQuote.Details.Add(newItem)
        End Sub

        Private Sub ExecuteAddItemByBarcode(parameter As Object)
            If String.IsNullOrWhiteSpace(BarcodeSearch) Then Return

            Dim searchLower = BarcodeSearch.Trim().ToLower()

            ' Search by exact barcode first, then by name contains
            Dim found = Products.FirstOrDefault(Function(p)
                                                    Return (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchLower) OrElse
                                                           (p.SearchText IsNot Nothing AndAlso p.SearchText.ToLower().Contains(searchLower))
                                                End Function)

            If found IsNot Nothing Then
                ' Check if already added
                Dim existing = CurrentQuote.Details.FirstOrDefault(Function(d) d.ProductID = found.ProductID)
                If existing IsNot Nothing Then
                    RaiseEvent RequestSnackbar($"⚠️ الصنف ({found.ProductName}) مضاف بالفعل في جدول العرض")
                Else
                    Dim newItem As New QuoteDetail() With {
                        .ProductID = found.ProductID,
                        .Barcode = found.Barcode,
                        .UnitName = found.UnitName,
                        .QuotedPrice = found.SalePrice
                    }
                    AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
                    CurrentQuote.Details.Add(newItem)
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
                CurrentQuote.Details.Remove(item)
            End If
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            Dim detail = CType(sender, QuoteDetail)
            
            If e.PropertyName = NameOf(QuoteDetail.ProductID) Then
                ' Default the quote price to the global standard sale price on first select
                Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod IsNot Nothing Then
                    detail.QuotedPrice = prod.SalePrice
                    detail.Barcode = prod.Barcode
                    detail.UnitName = prod.UnitName
                End If
            End If
            
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

    End Class
End Namespace
