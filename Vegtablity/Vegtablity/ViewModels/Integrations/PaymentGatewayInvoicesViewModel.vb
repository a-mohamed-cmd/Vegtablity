Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Globalization
Imports System.Linq
Imports System.Windows
Imports Vegtablity.Helpers
Imports Vegtablity.Models
Imports Vegtablity.Models.Integrations
Imports Vegtablity.Services
Imports Vegtablity.Services.Integrations

Namespace ViewModels.Integrations

    ''' <summary>
    ''' ViewModel شاشة طلبات وفواتير بوابات الدفع الإلكتروني (تحت قسم المبيعات)
    ''' يدعم إصدار الروابط المفردة والمجمعة، الفلترة بالحالات، الترقيم السريع (Pagination)،
    ''' اختيار عميل مسجل أو إدخال عميل غير مسجل مع تعبئة الهاتف تلقائياً، وإرجاع المبالغ (Refund)
    ''' </summary>
    Public Class PaymentGatewayInvoicesViewModel
        Inherits BaseViewModel

        Private ReadOnly _integrationService As New IntegrationManagerService()
        Private ReadOnly _partnerService As New PartnerService()
        Private ReadOnly _permissionService As New PermissionService()

        Public Event CustomerSelectionSynced(partner As Partner, customName As String)
        Public Event RequestSnackbar(message As String, isError As Boolean)
        Public Event CreateDialogStateChanged(isOpen As Boolean)

        Public Property PaymentLinks As New ObservableCollection(Of PaymentLinkRecord)()
        Public Property ConfiguredGateways As New ObservableCollection(Of IntegrationProviderConfig)()

        ' === قائمة العملاء للـ SearchableDropdown (مع دعم عميل غير مسجل) ===
        Public Property AllCustomers As New List(Of Partner)()
        Private _filteredCustomers As New ObservableCollection(Of Partner)()
        Public Property FilteredCustomers As ObservableCollection(Of Partner)
            Get
                Return _filteredCustomers
            End Get
            Set(value As ObservableCollection(Of Partner))
                _filteredCustomers = value
                OnPropertyChanged()
            End Set
        End Property

        Private _selectedCustomer As Partner
        Public Property SelectedCustomer As Partner
            Get
                Return _selectedCustomer
            End Get
            Set(value As Partner)
                _selectedCustomer = value
                OnPropertyChanged()
                If value IsNot Nothing Then
                    _newPartnerId = value.PartnerID
                    _newCustomerName = value.PartnerName
                    OnPropertyChanged(NameOf(NewCustomerName))
                    If Not String.IsNullOrWhiteSpace(value.Phone) Then
                        NewCustomerPhone = value.Phone.Trim()
                    End If
                End If
            End Set
        End Property

        Private _newPartnerId As Integer?
        Public Property NewPartnerId As Integer?
            Get
                Return _newPartnerId
            End Get
            Set(value As Integer?)
                _newPartnerId = value
                OnPropertyChanged()
            End Set
        End Property

        ' === خيارات فلترة الحالات ===
        Public Property StatusFilterOptions As New ObservableCollection(Of PaymentLinkStatusFilterItem)()

        Private _selectedLink As PaymentLinkRecord
        Public Property SelectedLink As PaymentLinkRecord
            Get
                Return _selectedLink
            End Get
            Set(value As PaymentLinkRecord)
                _selectedLink = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(CanRefundSelected))
                If value IsNot Nothing Then
                    RefundAmountInput = value.RemainingRefundableAmount
                End If
            End Set
        End Property

        Private _selectedGatewayForNewLink As IntegrationProviderConfig
        Public Property SelectedGatewayForNewLink As IntegrationProviderConfig
            Get
                Return _selectedGatewayForNewLink
            End Get
            Set(value As IntegrationProviderConfig)
                _selectedGatewayForNewLink = value
                OnPropertyChanged()
            End Set
        End Property

        ' === الفلاتر (Filters) ===
        Private _filterProviderCode As String = "ALL"
        Public Property FilterProviderCode As String
            Get
                Return _filterProviderCode
            End Get
            Set(value As String)
                If _filterProviderCode <> value Then
                    _filterProviderCode = value
                    OnPropertyChanged()
                    _currentPage = 1
                    OnPropertyChanged(NameOf(CurrentPage))
                    LoadLinks()
                End If
            End Set
        End Property

        Private _filterStatus As String = "ALL"
        Public Property FilterStatus As String
            Get
                Return _filterStatus
            End Get
            Set(value As String)
                If _filterStatus <> value Then
                    _filterStatus = value
                    OnPropertyChanged()
                    _currentPage = 1
                    OnPropertyChanged(NameOf(CurrentPage))
                    LoadLinks()
                End If
            End Set
        End Property

        Private _searchText As String = ""
        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                _searchText = value
                OnPropertyChanged()
            End Set
        End Property

        ' === الترقيم (Server-Side Pagination) ===
        Private _currentPage As Integer = 1
        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                If value < 1 Then value = 1
                If _currentPage <> value Then
                    _currentPage = value
                    OnPropertyChanged()
                    LoadLinks()
                End If
            End Set
        End Property

        Private _pageSize As Integer = 20
        Public Property PageSize As Integer
            Get
                Return _pageSize
            End Get
            Set(value As Integer)
                If value < 5 Then value = 20
                If _pageSize <> value Then
                    _pageSize = value
                    OnPropertyChanged()
                    _currentPage = 1
                    OnPropertyChanged(NameOf(CurrentPage))
                    LoadLinks()
                End If
            End Set
        End Property

        Public Property PageSizeOptions As New ObservableCollection(Of Integer) From {15, 20, 50, 100}

        Private _totalRecordsCount As Integer = 0
        Public Property TotalRecordsCount As Integer
            Get
                Return _totalRecordsCount
            End Get
            Set(value As Integer)
                _totalRecordsCount = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(PageInfoText))
                OnPropertyChanged(NameOf(CanGoNextPage))
                OnPropertyChanged(NameOf(CanGoPrevPage))
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                If PageSize <= 0 Then Return 1
                Return Math.Max(1, CInt(Math.Ceiling(CDbl(TotalRecordsCount) / CDbl(PageSize))))
            End Get
        End Property

        Public ReadOnly Property PageInfoText As String
            Get
                Return $"صفحة {CurrentPage} من {TotalPages}  (إجمالي السجلات: {TotalRecordsCount})"
            End Get
        End Property

        Public ReadOnly Property CanGoPrevPage As Boolean
            Get
                Return CurrentPage > 1
            End Get
        End Property

        Public ReadOnly Property CanGoNextPage As Boolean
            Get
                Return CurrentPage < TotalPages
            End Get
        End Property

        ' === حقول إصدار رابط جديد (مفرد أو مجمع) ===
        Private _newInvId As Integer
        Public Property NewInvId As Integer
            Get
                Return _newInvId
            End Get
            Set(value As Integer)
                _newInvId = value
                OnPropertyChanged()
            End Set
        End Property

        Private _newAmount As Decimal
        Public Property NewAmount As Decimal
            Get
                Return _newAmount
            End Get
            Set(value As Decimal)
                _newAmount = value
                OnPropertyChanged()
            End Set
        End Property

        Private _newCustomerName As String = ""
        Public Property NewCustomerName As String
            Get
                Return _newCustomerName
            End Get
            Set(value As String)
                _newCustomerName = value
                OnPropertyChanged()
            End Set
        End Property

        Private _newCustomerPhone As String = ""
        Public Property NewCustomerPhone As String
            Get
                Return _newCustomerPhone
            End Get
            Set(value As String)
                _newCustomerPhone = value
                OnPropertyChanged()
            End Set
        End Property

        Private _isConsolidatedLink As Boolean = False
        Public Property IsConsolidatedLink As Boolean
            Get
                Return _isConsolidatedLink
            End Get
            Set(value As Boolean)
                _isConsolidatedLink = value
                OnPropertyChanged()
                If value AndAlso ConsolidatedItems.Count > 0 Then
                    RecalculateConsolidatedTotals()
                End If
            End Set
        End Property

        Public Property ConsolidatedItems As New ObservableCollection(Of ConsolidatedInvoiceItem)()

        Private _subInvIdInput As Integer
        Public Property SubInvIdInput As Integer
            Get
                Return _subInvIdInput
            End Get
            Set(value As Integer)
                _subInvIdInput = value
                OnPropertyChanged()
            End Set
        End Property

        Private _subInvAmountInput As Decimal
        Public Property SubInvAmountInput As Decimal
            Get
                Return _subInvAmountInput
            End Get
            Set(value As Decimal)
                _subInvAmountInput = value
                OnPropertyChanged()
            End Set
        End Property

        Private _consolidatedCsv As String = ""
        Public Property ConsolidatedCsv As String
            Get
                Return _consolidatedCsv
            End Get
            Set(value As String)
                _consolidatedCsv = value
                OnPropertyChanged()
            End Set
        End Property

        ' === Create Link Popup & Refund Dialog State ===
        Private _isCreateLinkDialogOpen As Boolean = False
        Public Property IsCreateLinkDialogOpen As Boolean
            Get
                Return _isCreateLinkDialogOpen
            End Get
            Set(value As Boolean)
                If _isCreateLinkDialogOpen <> value Then
                    _isCreateLinkDialogOpen = value
                    OnPropertyChanged()
                    RaiseEvent CreateDialogStateChanged(value)
                End If
            End Set
        End Property

        Private _isRefundDialogOpen As Boolean = False
        Public Property IsRefundDialogOpen As Boolean
            Get
                Return _isRefundDialogOpen
            End Get
            Set(value As Boolean)
                _isRefundDialogOpen = value
                OnPropertyChanged()
            End Set
        End Property

        Private _refundAmountInput As Decimal
        Public Property RefundAmountInput As Decimal
            Get
                Return _refundAmountInput
            End Get
            Set(value As Decimal)
                _refundAmountInput = value
                OnPropertyChanged()
            End Set
        End Property

        Private _refundReasonInput As String = "بناءً على طلب العميل"
        Public Property RefundReasonInput As String
            Get
                Return _refundReasonInput
            End Get
            Set(value As String)
                _refundReasonInput = value
                OnPropertyChanged()
            End Set
        End Property

        ' === KPI Summaries (من السيرفر لجميع السجلات المطابقة للفلتر) ===
        Private _summaryPaidAmount As Decimal = 0D
        Private _summaryPendingAmount As Decimal = 0D
        Private _summaryRefundedAmount As Decimal = 0D

        Public ReadOnly Property TotalPaidAmount As Decimal
            Get
                Return _summaryPaidAmount
            End Get
        End Property

        Public ReadOnly Property TotalPendingAmount As Decimal
            Get
                Return _summaryPendingAmount
            End Get
        End Property

        Public ReadOnly Property TotalRefundedAmount As Decimal
            Get
                Return _summaryRefundedAmount
            End Get
        End Property

        Public ReadOnly Property PaymentLinksCount As Integer
            Get
                Return If(PaymentLinks IsNot Nothing, PaymentLinks.Count, 0)
            End Get
        End Property

        ''' <summary>
        ''' يتحكم في صلاحية المستخدم الحالي لإرجاع مبالغ بوابات الدفع الإلكتروني
        ''' </summary>
        Public ReadOnly Property CanCurrentUserRefund As Boolean
            Get
                Return Session.CurrentUser IsNot Nothing AndAlso Session.CurrentUser.CanRefundPaymentGateway
            End Get
        End Property

        ''' <summary>
        ''' يتحكم في إظهار زر إرجاع المبلغ العام في الشريط العلوي إذا كانت هناك أي بوابة مفعل بها خيار الإرجاع ويمتلك المستخدم الصلاحية
        ''' </summary>
        Public ReadOnly Property IsRefundFeatureEnabledInAnyGateway As Boolean
            Get
                Return CanCurrentUserRefund AndAlso ConfiguredGateways.Any(Function(g) g.EnableGatewayRefunds)
            End Get
        End Property

        Public ReadOnly Property CanRefundSelected As Boolean
            Get
                Return CanCurrentUserRefund AndAlso SelectedLink IsNot Nothing AndAlso SelectedLink.CanRefund
            End Get
        End Property

        ' === Commands ===
        Public Property SearchCommand As RelayCommand
        Public Property FilterByStatusCommand As RelayCommand
        Public Property OpenCreateLinkDialogCommand As RelayCommand
        Public Property CloseCreateLinkDialogCommand As RelayCommand
        Public Property CreatePaymentLinkCommand As RelayCommand
        Public Property AddConsolidatedItemCommand As RelayCommand
        Public Property RemoveConsolidatedItemCommand As RelayCommand
        Public Property RefreshStatusCommand As RelayCommand
        Public Property SendWhatsAppCommand As RelayCommand
        Public Property PrintQr80mmCommand As RelayCommand
        Public Property PrintQr58mmCommand As RelayCommand
        Public Property PrintQrWpfCommand As RelayCommand
        Public Property OpenRefundDialogCommand As RelayCommand
        Public Property ConfirmRefundCommand As RelayCommand
        Public Property CancelRefundDialogCommand As RelayCommand

        ' Pagination Commands
        Public Property FirstPageCommand As RelayCommand
        Public Property PrevPageCommand As RelayCommand
        Public Property NextPageCommand As RelayCommand
        Public Property LastPageCommand As RelayCommand

        Public Sub New()
            InitializeStatusFilters()

            SearchCommand = New RelayCommand(Sub(o)
                                                 _currentPage = 1
                                                 OnPropertyChanged(NameOf(CurrentPage))
                                                 LoadLinks()
                                             End Sub)
            FilterByStatusCommand = New RelayCommand(Sub(o)
                                                         Dim st = TryCast(o, String)
                                                         If Not String.IsNullOrWhiteSpace(st) Then
                                                             FilterStatus = st
                                                         End If
                                                     End Sub)
            OpenCreateLinkDialogCommand = New RelayCommand(Sub(o)
                                                               If ConfiguredGateways IsNot Nothing AndAlso SelectedGatewayForNewLink Is Nothing Then
                                                                   SelectedGatewayForNewLink = ConfiguredGateways.FirstOrDefault()
                                                               End If
                                                               IsCreateLinkDialogOpen = True
                                                           End Sub)
            CloseCreateLinkDialogCommand = New RelayCommand(Sub(o) IsCreateLinkDialogOpen = False)
            CreatePaymentLinkCommand = New RelayCommand(AddressOf ExecuteCreatePaymentLink)
            AddConsolidatedItemCommand = New RelayCommand(AddressOf ExecuteAddConsolidatedItem)
            RemoveConsolidatedItemCommand = New RelayCommand(AddressOf ExecuteRemoveConsolidatedItem)
            RefreshStatusCommand = New RelayCommand(AddressOf ExecuteRefreshStatus)
            SendWhatsAppCommand = New RelayCommand(AddressOf ExecuteSendWhatsApp)
            PrintQr80mmCommand = New RelayCommand(Sub(o) ExecutePrintQr(o, "80mm"))
            PrintQr58mmCommand = New RelayCommand(Sub(o) ExecutePrintQr(o, "58mm"))
            PrintQrWpfCommand = New RelayCommand(Sub(o) ExecutePrintQr(o, "WPF"))
            OpenRefundDialogCommand = New RelayCommand(AddressOf ExecuteOpenRefundDialog)
            ConfirmRefundCommand = New RelayCommand(AddressOf ExecuteConfirmRefund)
            CancelRefundDialogCommand = New RelayCommand(Sub(o) IsRefundDialogOpen = False)

            FirstPageCommand = New RelayCommand(Sub(o) CurrentPage = 1, Function(o) CanGoPrevPage)
            PrevPageCommand = New RelayCommand(Sub(o) If CanGoPrevPage Then CurrentPage -= 1, Function(o) CanGoPrevPage)
            NextPageCommand = New RelayCommand(Sub(o) If CanGoNextPage Then CurrentPage += 1, Function(o) CanGoNextPage)
            LastPageCommand = New RelayCommand(Sub(o) CurrentPage = TotalPages, Function(o) CanGoNextPage)

            LoadCustomers()
            LoadGatewaysAndLinks()
        End Sub

        Private Sub InitializeStatusFilters()
            StatusFilterOptions.Clear()
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "ALL", .TitleAr = "📋 الكل"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Pending", .TitleAr = "⏳ بانتظار الدفع"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Paid", .TitleAr = "✅ مدفوع (Paid)"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "PartiallyRefunded", .TitleAr = "↩️ مسترد جزئياً"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Refunded", .TitleAr = "↩️ مسترد بالكامل"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Failed", .TitleAr = "❌ فشل الدفع"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Expired", .TitleAr = "⌛ منتهي الصلاحية"})
            StatusFilterOptions.Add(New PaymentLinkStatusFilterItem With {.StatusCode = "Cancelled", .TitleAr = "🚫 ملغي"})
        End Sub

        Public Sub LoadCustomers()
            Try
                Dim list = _partnerService.GetAllPartners("Customer")
                If list Is Nothing OrElse list.Count = 0 Then
                    list = _partnerService.SearchAllPartners("")
                End If
                AllCustomers = If(list, New List(Of Partner)())
                FilteredCustomers = New ObservableCollection(Of Partner)(AllCustomers)
            Catch
                AllCustomers = New List(Of Partner)()
                FilteredCustomers = New ObservableCollection(Of Partner)()
            End Try
        End Sub

        ''' <summary>
        ''' فلترة العملاء أثناء الكتابة في SearchableDropdown مع حفظ النص المكتوب في حال كان العميل غير مسجل
        ''' </summary>
        Public Sub ApplyCustomerFilter(searchText As String)
            Dim trimmed = If(searchText, "").Trim()

            ' إذا لم يكن هناك عميل مسجل مختار حالياً، اعتبر النص المكتوب هو اسم العميل (يدعم العميل غير المسجل)
            If SelectedCustomer Is Nothing Then
                _newPartnerId = Nothing
                _newCustomerName = trimmed
                OnPropertyChanged(NameOf(NewCustomerName))
            End If

            If String.IsNullOrWhiteSpace(trimmed) Then
                FilteredCustomers = New ObservableCollection(Of Partner)(AllCustomers)
                Return
            End If

            Dim lower = trimmed.ToLowerInvariant()
            Dim matches = AllCustomers.Where(Function(p)
                                                 Return (p.PartnerName IsNot Nothing AndAlso p.PartnerName.ToLowerInvariant().Contains(lower)) OrElse
                                                        (p.Phone IsNot Nothing AndAlso p.Phone.Contains(trimmed)) OrElse
                                                        (p.AccountCode IsNot Nothing AndAlso p.AccountCode.Contains(trimmed))
                                             End Function).ToList()
            FilteredCustomers = New ObservableCollection(Of Partner)(matches)
        End Sub

        ''' <summary>
        ''' عند اختيار عميل مسجل من القائمة المنسدلة يتم تعبئة الاسم ورقم الهاتف تلقائياً
        ''' </summary>
        Public Sub OnCustomerSelected(partner As Partner)
            If partner Is Nothing Then Return
            SelectedCustomer = partner
        End Sub

        ''' <summary>
        ''' جلب بيانات الفاتورة تلقائياً (المبلغ المتبقي والعميل والهاتف) عند إدخال رقم الفاتورة
        ''' </summary>
        Public Sub TryAutoFillFromInvoice(invId As Integer)
            If invId <= 0 Then Return
            Dim info = _integrationService.GetInvoiceQuickInfo(invId)
            If Not info.Found Then Return

            If NewAmount <= 0D AndAlso info.Amount > 0D Then
                NewAmount = info.Amount
            End If

            If info.PartnerID.HasValue AndAlso info.PartnerID.Value > 0 Then
                Dim matched = AllCustomers.FirstOrDefault(Function(c) c.PartnerID = info.PartnerID.Value)
                If matched IsNot Nothing Then
                    SelectedCustomer = matched
                    RaiseEvent CustomerSelectionSynced(matched, matched.PartnerName)
                    Return
                End If
            End If

            If Not String.IsNullOrWhiteSpace(info.PartnerName) AndAlso String.IsNullOrWhiteSpace(NewCustomerName) Then
                NewCustomerName = info.PartnerName
                If Not String.IsNullOrWhiteSpace(info.PartnerPhone) Then
                    NewCustomerPhone = info.PartnerPhone
                End If
                RaiseEvent CustomerSelectionSynced(Nothing, info.PartnerName)
            End If
        End Sub

        ''' <summary>
        ''' جلب مبلغ الفاتورة الفرعية تلقائياً عند إدخال رقمها في وضع الرابط المجمع
        ''' </summary>
        Public Sub TryAutoFillSubInvoiceAmount(invId As Integer)
            If invId <= 0 Then Return
            Dim info = _integrationService.GetInvoiceQuickInfo(invId)
            If info.Found AndAlso info.Amount > 0D Then
                SubInvAmountInput = info.Amount
            End If
        End Sub

        Private Sub ExecuteAddConsolidatedItem(obj As Object)
            If SubInvIdInput <= 0 OrElse SubInvAmountInput <= 0D Then
                RaiseEvent RequestSnackbar("⚠️ يرجى إدخال رقم الفاتورة الفرعية ومبلغها لإضافتها للرابط المجمّع.", True)
                Return
            End If

            Dim existing = ConsolidatedItems.FirstOrDefault(Function(x) x.InvID = SubInvIdInput)
            If existing IsNot Nothing Then
                ConsolidatedItems.Remove(existing)
            End If

            ConsolidatedItems.Add(New ConsolidatedInvoiceItem With {
                .InvID = SubInvIdInput,
                .Amount = SubInvAmountInput
            })

            If NewInvId <= 0 Then
                NewInvId = SubInvIdInput
                TryAutoFillFromInvoice(SubInvIdInput)
            End If

            SubInvIdInput = 0
            SubInvAmountInput = 0D
            RecalculateConsolidatedTotals()
        End Sub

        Private Sub ExecuteRemoveConsolidatedItem(obj As Object)
            Dim item = TryCast(obj, ConsolidatedInvoiceItem)
            If item Is Nothing Then Return
            ConsolidatedItems.Remove(item)
            RecalculateConsolidatedTotals()
        End Sub

        Private Sub RecalculateConsolidatedTotals()
            If ConsolidatedItems.Count > 0 Then
                NewAmount = ConsolidatedItems.Sum(Function(x) x.Amount)
                ConsolidatedCsv = String.Join(",", ConsolidatedItems.Select(Function(x) $"{x.InvID}:{x.Amount.ToString("0.###", CultureInfo.InvariantCulture)}"))
                If NewInvId <= 0 Then
                    NewInvId = ConsolidatedItems.First().InvID
                End If
            Else
                ConsolidatedCsv = ""
            End If
        End Sub

        Public Sub RefreshCurrentUserPermission()
            Try
                If Session.CurrentUser IsNot Nothing Then
                    Dim perm = _permissionService.GetPermissionsForForm(Session.CurrentUser.RoleID, "PaymentGatewayInvoices")
                    Session.CurrentUser.CanRefundPaymentGateway = (perm IsNot Nothing AndAlso perm.CanDelete)
                End If
            Catch
            End Try
            OnPropertyChanged(NameOf(CanCurrentUserRefund))
            OnPropertyChanged(NameOf(IsRefundFeatureEnabledInAnyGateway))
            OnPropertyChanged(NameOf(CanRefundSelected))
        End Sub

        Public Sub LoadGatewaysAndLinks()
            Try
                RefreshCurrentUserPermission()
                ConfiguredGateways.Clear()
                Dim list = _integrationService.GetProviders(onlyEnabled:=True).Where(Function(p) p.IsPaymentGateway AndAlso p.IsConfigured).ToList()
                For Each g In list
                    ConfiguredGateways.Add(g)
                Next
                SelectedGatewayForNewLink = ConfiguredGateways.FirstOrDefault()
                OnPropertyChanged(NameOf(CanCurrentUserRefund))
                OnPropertyChanged(NameOf(IsRefundFeatureEnabledInAnyGateway))
                OnPropertyChanged(NameOf(CanRefundSelected))
                LoadLinks()
            Catch
            End Try
        End Sub

        Public Sub LoadLinks()
            Try
                PaymentLinks.Clear()
                Dim rows = _integrationService.GetFilteredPaymentLinks(
                    providerCode:=FilterProviderCode,
                    status:=FilterStatus,
                    searchText:=SearchText,
                    pageNumber:=CurrentPage,
                    pageSize:=PageSize
                )

                If rows IsNot Nothing AndAlso rows.Count > 0 Then
                    Dim first = rows(0)
                    TotalRecordsCount = If(first.TotalRecordsCount > 0, first.TotalRecordsCount, rows.Count)
                    _summaryPaidAmount = first.SummaryPaidAmount
                    _summaryPendingAmount = first.SummaryPendingAmount
                    _summaryRefundedAmount = first.SummaryRefundedAmount
                    For Each r In rows
                        PaymentLinks.Add(r)
                    Next
                Else
                    TotalRecordsCount = 0
                    _summaryPaidAmount = 0D
                    _summaryPendingAmount = 0D
                    _summaryRefundedAmount = 0D
                End If

                OnPropertyChanged(NameOf(TotalPaidAmount))
                OnPropertyChanged(NameOf(TotalPendingAmount))
                OnPropertyChanged(NameOf(TotalRefundedAmount))
                OnPropertyChanged(NameOf(PaymentLinksCount))
                OnPropertyChanged(NameOf(PageInfoText))
                OnPropertyChanged(NameOf(CanGoNextPage))
                OnPropertyChanged(NameOf(CanGoPrevPage))
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            Catch
            End Try
        End Sub

        Private Async Sub ExecuteCreatePaymentLink(obj As Object)
            If SelectedGatewayForNewLink Is Nothing Then
                RaiseEvent RequestSnackbar("⚠️ يرجى إعداد وتفعيل بوابة دفع واحدة على الأقل (واختبار اتصالها) من شاشة إعدادات الربط أولاً.", True)
                Return
            End If

            If IsConsolidatedLink AndAlso ConsolidatedItems.Count > 0 Then
                RecalculateConsolidatedTotals()
            End If

            If NewInvId <= 0 OrElse NewAmount <= 0D Then
                RaiseEvent RequestSnackbar("⚠️ يرجى إدخال رقم الفاتورة والمبلغ المطلوب تحصيله قبل إصدار الرابط.", True)
                Return
            End If

            Dim finalCustomerName As String = If(SelectedCustomer IsNot Nothing, SelectedCustomer.PartnerName, NewCustomerName)
            If String.IsNullOrWhiteSpace(finalCustomerName) Then
                finalCustomerName = "عميل نقدي"
            End If

            Dim req As New PaymentLinkRequest With {
                .InvID = NewInvId,
                .PartnerID = If(SelectedCustomer IsNot Nothing, CType(SelectedCustomer.PartnerID, Integer?), NewPartnerId),
                .ProviderID = SelectedGatewayForNewLink.ProviderID,
                .ProviderCode = SelectedGatewayForNewLink.ProviderCode,
                .Amount = NewAmount,
                .CurrencyCode = SelectedGatewayForNewLink.DefaultCurrency,
                .CustomerName = finalCustomerName,
                .CustomerPhone = NewCustomerPhone,
                .SendViaWhatsApp = SelectedGatewayForNewLink.AutoSendWhatsApp,
                .SendViaSms = SelectedGatewayForNewLink.AutoSendSms,
                .IsConsolidated = IsConsolidatedLink,
                .ConsolidatedInvoicesCsv = ConsolidatedCsv
            }

            Dim res = Await _integrationService.CreateAndSavePaymentLinkAsync(SelectedGatewayForNewLink, req)
            If res.Success Then
                _currentPage = 1
                OnPropertyChanged(NameOf(CurrentPage))
                LoadLinks()

                ' طباعة نموذج فاتورة WPF A4 إذا كان الخيار مفعلاً (الكود الخاص بـ 80mm و 58mm محفوظ دون تفعيله من شاشة WPF)
                If res.Record IsNot Nothing Then
                    If False AndAlso SelectedGatewayForNewLink.PrintQrOnPos80mm Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(res.Record.InvID, res.Record.CustomerName, res.Record.Amount, res.Record.CurrencyCode, SelectedGatewayForNewLink.ProviderNameAr, res.Record.PaymentUrl, "80mm")
                    End If
                    If False AndAlso SelectedGatewayForNewLink.PrintQrOnPos58mm Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(res.Record.InvID, res.Record.CustomerName, res.Record.Amount, res.Record.CurrencyCode, SelectedGatewayForNewLink.ProviderNameAr, res.Record.PaymentUrl, "58mm")
                    End If
                    If SelectedGatewayForNewLink.PrintQrOnWpfInvoice Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(res.Record.InvID, res.Record.CustomerName, res.Record.Amount, res.Record.CurrencyCode, SelectedGatewayForNewLink.ProviderNameAr, res.Record.PaymentUrl, "WPF")
                    End If
                End If

                ' تفريغ الحقول وإغلاق نافذة الإصدار بعد الإنشاء الناجح
                NewInvId = 0
                NewAmount = 0D
                SelectedCustomer = Nothing
                NewPartnerId = Nothing
                NewCustomerName = ""
                NewCustomerPhone = ""
                SubInvIdInput = 0
                SubInvAmountInput = 0D
                ConsolidatedItems.Clear()
                ConsolidatedCsv = ""
                RaiseEvent CustomerSelectionSynced(Nothing, "")
                IsCreateLinkDialogOpen = False

                RaiseEvent RequestSnackbar(res.MessageAr, False)
            Else
                RaiseEvent RequestSnackbar(res.MessageAr, True)
            End If
        End Sub

        Private Async Sub ExecuteRefreshStatus(obj As Object)
            Dim target As PaymentLinkRecord = TryCast(obj, PaymentLinkRecord)
            If target Is Nothing Then target = SelectedLink
            If target Is Nothing Then Return

            Dim res = Await _integrationService.RefreshPaymentLinkStatusWithFeedbackAsync(target)
            LoadLinks()
            RaiseEvent RequestSnackbar(res.MessageAr, Not res.Success)
        End Sub

        Private Sub ExecuteSendWhatsApp(obj As Object)
            Dim target As PaymentLinkRecord = TryCast(obj, PaymentLinkRecord)
            If target Is Nothing Then target = SelectedLink
            If target Is Nothing Then Return

            _integrationService.SendPaymentLinkViaWhatsApp(target.DisplayCustomerPhone, target.DisplayCustomerName, target.InvID, target.Amount, target.CurrencyCode, target.PaymentUrl)
        End Sub

        Private Sub ExecutePrintQr(obj As Object, mode As String)
            Dim target As PaymentLinkRecord = TryCast(obj, PaymentLinkRecord)
            If target Is Nothing Then target = SelectedLink
            If target Is Nothing Then Return

            _integrationService.QrService.PrintPaymentLinkReceipt(target.InvID, target.DisplayCustomerName, target.Amount, target.CurrencyCode, target.ProviderNameAr, target.PaymentUrl, mode)
        End Sub

        Private Sub ExecuteOpenRefundDialog(obj As Object)
            If Not CanCurrentUserRefund Then
                RaiseEvent RequestSnackbar("⚠️ عذراً، لا تملك صلاحية استرداد مبالغ بوابات الدفع الإلكتروني.", True)
                Return
            End If

            Dim target As PaymentLinkRecord = TryCast(obj, PaymentLinkRecord)
            If target IsNot Nothing Then SelectedLink = target
            If SelectedLink Is Nothing Then Return

            If Not SelectedLink.CanRefund Then
                RaiseEvent RequestSnackbar("⚠️ لا يمكن استرداد هذا الرابط (إما أن صلاحية الإرجاع معطلة في إعدادات البوابة أو أن الرابط غير مدفوع).", True)
                Return
            End If

            RefundAmountInput = SelectedLink.RemainingRefundableAmount
            RefundReasonInput = "إرجاع مبلغ للعميل"
            IsRefundDialogOpen = True
        End Sub

        Private Async Sub ExecuteConfirmRefund(obj As Object)
            If Not CanCurrentUserRefund Then
                RaiseEvent RequestSnackbar("⚠️ عذراً، لا تملك صلاحية استرداد مبالغ بوابات الدفع الإلكتروني.", True)
                Return
            End If
            If SelectedLink Is Nothing Then Return
            If RefundAmountInput <= 0D OrElse RefundAmountInput > SelectedLink.RemainingRefundableAmount Then
                RaiseEvent RequestSnackbar($"⚠️ يرجى إدخال مبلغ استرداد صحيح لا يتجاوز المبلغ القابل للاسترداد ({SelectedLink.RemainingRefundableAmount:N3}).", True)
                Return
            End If

            If Not SelectedLink.AllowPartialRefunds AndAlso RefundAmountInput < SelectedLink.RemainingRefundableAmount Then
                RaiseEvent RequestSnackbar("⚠️ الاسترداد الجزئي غير مفعل لهذه البوابة؛ يجب استرداد كامل المبلغ المتبقي.", True)
                Return
            End If

            Dim currentUserId As Integer = Session.CurrentUser.UserID
            Dim res As PaymentRefundResult = Await _integrationService.RefundPaymentLinkAsync(SelectedLink, RefundAmountInput, RefundReasonInput, currentUserId)
            If res.IsSuccess Then
                IsRefundDialogOpen = False
                LoadLinks()
                RaiseEvent RequestSnackbar(res.MessageAr, False)
            Else
                RaiseEvent RequestSnackbar(res.MessageAr, True)
            End If
        End Sub

    End Class

End Namespace
