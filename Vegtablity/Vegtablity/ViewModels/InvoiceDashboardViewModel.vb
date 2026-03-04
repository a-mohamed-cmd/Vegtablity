Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows.Threading
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers
Imports System.Windows.Input

Namespace ViewModels
    Public Class InvoiceDashboardViewModel
        Inherits BaseViewModel

        Private ReadOnly _invoiceService As InvoiceService
        Private ReadOnly _accountingService As AccountingService

        ' ── Debounce timer for search ──
        Private ReadOnly _searchDebounce As DispatcherTimer

        ' ── Events for View ──
        Public Event RequestOpenInvoice As Action(Of Integer, String) ' (InvID, InvType)
        Public Event RequestSnackbar As Action(Of String)

        ' ── Dashboard Stats ──
        Private _stats As DashboardStats
        Public Property Stats As DashboardStats
            Get
                Return _stats
            End Get
            Set(value As DashboardStats)
                SetProperty(_stats, value)
                OnPropertyChanged(NameOf(TotalSalesAmount))
                OnPropertyChanged(NameOf(TotalPurchaseAmount))
                OnPropertyChanged(NameOf(TotalSalesCount))
                OnPropertyChanged(NameOf(TotalPurchaseCount))
                OnPropertyChanged(NameOf(TotalSalesRemainder))
                OnPropertyChanged(NameOf(TotalPurchaseRemainder))
            End Set
        End Property
        Public ReadOnly Property TotalSalesAmount As String
            Get
                Return If(_stats IsNot Nothing, _stats.TotalSalesAmount.ToString("N2"), "0.00")
            End Get
        End Property
        Public ReadOnly Property TotalPurchaseAmount As String
            Get
                Return If(_stats IsNot Nothing, _stats.TotalPurchaseAmount.ToString("N2"), "0.00")
            End Get
        End Property
        Public ReadOnly Property TotalSalesCount As Integer
            Get
                Return If(_stats IsNot Nothing, _stats.TotalSalesCount, 0)
            End Get
        End Property
        Public ReadOnly Property TotalPurchaseCount As Integer
            Get
                Return If(_stats IsNot Nothing, _stats.TotalPurchaseCount, 0)
            End Get
        End Property
        Public ReadOnly Property TotalSalesRemainder As String
            Get
                Return If(_stats IsNot Nothing, _stats.SalesRemainder.ToString("N2"), "0.00")
            End Get
        End Property
        Public ReadOnly Property TotalPurchaseRemainder As String
            Get
                Return If(_stats IsNot Nothing, _stats.PurchaseRemainder.ToString("N2"), "0.00")
            End Get
        End Property

        ' ── Invoice List ──
        Public Property Invoices As ObservableCollection(Of InvoiceListItem)

        Private _selectedInvoice As InvoiceListItem
        Public Property SelectedInvoice As InvoiceListItem
            Get
                Return _selectedInvoice
            End Get
            Set(value As InvoiceListItem)
                SetProperty(_selectedInvoice, value)
                OnPropertyChanged(NameOf(CanShowPaymentPanel))
            End Set
        End Property

        ' ── Filters ──
        Private _filterType As String = "All"
        Public Property FilterType As String
            Get
                Return _filterType
            End Get
            Set(value As String)
                SetProperty(_filterType, value)
                CurrentPage = 0
                LoadInvoices()
            End Set
        End Property

        Private _filterStatus As String = "All"
        Public Property FilterStatus As String
            Get
                Return _filterStatus
            End Get
            Set(value As String)
                SetProperty(_filterStatus, value)
                CurrentPage = 0
                LoadInvoices()
            End Set
        End Property

        Private _searchText As String = ""
        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                SetProperty(_searchText, value)
                ' Reset debounce timer on each keystroke
                _searchDebounce.Stop()
                _searchDebounce.Start()
            End Set
        End Property

        ' ── Pagination ──
        Private Const PAGE_SIZE As Integer = 20

        Private _currentPage As Integer = 0
        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                SetProperty(_currentPage, value)
                OnPropertyChanged(NameOf(PageLabel))
                OnPropertyChanged(NameOf(CanGoNext))
                OnPropertyChanged(NameOf(CanGoPrev))
            End Set
        End Property

        Private _totalCount As Integer = 0
        Public Property TotalCount As Integer
            Get
                Return _totalCount
            End Get
            Set(value As Integer)
                SetProperty(_totalCount, value)
                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(PageLabel))
                OnPropertyChanged(NameOf(CanGoNext))
                OnPropertyChanged(NameOf(CanGoPrev))
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(TotalCount / PAGE_SIZE)))
            End Get
        End Property

        Public ReadOnly Property PageLabel As String
            Get
                Return $"صفحة {CurrentPage + 1} من {TotalPages}  ({TotalCount} فاتورة)"
            End Get
        End Property

        Public ReadOnly Property CanGoNext As Boolean
            Get
                Return CurrentPage < TotalPages - 1
            End Get
        End Property

        Public ReadOnly Property CanGoPrev As Boolean
            Get
                Return CurrentPage > 0
            End Get
        End Property

        ' ── Payment Panel ──
        Private _isPaymentPanelOpen As Boolean
        Public Property IsPaymentPanelOpen As Boolean
            Get
                Return _isPaymentPanelOpen
            End Get
            Set(value As Boolean)
                SetProperty(_isPaymentPanelOpen, value)
            End Set
        End Property

        Private _paymentAmount As Decimal
        Public Property PaymentAmount As Decimal
            Get
                Return _paymentAmount
            End Get
            Set(value As Decimal)
                SetProperty(_paymentAmount, value)
                OnPropertyChanged(NameOf(CanConfirmPayment))
            End Set
        End Property

        Private _paymentAccountID As Integer?
        Public Property PaymentAccountID As Integer?
            Get
                Return _paymentAccountID
            End Get
            Set(value As Integer?)
                SetProperty(_paymentAccountID, value)
                OnPropertyChanged(NameOf(CanConfirmPayment))
            End Set
        End Property

        Public Property CashAccounts As ObservableCollection(Of Account)

        Public ReadOnly Property CanShowPaymentPanel As Boolean
            Get
                Return SelectedInvoice IsNot Nothing AndAlso SelectedInvoice.CanAddPayment
            End Get
        End Property

        Public ReadOnly Property CanConfirmPayment As Boolean
            Get
                Return SelectedInvoice IsNot Nothing AndAlso
                       PaymentAmount > 0 AndAlso
                       PaymentAmount <= SelectedInvoice.Remainder AndAlso
                       PaymentAccountID.HasValue
            End Get
        End Property

        ' ── IsLoading ──
        Private _isLoading As Boolean
        Public Property IsLoading As Boolean
            Get
                Return _isLoading
            End Get
            Set(value As Boolean)
                SetProperty(_isLoading, value)
            End Set
        End Property

        ' ── Commands ──
        Public Property RefreshCommand As ICommand
        Public Property NextPageCommand As ICommand
        Public Property PrevPageCommand As ICommand
        Public Property OpenInvoiceCommand As ICommand
        Public Property ShowPaymentPanelCommand As ICommand
        Public Property ConfirmPaymentCommand As ICommand
        Public Property ClosePaymentPanelCommand As ICommand
        Public Property FilterTypeCommand As ICommand
        Public Property FilterStatusCommand As ICommand

        ' ── CurrentUserID ──
        Public Property CurrentUserID As Integer = 1

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then Return

            _invoiceService = New InvoiceService()
            _accountingService = New AccountingService()

            Invoices = New ObservableCollection(Of InvoiceListItem)()
            CashAccounts = New ObservableCollection(Of Account)()

            ' Debounce: wait 400ms after last keystroke before searching
            _searchDebounce = New DispatcherTimer() With {.Interval = TimeSpan.FromMilliseconds(400)}
            AddHandler _searchDebounce.Tick, Sub(s, e)
                                                 _searchDebounce.Stop()
                                                 CurrentPage = 0
                                                 LoadInvoices()
                                             End Sub

            RefreshCommand = New RelayCommand(Sub(p)
                                                 LoadStats()
                                                 LoadInvoices()
                                             End Sub)
            NextPageCommand = New RelayCommand(Sub(p)
                                                   If CanGoNext Then
                                                       CurrentPage += 1
                                                       LoadInvoices()
                                                   End If
                                               End Sub)
            PrevPageCommand = New RelayCommand(Sub(p)
                                                   If CanGoPrev Then
                                                       CurrentPage -= 1
                                                       LoadInvoices()
                                                   End If
                                               End Sub)
            FilterTypeCommand = New RelayCommand(Sub(p) FilterType = CStr(p))
            FilterStatusCommand = New RelayCommand(Sub(p) FilterStatus = CStr(p))
            OpenInvoiceCommand = New RelayCommand(AddressOf ExecuteOpenInvoice, Function(p) p IsNot Nothing)
            ShowPaymentPanelCommand = New RelayCommand(AddressOf ExecuteShowPayment, Function(p) CanShowPaymentPanel)
            ConfirmPaymentCommand = New RelayCommand(AddressOf ExecuteConfirmPayment, Function(p) CanConfirmPayment)
            ClosePaymentPanelCommand = New RelayCommand(Sub(p) IsPaymentPanelOpen = False)

            LoadCashAccounts()
            LoadStats()
            LoadInvoices()
        End Sub

        Private Sub LoadCashAccounts()
            Dim list = _accountingService.GetCashAccounts()
            CashAccounts.Clear()
            For Each a In list : CashAccounts.Add(a) : Next
        End Sub

        ''' <summary>Load KPI stats separately (only called on first load + manual refresh).</summary>
        Public Sub LoadStats()
            Try
                Stats = _invoiceService.GetDashboardStats()
            Catch ex As Exception
                RaiseEvent RequestSnackbar("❌ خطأ في الإحصائيات: " & ex.Message)
            End Try
        End Sub

        ''' <summary>Load paged invoice list (called on filter/search/page change).</summary>
        Public Sub LoadInvoices()
            Try
                IsLoading = True

                Dim invType = If(FilterType = "All", Nothing, FilterType)
                Dim isPosted As Boolean? = Nothing
                If FilterStatus = "Posted" Then isPosted = True
                If FilterStatus = "Draft" Then isPosted = False
                Dim search = If(String.IsNullOrWhiteSpace(SearchText), Nothing, SearchText.Trim())

                Dim result = _invoiceService.GetFilteredInvoices(
                    invType:=invType, isPosted:=isPosted, searchText:=search,
                    pageNumber:=CurrentPage, pageSize:=PAGE_SIZE)

                Invoices.Clear()
                For Each item In result.Items : Invoices.Add(item) : Next
                TotalCount = result.TotalCount

            Catch ex As Exception
                RaiseEvent RequestSnackbar("❌ " & ex.Message)
            Finally
                IsLoading = False
            End Try
        End Sub

        ' Keep old LoadData for backward compatibility
        Public Sub LoadData()
            LoadStats()
            LoadInvoices()
        End Sub

        Private Sub ExecuteOpenInvoice(parameter As Object)
            Dim item = TryCast(parameter, InvoiceListItem)
            If item Is Nothing AndAlso SelectedInvoice IsNot Nothing Then item = SelectedInvoice
            If item IsNot Nothing Then
                RaiseEvent RequestOpenInvoice(item.InvID, item.InvType)
            End If
        End Sub

        Private Sub ExecuteShowPayment(parameter As Object)
            Dim item = TryCast(parameter, InvoiceListItem)
            If item IsNot Nothing Then SelectedInvoice = item
            If SelectedInvoice Is Nothing OrElse Not SelectedInvoice.CanAddPayment Then Return
            PaymentAmount = 0
            PaymentAccountID = Nothing
            IsPaymentPanelOpen = True
        End Sub

        Private Sub ExecuteConfirmPayment(parameter As Object)
            If Not CanConfirmPayment Then Return
            Try
                Dim ok = _invoiceService.AddPayment(
                    SelectedInvoice.InvID, PaymentAmount, PaymentAccountID.Value, CurrentUserID)
                If ok Then
                    IsPaymentPanelOpen = False
                    RaiseEvent RequestSnackbar("✅ تم تسجيل السداد بنجاح")
                    LoadStats()
                    LoadInvoices()
                Else
                    RaiseEvent RequestSnackbar("❌ فشل تسجيل السداد")
                End If
            Catch ex As Exception
                RaiseEvent RequestSnackbar("❌ " & ex.Message)
            End Try
        End Sub
    End Class
End Namespace
