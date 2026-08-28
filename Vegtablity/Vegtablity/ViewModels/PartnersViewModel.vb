Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class PartnersViewModel
        Inherits BaseViewModel

        Private ReadOnly _partnerService As New Services.PartnerService()
        Private ReadOnly _quoteService As New Services.QuoteService()
        Private ReadOnly _purchaseQuoteService As New Services.PurchaseQuoteService()

        ' ===== Customers =====
        Private _customers As ObservableCollection(Of Partner)
        Private _selectedCustomer As Partner
        Private _isEditingCustomer As Boolean
        Private _customerSearchText As String

        Private _editCustomerName As String
        Private _editCustomerPhone As String
        Private _editCustomerAddress As String
        Private _customerNameError As String
        Private _customerStatusMessage As String
        Private _isCustomerPanelVisible As Boolean

        ' ===== Suppliers =====
        Private _suppliers As ObservableCollection(Of Partner)
        Private _selectedSupplier As Partner
        Private _isEditingSupplier As Boolean
        Private _supplierSearchText As String

        Private _editSupplierName As String
        Private _editSupplierPhone As String
        Private _editSupplierAddress As String
        Private _supplierNameError As String
        Private _supplierStatusMessage As String
        Private _isSupplierPanelVisible As Boolean

        ' ===== Customer Quotes Panel =====
        Private _customerQuotes As ObservableCollection(Of QuoteHeader)
        Private _isQuotesPanelOpen As Boolean
        Private _quotePanelCustomerName As String

        ''' <summary>Raised when the user clicks a quote — View navigates to QuotePage with that quote.</summary>
        Public Event RequestNavigateToQuote As Action(Of QuoteHeader)
        Public Event RequestNavigateToPurchaseQuote As Action(Of PurchaseQuoteHeader)

        Public Sub New()
            LoadPermissions("Partners")
            LoadCustomers()
            LoadSuppliers()
        End Sub

#Region "Properties - Customers"
        Public Property Customers As ObservableCollection(Of Partner)
            Get
                Return _customers
            End Get
            Set(value As ObservableCollection(Of Partner))
                SetProperty(_customers, value)
            End Set
        End Property

        Public Property SelectedCustomer As Partner
            Get
                Return _selectedCustomer
            End Get
            Set(value As Partner)
                SetProperty(_selectedCustomer, value)
                If value IsNot Nothing Then
                    EditCustomerName = value.PartnerName
                    EditCustomerPhone = value.Phone
                    EditCustomerAddress = value.Address
                    IsEditingCustomer = True
                    CustomerNameError = Nothing
                    IsCustomerPanelVisible = True
                End If
            End Set
        End Property

        Public Property IsCustomerPanelVisible As Boolean
            Get
                Return _isCustomerPanelVisible
            End Get
            Set(value As Boolean)
                SetProperty(_isCustomerPanelVisible, value)
            End Set
        End Property

        Public Property IsEditingCustomer As Boolean
            Get
                Return _isEditingCustomer
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingCustomer, value)
            End Set
        End Property

        Public Property CustomerSearchText As String
            Get
                Return _customerSearchText
            End Get
            Set(value As String)
                SetProperty(_customerSearchText, value)
                If String.IsNullOrWhiteSpace(value) Then
                    LoadCustomers()
                Else
                    SearchCustomers()
                End If
            End Set
        End Property

        Public Property EditCustomerName As String
            Get
                Return _editCustomerName
            End Get
            Set(value As String)
                SetProperty(_editCustomerName, value)
                If Not String.IsNullOrEmpty(value) Then CustomerNameError = Nothing
            End Set
        End Property

        Public Property EditCustomerPhone As String
            Get
                Return _editCustomerPhone
            End Get
            Set(value As String)
                SetProperty(_editCustomerPhone, value)
            End Set
        End Property

        Public Property EditCustomerAddress As String
            Get
                Return _editCustomerAddress
            End Get
            Set(value As String)
                SetProperty(_editCustomerAddress, value)
            End Set
        End Property

        Public Property CustomerNameError As String
            Get
                Return _customerNameError
            End Get
            Set(value As String)
                SetProperty(_customerNameError, value)
            End Set
        End Property

        Public Property CustomerStatusMessage As String
            Get
                Return _customerStatusMessage
            End Get
            Set(value As String)
                SetProperty(_customerStatusMessage, value)
            End Set
        End Property

        Public Property CustomerQuotes As ObservableCollection(Of QuoteHeader)
            Get
                Return _customerQuotes
            End Get
            Set(value As ObservableCollection(Of QuoteHeader))
                SetProperty(_customerQuotes, value)
            End Set
        End Property

        Public Property IsQuotesPanelOpen As Boolean
            Get
                Return _isQuotesPanelOpen
            End Get
            Set(value As Boolean)
                SetProperty(_isQuotesPanelOpen, value)
            End Set
        End Property

        Public Property QuotePanelCustomerName As String
            Get
                Return _quotePanelCustomerName
            End Get
            Set(value As String)
                SetProperty(_quotePanelCustomerName, value)
            End Set
        End Property
#End Region

#Region "Properties - Suppliers"
        Public Property Suppliers As ObservableCollection(Of Partner)
            Get
                Return _suppliers
            End Get
            Set(value As ObservableCollection(Of Partner))
                SetProperty(_suppliers, value)
            End Set
        End Property

        Public Property SelectedSupplier As Partner
            Get
                Return _selectedSupplier
            End Get
            Set(value As Partner)
                SetProperty(_selectedSupplier, value)
                If value IsNot Nothing Then
                    EditSupplierName = value.PartnerName
                    EditSupplierPhone = value.Phone
                    EditSupplierAddress = value.Address
                    IsEditingSupplier = True
                    SupplierNameError = Nothing
                    IsSupplierPanelVisible = True
                End If
            End Set
        End Property

        Public Property IsSupplierPanelVisible As Boolean
            Get
                Return _isSupplierPanelVisible
            End Get
            Set(value As Boolean)
                SetProperty(_isSupplierPanelVisible, value)
            End Set
        End Property

        Public Property IsEditingSupplier As Boolean
            Get
                Return _isEditingSupplier
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingSupplier, value)
            End Set
        End Property

        Public Property SupplierSearchText As String
            Get
                Return _supplierSearchText
            End Get
            Set(value As String)
                SetProperty(_supplierSearchText, value)
                If String.IsNullOrWhiteSpace(value) Then
                    LoadSuppliers()
                Else
                    SearchSuppliers()
                End If
            End Set
        End Property

        Public Property EditSupplierName As String
            Get
                Return _editSupplierName
            End Get
            Set(value As String)
                SetProperty(_editSupplierName, value)
                If Not String.IsNullOrEmpty(value) Then SupplierNameError = Nothing
            End Set
        End Property

        Public Property EditSupplierPhone As String
            Get
                Return _editSupplierPhone
            End Get
            Set(value As String)
                SetProperty(_editSupplierPhone, value)
            End Set
        End Property

        Public Property EditSupplierAddress As String
            Get
                Return _editSupplierAddress
            End Get
            Set(value As String)
                SetProperty(_editSupplierAddress, value)
            End Set
        End Property

        Public Property SupplierNameError As String
            Get
                Return _supplierNameError
            End Get
            Set(value As String)
                SetProperty(_supplierNameError, value)
            End Set
        End Property

        Public Property SupplierStatusMessage As String
            Get
                Return _supplierStatusMessage
            End Get
            Set(value As String)
                SetProperty(_supplierStatusMessage, value)
            End Set
        End Property

        Private _supplierQuotes As ObservableCollection(Of PurchaseQuoteHeader)
        Public Property SupplierQuotes As ObservableCollection(Of PurchaseQuoteHeader)
            Get
                Return _supplierQuotes
            End Get
            Set(value As ObservableCollection(Of PurchaseQuoteHeader))
                SetProperty(_supplierQuotes, value)
            End Set
        End Property

        Private _isSupplierQuotesPanelOpen As Boolean
        Public Property IsSupplierQuotesPanelOpen As Boolean
            Get
                Return _isSupplierQuotesPanelOpen
            End Get
            Set(value As Boolean)
                SetProperty(_isSupplierQuotesPanelOpen, value)
            End Set
        End Property

        Private _quotePanelSupplierName As String
        Public Property QuotePanelSupplierName As String
            Get
                Return _quotePanelSupplierName
            End Get
            Set(value As String)
                SetProperty(_quotePanelSupplierName, value)
            End Set
        End Property
#End Region

#Region "Commands - Customers"
        Public ReadOnly Property SaveCustomerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveCustomer)
            End Get
        End Property

        Public ReadOnly Property NewCustomerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewCustomer)
            End Get
        End Property

        Public ReadOnly Property DeleteCustomerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteCustomer, Function(o) SelectedCustomer IsNot Nothing AndAlso CurrentPermissions IsNot Nothing AndAlso CurrentPermissions.CanDelete)
            End Get
        End Property

        Public ReadOnly Property ShowQuotesPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                                                    If SelectedCustomer IsNot Nothing Then
                                                        LoadCustomerQuotes(SelectedCustomer.PartnerID, SelectedCustomer.PartnerName)
                                                    End If
                                                End Sub)
            End Get
        End Property

        Public ReadOnly Property CloseQuotesPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsQuotesPanelOpen = False)
            End Get
        End Property

        Public ReadOnly Property CloseCustomerPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) 
                                                    IsCustomerPanelVisible = False
                                                    SelectedCustomer = Nothing
                                                End Sub)
            End Get
        End Property

        Public ReadOnly Property ViewQuoteCommand As ICommand
            Get
                Return New Helpers.RelayCommand(
                    Sub(o)
                        Dim q = TryCast(o, QuoteHeader)
                        If q Is Nothing Then
                            Dim summary = TryCast(o, PartnerQuoteSummaryItem)
                            If summary IsNot Nothing Then q = TryCast(summary.RawQuote, QuoteHeader)
                        End If
                        If q Is Nothing Then
                            Dim p = TryCast(o, Partner)
                            If p IsNot Nothing AndAlso p.LatestQuote IsNot Nothing Then
                                q = TryCast(p.LatestQuote, QuoteHeader)
                            End If
                        End If
                        If q IsNot Nothing Then RaiseEvent RequestNavigateToQuote(q)
                    End Sub,
                    Function(o) o IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Commands - Suppliers"
        Public ReadOnly Property SaveSupplierCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveSupplier)
            End Get
        End Property

        Public ReadOnly Property NewSupplierCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewSupplier)
            End Get
        End Property

        Public ReadOnly Property DeleteSupplierCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteSupplier, Function(o) SelectedSupplier IsNot Nothing AndAlso CurrentPermissions IsNot Nothing AndAlso CurrentPermissions.CanDelete)
            End Get
        End Property

        Public ReadOnly Property CloseSupplierPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) 
                                                    IsSupplierPanelVisible = False
                                                    SelectedSupplier = Nothing
                                                End Sub)
            End Get
        End Property

        Public ReadOnly Property ShowSupplierQuotesPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                                                     If SelectedSupplier IsNot Nothing Then
                                                         LoadSupplierQuotes(SelectedSupplier.PartnerID, SelectedSupplier.PartnerName)
                                                     End If
                                                 End Sub)
            End Get
        End Property

        Public ReadOnly Property CloseSupplierQuotesPanelCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsSupplierQuotesPanelOpen = False)
            End Get
        End Property

        Public ReadOnly Property ViewPurchaseQuoteCommand As ICommand
            Get
                Return New Helpers.RelayCommand(
                    Sub(o)
                        Dim q = TryCast(o, PurchaseQuoteHeader)
                        If q Is Nothing Then
                            Dim summary = TryCast(o, PartnerQuoteSummaryItem)
                            If summary IsNot Nothing Then q = TryCast(summary.RawQuote, PurchaseQuoteHeader)
                        End If
                        If q Is Nothing Then
                            Dim p = TryCast(o, Partner)
                            If p IsNot Nothing AndAlso p.LatestQuote IsNot Nothing Then
                                q = TryCast(p.LatestQuote, PurchaseQuoteHeader)
                            End If
                        End If
                        If q IsNot Nothing Then RaiseEvent RequestNavigateToPurchaseQuote(q)
                    End Sub,
                    Function(o) o IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Methods - Customers"
        Private Sub PopulateCustomerQuotes(partnerList As List(Of Partner))
            If partnerList Is Nothing OrElse partnerList.Count = 0 Then Return
            Try
                Dim allQuotes = _quoteService.GetAllQuotes()
                If allQuotes IsNot Nothing Then
                    Dim dict = allQuotes.GroupBy(Function(q) q.PartnerID).ToDictionary(Function(g) g.Key, Function(g) g.ToList())
                    For Each p In partnerList
                        If dict.ContainsKey(p.PartnerID) Then
                            Dim qList = dict(p.PartnerID)
                            p.QuotesCount = qList.Count
                            Dim summaryList As New List(Of PartnerQuoteSummaryItem)()
                            For Each q In qList.OrderByDescending(Function(x) x.QuoteDate)
                                q.PartnerName = p.PartnerName
                                q.PartnerID = p.PartnerID
                                summaryList.Add(New PartnerQuoteSummaryItem With {
                                    .QuoteID = q.QuoteID,
                                    .QuoteTitle = $"عرض سعر #{q.QuoteID}",
                                    .QuoteDate = q.QuoteDate,
                                    .QuoteDateFormatted = q.QuoteDate.ToString("yyyy/MM/dd"),
                                    .IsActive = q.IsActive,
                                    .RawQuote = q,
                                    .PartnerType = "Customer"
                                })
                            Next
                            p.DisplayQuotes = summaryList
                            p.LatestQuote = qList.OrderByDescending(Function(q) q.QuoteDate).FirstOrDefault()
                            p.QuotesList = qList.Cast(Of Object)().ToList()
                        Else
                            p.QuotesCount = 0
                            p.DisplayQuotes = New List(Of PartnerQuoteSummaryItem)()
                            p.LatestQuote = Nothing
                            p.QuotesList = New List(Of Object)()
                        End If
                    Next
                End If
            Catch ex As Exception
                ' Non-critical
            End Try
        End Sub

        Private Sub LoadCustomers()
            Try
                Dim list = _partnerService.GetAllPartners("Customer")
                PopulateCustomerQuotes(list)
                Customers = New ObservableCollection(Of Partner)(list)
            Catch ex As Exception
                CustomerStatusMessage = "خطأ في تحميل العملاء: " & ex.Message
            End Try
        End Sub

        Private Sub LoadCustomerQuotes(partnerID As Integer, customerName As String)
            Try
                QuotePanelCustomerName = customerName
                Dim quotes = _quoteService.GetQuotesByPartner(partnerID)
                
                ' تأكيد وجود اسم العميل في كل عرض لضمان ظهوره عند الانتقال للتفاصيل
                If quotes IsNot Nothing Then
                    For Each q In quotes
                        q.PartnerName = customerName
                        q.PartnerID = partnerID
                    Next
                End If

                CustomerQuotes = New ObservableCollection(Of QuoteHeader)(quotes)
                IsQuotesPanelOpen = True
            Catch ex As Exception
                CustomerStatusMessage = "خطأ في تحميل عروض الأسعار: " & ex.Message
            End Try
        End Sub

        Private Sub SearchCustomers()
            Try
                Dim list = _partnerService.SearchPartners("Customer", CustomerSearchText)
                PopulateCustomerQuotes(list)
                Customers = New ObservableCollection(Of Partner)(list)
            Catch ex As Exception
                CustomerStatusMessage = "خطأ في البحث: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteNewCustomer(obj As Object)
            SelectedCustomer = Nothing
            EditCustomerName = ""
            EditCustomerPhone = ""
            EditCustomerAddress = ""
            IsEditingCustomer = False
            CustomerNameError = Nothing
            IsCustomerPanelVisible = True
        End Sub

        Private Sub ExecuteSaveCustomer(obj As Object)
            If Not IsEditingCustomer AndAlso Not CurrentPermissions.CanAdd Then
                CustomerStatusMessage = "ليس لديك صلاحية لإضافة عميل جديد."
                Return
            End If
            If IsEditingCustomer AndAlso Not CurrentPermissions.CanEdit Then
                CustomerStatusMessage = "ليس لديك صلاحية لتعديل هذا العميل."
                Return
            End If

            CustomerNameError = Helpers.ValidationHelper.IsRequired(EditCustomerName, "اسم العميل")
            If CustomerNameError IsNot Nothing Then Return

            Try
                Dim p As New Partner With {
                    .PartnerID = If(IsEditingCustomer AndAlso SelectedCustomer IsNot Nothing, SelectedCustomer.PartnerID, 0),
                    .PartnerName = EditCustomerName,
                    .PartnerType = "Customer",
                    .Phone = EditCustomerPhone,
                    .Address = EditCustomerAddress
                }
                _partnerService.SavePartner(p)
                CustomerStatusMessage = If(p.PartnerID = 0, "تم إضافة العميل بنجاح. ✅", "تم تحديث العميل بنجاح. ✅")
                LoadCustomers()
                ExecuteNewCustomer(Nothing)
            Catch ex As Exception
                CustomerStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteCustomer(obj As Object)
            If SelectedCustomer Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذا العميل؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _partnerService.DeletePartner(SelectedCustomer.PartnerID)
                    CustomerStatusMessage = "تم تعطيل العميل. ✅"
                    LoadCustomers()
                    ExecuteNewCustomer(Nothing)
                Catch ex As Exception
                    CustomerStatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub
#End Region

#Region "Methods - Suppliers"
        Private Sub PopulateSupplierQuotes(partnerList As List(Of Partner))
            If partnerList Is Nothing OrElse partnerList.Count = 0 Then Return
            Try
                Dim allQuotes = _purchaseQuoteService.GetAllQuotes()
                If allQuotes IsNot Nothing Then
                    Dim dict = allQuotes.GroupBy(Function(q) q.PartnerID).ToDictionary(Function(g) g.Key, Function(g) g.ToList())
                    For Each p In partnerList
                        If dict.ContainsKey(p.PartnerID) Then
                            Dim qList = dict(p.PartnerID)
                            p.QuotesCount = qList.Count
                            Dim summaryList As New List(Of PartnerQuoteSummaryItem)()
                            For Each q In qList.OrderByDescending(Function(x) x.QuoteDate)
                                q.PartnerName = p.PartnerName
                                q.PartnerID = p.PartnerID
                                summaryList.Add(New PartnerQuoteSummaryItem With {
                                    .QuoteID = q.PurchaseQuoteID,
                                    .QuoteTitle = $"عرض مشتريات #{q.PurchaseQuoteID}",
                                    .QuoteDate = q.QuoteDate,
                                    .QuoteDateFormatted = q.QuoteDate.ToString("yyyy/MM/dd"),
                                    .IsActive = True,
                                    .RawQuote = q,
                                    .PartnerType = "Supplier"
                                })
                            Next
                            p.DisplayQuotes = summaryList
                            p.LatestQuote = qList.OrderByDescending(Function(q) q.QuoteDate).FirstOrDefault()
                            p.QuotesList = qList.Cast(Of Object)().ToList()
                        Else
                            p.QuotesCount = 0
                            p.DisplayQuotes = New List(Of PartnerQuoteSummaryItem)()
                            p.LatestQuote = Nothing
                            p.QuotesList = New List(Of Object)()
                        End If
                    Next
                End If
            Catch ex As Exception
                ' Non-critical
            End Try
        End Sub

        Private Sub LoadSuppliers()
            Try
                Dim list = _partnerService.GetAllPartners("Supplier")
                PopulateSupplierQuotes(list)
                Suppliers = New ObservableCollection(Of Partner)(list)
            Catch ex As Exception
                SupplierStatusMessage = "خطأ في تحميل الموردين: " & ex.Message
            End Try
        End Sub

        Private Sub SearchSuppliers()
            Try
                Dim list = _partnerService.SearchPartners("Supplier", SupplierSearchText)
                PopulateSupplierQuotes(list)
                Suppliers = New ObservableCollection(Of Partner)(list)
            Catch ex As Exception
                SupplierStatusMessage = "خطأ في البحث: " & ex.Message
            End Try
        End Sub

        Private Sub LoadSupplierQuotes(partnerID As Integer, supplierName As String)
            Try
                QuotePanelSupplierName = supplierName
                Dim quotes = _purchaseQuoteService.GetQuotesByPartner(partnerID)
                
                ' تأكيد وجود اسم المورد في كل عرض لضمان ظهوره عند الانتقال للتفاصيل
                If quotes IsNot Nothing Then
                    For Each q In quotes
                        q.PartnerName = supplierName
                        q.PartnerID = partnerID
                    Next
                End If

                SupplierQuotes = New ObservableCollection(Of PurchaseQuoteHeader)(quotes)
                IsSupplierQuotesPanelOpen = True
            Catch ex As Exception
                SupplierStatusMessage = "خطأ في تحميل عروض الأسعار: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteNewSupplier(obj As Object)
            SelectedSupplier = Nothing
            EditSupplierName = ""
            EditSupplierPhone = ""
            EditSupplierAddress = ""
            IsEditingSupplier = False
            SupplierNameError = Nothing
            IsSupplierPanelVisible = True
        End Sub

        Private Sub ExecuteSaveSupplier(obj As Object)
            If Not IsEditingSupplier AndAlso Not CurrentPermissions.CanAdd Then
                SupplierStatusMessage = "ليس لديك صلاحية لإضافة مورد جديد."
                Return
            End If
            If IsEditingSupplier AndAlso Not CurrentPermissions.CanEdit Then
                SupplierStatusMessage = "ليس لديك صلاحية لتعديل هذا المورد."
                Return
            End If

            SupplierNameError = Helpers.ValidationHelper.IsRequired(EditSupplierName, "اسم المورد")
            If SupplierNameError IsNot Nothing Then Return

            Try
                Dim p As New Partner With {
                    .PartnerID = If(IsEditingSupplier AndAlso SelectedSupplier IsNot Nothing, SelectedSupplier.PartnerID, 0),
                    .PartnerName = EditSupplierName,
                    .PartnerType = "Supplier",
                    .Phone = EditSupplierPhone,
                    .Address = EditSupplierAddress
                }
                _partnerService.SavePartner(p)
                SupplierStatusMessage = If(p.PartnerID = 0, "تم إضافة المورد بنجاح. ✅", "تم تحديث المورد بنجاح. ✅")
                LoadSuppliers()
                ExecuteNewSupplier(Nothing)
            Catch ex As Exception
                SupplierStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteSupplier(obj As Object)
            If SelectedSupplier Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذا المورد؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _partnerService.DeletePartner(SelectedSupplier.PartnerID)
                    SupplierStatusMessage = "تم تعطيل المورد. ✅"
                    LoadSuppliers()
                    ExecuteNewSupplier(Nothing)
                Catch ex As Exception
                    SupplierStatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub
#End Region

    End Class
End Namespace
