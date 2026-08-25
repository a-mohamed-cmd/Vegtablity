Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class VouchersViewModel
        Inherits BaseViewModel

        Private ReadOnly _voucherService As New Services.VoucherService()
        Private ReadOnly _partnerService As New Services.PartnerService()
        Private ReadOnly _accountingService As New Services.AccountingService()

        Public Event ReceiptLoaded(accountID As Integer?, accountName As String)
        Public Event PaymentLoaded(accountID As Integer?, accountName As String)

        ' ===== سندات القبض =====
        Private _receipts As ObservableCollection(Of Voucher)
        Private _selectedReceipt As Voucher
        Private _isEditingReceipt As Boolean
        Private _receiptSearchText As String

        Private _editReceiptDate As DateTime
        Private _editReceiptPartnerID As Integer?
        Private _editReceiptAccountID As Integer?
        Private _editReceiptAmount As Decimal
        Private _editReceiptDescription As String
        Private _editReceiptPaymentMethod As String
        Private _receiptAmountError As String
        Private _receiptStatusMessage As String

        ' ===== سندات الصرف =====
        Private _payments As ObservableCollection(Of Voucher)
        Private _selectedPayment As Voucher
        Private _isEditingPayment As Boolean
        Private _paymentSearchText As String

        Private _editPaymentDate As DateTime
        Private _editPaymentPartnerID As Integer?
        Private _editPaymentAccountID As Integer?
        Private _editPaymentAmount As Decimal
        Private _editPaymentDescription As String
        Private _editPaymentPaymentMethod As String
        Private _paymentAmountError As String
        Private _paymentStatusMessage As String

        ' ===== Lookups =====
        Private _partners As ObservableCollection(Of Partner)
        Private _accounts As ObservableCollection(Of Account)
        Private _paymentMethods As ObservableCollection(Of Account)

        ' ===== Quick Add Partner =====
        Private _isAddingNewPartner As Boolean
        Private _newPartnerName As String
        Private _newPartnerType As String
        Private _partnerTypesList As ObservableCollection(Of String)

        ' --- Permissions ---
        Private _receiptPermissions As RolePermission
        Public Property ReceiptPermissions As RolePermission
            Get
                Return _receiptPermissions
            End Get
            Set(value As RolePermission)
                SetProperty(_receiptPermissions, value)
            End Set
        End Property

        Private _paymentPermissions As RolePermission
        Public Property PaymentPermissions As RolePermission
            Get
                Return _paymentPermissions
            End Get
            Set(value As RolePermission)
                SetProperty(_paymentPermissions, value)
            End Set
        End Property

        Public Sub New()
            PartnerTypesList = New ObservableCollection(Of String)({"Customer", "Supplier", "Employee", "Delegate", "Other"})
            EditReceiptDate = DateTime.Now
            EditPaymentDate = DateTime.Now

            Dim permService As New Services.PermissionService()
            If Services.Session.CurrentUser IsNot Nothing Then
                Dim roleID = Services.Session.CurrentUser.RoleID
                ReceiptPermissions = permService.GetPermissionsForForm(roleID, "ReceiptVoucher")
                PaymentPermissions = permService.GetPermissionsForForm(roleID, "PaymentVoucher")
            End If

            LoadLookups()
            If PaymentMethods IsNot Nothing AndAlso PaymentMethods.Count > 0 Then
                EditReceiptPaymentMethod = PaymentMethods.First().AccountID.ToString()
                EditPaymentPaymentMethod = PaymentMethods.First().AccountID.ToString()
            End If
            LoadReceipts()
            LoadPayments()
        End Sub

#Region "Quick Add Partner"
        Public Property IsAddingNewPartner As Boolean
            Get
                Return _isAddingNewPartner
            End Get
            Set(value As Boolean)
                SetProperty(_isAddingNewPartner, value)
            End Set
        End Property

        Public Property NewPartnerName As String
            Get
                Return _newPartnerName
            End Get
            Set(value As String)
                SetProperty(_newPartnerName, value)
            End Set
        End Property

        Public Property NewPartnerType As String
            Get
                Return _newPartnerType
            End Get
            Set(value As String)
                SetProperty(_newPartnerType, value)
            End Set
        End Property

        Public Property PartnerTypesList As ObservableCollection(Of String)
            Get
                Return _partnerTypesList
            End Get
            Set(value As ObservableCollection(Of String))
                SetProperty(_partnerTypesList, value)
            End Set
        End Property

        Public ReadOnly Property OpenNewPartnerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteOpenNewPartner)
            End Get
        End Property

        Public ReadOnly Property CancelNewPartnerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteCancelNewPartner)
            End Get
        End Property

        Public ReadOnly Property SaveNewPartnerCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveNewPartner)
            End Get
        End Property

        Private Sub ExecuteOpenNewPartner(obj As Object)
            Dim context As String = If(obj IsNot Nothing, obj.ToString(), "Receipt")
            NewPartnerName = ""
            NewPartnerType = If(context = "Receipt", "Customer", "Supplier")
            IsAddingNewPartner = True
        End Sub

        Private Sub ExecuteCancelNewPartner(obj As Object)
            IsAddingNewPartner = False
        End Sub

        Private Sub ExecuteSaveNewPartner(obj As Object)
            If String.IsNullOrWhiteSpace(NewPartnerName) Then
                MessageBox.Show("يرجى إدخال اسم المستلم / الشريك.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                Dim p As New Partner With {
                    .PartnerName = NewPartnerName.Trim(),
                    .PartnerType = NewPartnerType,
                    .Phone = "",
                    .Address = ""
                }
                Dim newId = _partnerService.SavePartner(p)
                
                ' إعادة تحميل قائمة الشركاء
                LoadLookups()
                
                ' تحديد الشريك الجديد بناءً على الشاشة (قبض أم صرف)
                Dim context As String = If(obj IsNot Nothing, obj.ToString(), "Receipt")
                If context = "Receipt" Then
                    EditReceiptPartnerID = newId
                Else
                    EditPaymentPartnerID = newId
                End If
                
                IsAddingNewPartner = False
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الشريك الجديد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub
#End Region

#Region "Lookups"
        Public Property Partners As ObservableCollection(Of Partner)
            Get
                Return _partners
            End Get
            Set(value As ObservableCollection(Of Partner))
                SetProperty(_partners, value)
            End Set
        End Property

        
        Private _filteredAccounts As ObservableCollection(Of Account)
        Public Property FilteredAccounts As ObservableCollection(Of Account)
            Get
                Return _filteredAccounts
            End Get
            Set(value As ObservableCollection(Of Account))
                _filteredAccounts = value
                OnPropertyChanged()
            End Set
        End Property

        Public Sub FilterAccounts(searchText As String)
            If String.IsNullOrWhiteSpace(searchText) Then
                FilteredAccounts = Accounts
            Else
                Dim lower = searchText.ToLower()
                FilteredAccounts = New ObservableCollection(Of Account)(
                    System.Linq.Enumerable.Where(Accounts, Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower().Contains(lower)) OrElse 
                                               (a.AccountCode IsNot Nothing AndAlso a.AccountCode.Contains(searchText)))
                )
            End If
        End Sub

        Public Property Accounts As ObservableCollection(Of Account)
            Get
                Return _accounts
            End Get
            Set(value As ObservableCollection(Of Account))
                SetProperty(_accounts, value)
            End Set
        End Property

        Public Property PaymentMethods As ObservableCollection(Of Account)
            Get
                Return _paymentMethods
            End Get
            Set(value As ObservableCollection(Of Account))
                SetProperty(_paymentMethods, value)
            End Set
        End Property

        Private Sub LoadLookups()
            Try
                ' تحميل كل الشركاء بمختلف أنواعهم
                Dim allPartners = _partnerService.GetAllPartners("All")
                Partners = New ObservableCollection(Of Partner)(allPartners)

                ' تحميل الحسابات القابلة للقيد فقط (IsTransactional = 1)
                Dim allAccounts = _accountingService.GetAllAccounts()
                Accounts = New ObservableCollection(Of Account)(allAccounts.Where(Function(a) a.IsTransactional))

                ' تحميل حسابات طريقة الدفع (النقدية والبنوك AccountCode = 11)
                PaymentMethods = New ObservableCollection(Of Account)(allAccounts.Where(Function(a) a.IsTransactional AndAlso a.AccountCode.StartsWith("11")))
                
                EnrichPaymentMethodNames(Receipts)
                EnrichPaymentMethodNames(Payments)
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ في تحميل البيانات: " & ex.Message
            End Try
        End Sub

        Private Sub EnrichPaymentMethodNames(vouchers As IEnumerable(Of Voucher))
            If vouchers Is Nothing OrElse PaymentMethods Is Nothing Then Return
            For Each v In vouchers
                If String.IsNullOrEmpty(v.PaymentMethodName) OrElse v.PaymentMethodName = v.PaymentMethod Then
                    Dim pmAcc = PaymentMethods.FirstOrDefault(Function(a) a.AccountID.ToString() = v.PaymentMethod)
                    If pmAcc IsNot Nothing Then
                        v.PaymentMethodName = pmAcc.AccountName
                    End If
                End If
            Next
        End Sub
#End Region

#Region "Properties - Receipts"
        Public Property Receipts As ObservableCollection(Of Voucher)
            Get
                Return _receipts
            End Get
            Set(value As ObservableCollection(Of Voucher))
                SetProperty(_receipts, value)
            End Set
        End Property

        Public Property SelectedReceipt As Voucher
            Get
                Return _selectedReceipt
            End Get
            Set(value As Voucher)
                SetProperty(_selectedReceipt, value)
                If value IsNot Nothing Then
                    EditReceiptDate = value.VoucherDate
                    EditReceiptPartnerID = value.PartnerID
                    EditReceiptAccountID = value.AccountID
                    EditReceiptAmount = value.Amount
                    EditReceiptDescription = value.Description
                    EditReceiptPaymentMethod = value.PaymentMethod
                    IsEditingReceipt = True
                    ReceiptAmountError = Nothing
                    RaiseEvent ReceiptLoaded(value.AccountID, value.AccountName)
                End If
                NotifyReceiptButtonStates()
            End Set
        End Property

        Public Property IsEditingReceipt As Boolean
            Get
                Return _isEditingReceipt
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingReceipt, value)
            End Set
        End Property

        Public Property ReceiptSearchText As String
            Get
                Return _receiptSearchText
            End Get
            Set(value As String)
                SetProperty(_receiptSearchText, value)
                If String.IsNullOrWhiteSpace(value) Then LoadReceipts() Else SearchReceipts()
            End Set
        End Property

        Public Property EditReceiptDate As DateTime
            Get
                Return _editReceiptDate
            End Get
            Set(value As DateTime)
                SetProperty(_editReceiptDate, value)
                _editReceiptDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged(NameOf(EditReceiptDateText))
            End Set
        End Property

        Private _editReceiptDateText As String = DateTime.Now.ToString("dd/MM/yyyy")
        Public Property EditReceiptDateText As String
            Get
                Return _editReceiptDateText
            End Get
            Set(value As String)
                _editReceiptDateText = If(value, "")
                OnPropertyChanged(NameOf(EditReceiptDateText))
            End Set
        End Property

        Public Property EditReceiptPartnerID As Integer?
            Get
                Return _editReceiptPartnerID
            End Get
            Set(value As Integer?)
                SetProperty(_editReceiptPartnerID, value)
            End Set
        End Property

        Public Property EditReceiptAccountID As Integer?
            Get
                Return _editReceiptAccountID
            End Get
            Set(value As Integer?)
                SetProperty(_editReceiptAccountID, value)
            End Set
        End Property

        Public Property EditReceiptAmount As Decimal
            Get
                Return _editReceiptAmount
            End Get
            Set(value As Decimal)
                SetProperty(_editReceiptAmount, value)
                If value > 0 Then ReceiptAmountError = Nothing
            End Set
        End Property

        Public Property EditReceiptDescription As String
            Get
                Return _editReceiptDescription
            End Get
            Set(value As String)
                SetProperty(_editReceiptDescription, value)
            End Set
        End Property

        Public Property EditReceiptPaymentMethod As String
            Get
                Return _editReceiptPaymentMethod
            End Get
            Set(value As String)
                SetProperty(_editReceiptPaymentMethod, value)
            End Set
        End Property

        Public Property ReceiptAmountError As String
            Get
                Return _receiptAmountError
            End Get
            Set(value As String)
                SetProperty(_receiptAmountError, value)
            End Set
        End Property

        Public Property ReceiptStatusMessage As String
            Get
                Return _receiptStatusMessage
            End Get
            Set(value As String)
                SetProperty(_receiptStatusMessage, value)
            End Set
        End Property

        ' --- Smart Buttons & Editor Panel - Receipts ---
        Public ReadOnly Property IsReceiptPosted As Boolean
            Get
                Return SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsReceiptEditAllowed As Boolean
            Get
                Return Not IsReceiptPosted
            End Get
        End Property

        Public ReadOnly Property IsReceiptSaveVisible As Boolean
            Get
                Return Not IsReceiptPosted
            End Get
        End Property

        Public ReadOnly Property IsReceiptPostVisible As Boolean
            Get
                Return Not IsReceiptPosted AndAlso SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.VoucherID > 0
            End Get
        End Property

        Public ReadOnly Property IsReceiptUnpostVisible As Boolean
            Get
                Return IsReceiptPosted AndAlso SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.VoucherID > 0
            End Get
        End Property

        Private _isReceiptEditorExpanded As Boolean = True
        Public Property IsReceiptEditorExpanded As Boolean
            Get
                Return _isReceiptEditorExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isReceiptEditorExpanded, value)
                OnPropertyChanged(NameOf(ReceiptToggleIconText))
                OnPropertyChanged(NameOf(ReceiptToggleTooltip))
            End Set
        End Property

        Public ReadOnly Property ReceiptToggleIconText As String
            Get
                Return If(IsReceiptEditorExpanded, "◀ طي النموذج", "▶ إضافة / تعديل سند")
            End Get
        End Property

        Public ReadOnly Property ReceiptToggleTooltip As String
            Get
                Return If(IsReceiptEditorExpanded, "طي لوحة إضافة / تعديل السند لتوسيع القائمة", "إظهار لوحة إضافة / تعديل السند")
            End Get
        End Property

        Public Sub NotifyReceiptButtonStates()
            OnPropertyChanged(NameOf(IsReceiptPosted))
            OnPropertyChanged(NameOf(IsReceiptEditAllowed))
            OnPropertyChanged(NameOf(IsReceiptSaveVisible))
            OnPropertyChanged(NameOf(IsReceiptPostVisible))
            OnPropertyChanged(NameOf(IsReceiptUnpostVisible))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        ' === Pagination - Receipts ===
        Private _receiptCurrentPageIndex As Integer = 1
        Public Property ReceiptCurrentPageIndex As Integer
            Get
                Return _receiptCurrentPageIndex
            End Get
            Set(value As Integer)
                _receiptCurrentPageIndex = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(HasPreviousReceiptPage))
                OnPropertyChanged(NameOf(HasNextReceiptPage))
                OnPropertyChanged(NameOf(ReceiptPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Private _receiptPageSize As Integer = 15
        Public Property ReceiptPageSize As Integer
            Get
                Return _receiptPageSize
            End Get
            Set(value As Integer)
                _receiptPageSize = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(ReceiptTotalPages))
                OnPropertyChanged(NameOf(HasPreviousReceiptPage))
                OnPropertyChanged(NameOf(HasNextReceiptPage))
                OnPropertyChanged(NameOf(ReceiptPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Private _receiptTotalCount As Integer = 0
        Public Property ReceiptTotalCount As Integer
            Get
                Return _receiptTotalCount
            End Get
            Set(value As Integer)
                _receiptTotalCount = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(ReceiptTotalPages))
                OnPropertyChanged(NameOf(HasPreviousReceiptPage))
                OnPropertyChanged(NameOf(HasNextReceiptPage))
                OnPropertyChanged(NameOf(ReceiptPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Public ReadOnly Property ReceiptTotalPages As Integer
            Get
                If ReceiptPageSize <= 0 Then Return 1
                Return Math.Max(1, CInt(Math.Ceiling(ReceiptTotalCount / CDbl(ReceiptPageSize))))
            End Get
        End Property

        Public ReadOnly Property HasPreviousReceiptPage As Boolean
            Get
                Return ReceiptCurrentPageIndex > 1
            End Get
        End Property

        Public ReadOnly Property HasNextReceiptPage As Boolean
            Get
                Return ReceiptCurrentPageIndex < ReceiptTotalPages
            End Get
        End Property

        Public ReadOnly Property ReceiptPageInfoText As String
            Get
                Return "صفحة " & ReceiptCurrentPageIndex & " من " & ReceiptTotalPages & " (إجمالي: " & ReceiptTotalCount & " سند)"
            End Get
        End Property
#End Region

#Region "Properties - Payments"
        Public Property Payments As ObservableCollection(Of Voucher)
            Get
                Return _payments
            End Get
            Set(value As ObservableCollection(Of Voucher))
                SetProperty(_payments, value)
            End Set
        End Property

        Public Property SelectedPayment As Voucher
            Get
                Return _selectedPayment
            End Get
            Set(value As Voucher)
                SetProperty(_selectedPayment, value)
                If value IsNot Nothing Then
                    EditPaymentDate = value.VoucherDate
                    EditPaymentPartnerID = value.PartnerID
                    EditPaymentAccountID = value.AccountID
                    EditPaymentAmount = value.Amount
                    EditPaymentDescription = value.Description
                    EditPaymentPaymentMethod = value.PaymentMethod
                    IsEditingPayment = True
                    PaymentAmountError = Nothing
                    RaiseEvent PaymentLoaded(value.AccountID, value.AccountName)
                End If
                NotifyPaymentButtonStates()
            End Set
        End Property

        Public Property IsEditingPayment As Boolean
            Get
                Return _isEditingPayment
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingPayment, value)
            End Set
        End Property

        Public Property PaymentSearchText As String
            Get
                Return _paymentSearchText
            End Get
            Set(value As String)
                SetProperty(_paymentSearchText, value)
                If String.IsNullOrWhiteSpace(value) Then LoadPayments() Else SearchPayments()
            End Set
        End Property

        Public Property EditPaymentDate As DateTime
            Get
                Return _editPaymentDate
            End Get
            Set(value As DateTime)
                SetProperty(_editPaymentDate, value)
                _editPaymentDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged(NameOf(EditPaymentDateText))
            End Set
        End Property

        Private _editPaymentDateText As String = DateTime.Now.ToString("dd/MM/yyyy")
        Public Property EditPaymentDateText As String
            Get
                Return _editPaymentDateText
            End Get
            Set(value As String)
                _editPaymentDateText = If(value, "")
                OnPropertyChanged(NameOf(EditPaymentDateText))
            End Set
        End Property

        Public Property EditPaymentPartnerID As Integer?
            Get
                Return _editPaymentPartnerID
            End Get
            Set(value As Integer?)
                SetProperty(_editPaymentPartnerID, value)
            End Set
        End Property

        Public Property EditPaymentAccountID As Integer?
            Get
                Return _editPaymentAccountID
            End Get
            Set(value As Integer?)
                SetProperty(_editPaymentAccountID, value)
            End Set
        End Property

        Public Property EditPaymentAmount As Decimal
            Get
                Return _editPaymentAmount
            End Get
            Set(value As Decimal)
                SetProperty(_editPaymentAmount, value)
                If value > 0 Then PaymentAmountError = Nothing
            End Set
        End Property

        Public Property EditPaymentDescription As String
            Get
                Return _editPaymentDescription
            End Get
            Set(value As String)
                SetProperty(_editPaymentDescription, value)
            End Set
        End Property

        Public Property EditPaymentPaymentMethod As String
            Get
                Return _editPaymentPaymentMethod
            End Get
            Set(value As String)
                SetProperty(_editPaymentPaymentMethod, value)
            End Set
        End Property

        Public Property PaymentAmountError As String
            Get
                Return _paymentAmountError
            End Get
            Set(value As String)
                SetProperty(_paymentAmountError, value)
            End Set
        End Property

        Public Property PaymentStatusMessage As String
            Get
                Return _paymentStatusMessage
            End Get
            Set(value As String)
                SetProperty(_paymentStatusMessage, value)
            End Set
        End Property

        ' --- Smart Buttons & Editor Panel - Payments ---
        Public ReadOnly Property IsPaymentPosted As Boolean
            Get
                Return SelectedPayment IsNot Nothing AndAlso SelectedPayment.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsPaymentEditAllowed As Boolean
            Get
                Return Not IsPaymentPosted
            End Get
        End Property

        Public ReadOnly Property IsPaymentSaveVisible As Boolean
            Get
                Return Not IsPaymentPosted
            End Get
        End Property

        Public ReadOnly Property IsPaymentPostVisible As Boolean
            Get
                Return Not IsPaymentPosted AndAlso SelectedPayment IsNot Nothing AndAlso SelectedPayment.VoucherID > 0
            End Get
        End Property

        Public ReadOnly Property IsPaymentUnpostVisible As Boolean
            Get
                Return IsPaymentPosted AndAlso SelectedPayment IsNot Nothing AndAlso SelectedPayment.VoucherID > 0
            End Get
        End Property

        Private _isPaymentEditorExpanded As Boolean = True
        Public Property IsPaymentEditorExpanded As Boolean
            Get
                Return _isPaymentEditorExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isPaymentEditorExpanded, value)
                OnPropertyChanged(NameOf(PaymentToggleIconText))
                OnPropertyChanged(NameOf(PaymentToggleTooltip))
            End Set
        End Property

        Public ReadOnly Property PaymentToggleIconText As String
            Get
                Return If(IsPaymentEditorExpanded, "◀ طي النموذج", "▶ إضافة / تعديل سند")
            End Get
        End Property

        Public ReadOnly Property PaymentToggleTooltip As String
            Get
                Return If(IsPaymentEditorExpanded, "طي لوحة إضافة / تعديل السند لتوسيع القائمة", "إظهار لوحة إضافة / تعديل السند")
            End Get
        End Property

        Public Sub NotifyPaymentButtonStates()
            OnPropertyChanged(NameOf(IsPaymentPosted))
            OnPropertyChanged(NameOf(IsPaymentEditAllowed))
            OnPropertyChanged(NameOf(IsPaymentSaveVisible))
            OnPropertyChanged(NameOf(IsPaymentPostVisible))
            OnPropertyChanged(NameOf(IsPaymentUnpostVisible))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        ' === Pagination - Payments ===
        Private _paymentCurrentPageIndex As Integer = 1
        Public Property PaymentCurrentPageIndex As Integer
            Get
                Return _paymentCurrentPageIndex
            End Get
            Set(value As Integer)
                _paymentCurrentPageIndex = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(HasPreviousPaymentPage))
                OnPropertyChanged(NameOf(HasNextPaymentPage))
                OnPropertyChanged(NameOf(PaymentPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Private _paymentPageSize As Integer = 15
        Public Property PaymentPageSize As Integer
            Get
                Return _paymentPageSize
            End Get
            Set(value As Integer)
                _paymentPageSize = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(PaymentTotalPages))
                OnPropertyChanged(NameOf(HasPreviousPaymentPage))
                OnPropertyChanged(NameOf(HasNextPaymentPage))
                OnPropertyChanged(NameOf(PaymentPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Private _paymentTotalCount As Integer = 0
        Public Property PaymentTotalCount As Integer
            Get
                Return _paymentTotalCount
            End Get
            Set(value As Integer)
                _paymentTotalCount = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(PaymentTotalPages))
                OnPropertyChanged(NameOf(HasPreviousPaymentPage))
                OnPropertyChanged(NameOf(HasNextPaymentPage))
                OnPropertyChanged(NameOf(PaymentPageInfoText))
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        Public ReadOnly Property PaymentTotalPages As Integer
            Get
                If PaymentPageSize <= 0 Then Return 1
                Return Math.Max(1, CInt(Math.Ceiling(PaymentTotalCount / CDbl(PaymentPageSize))))
            End Get
        End Property

        Public ReadOnly Property HasPreviousPaymentPage As Boolean
            Get
                Return PaymentCurrentPageIndex > 1
            End Get
        End Property

        Public ReadOnly Property HasNextPaymentPage As Boolean
            Get
                Return PaymentCurrentPageIndex < PaymentTotalPages
            End Get
        End Property

        Public ReadOnly Property PaymentPageInfoText As String
            Get
                Return "صفحة " & PaymentCurrentPageIndex & " من " & PaymentTotalPages & " (إجمالي: " & PaymentTotalCount & " سند)"
            End Get
        End Property
#End Region

#Region "Commands - Receipts"
        Public ReadOnly Property SaveReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveReceipt, Function(o) IsReceiptEditAllowed AndAlso (ReceiptPermissions Is Nothing OrElse If(IsEditingReceipt, ReceiptPermissions.CanEdit, ReceiptPermissions.CanAdd)))
            End Get
        End Property
        Public ReadOnly Property NewReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewReceipt, Function(o) ReceiptPermissions Is Nothing OrElse ReceiptPermissions.CanAdd)
            End Get
        End Property
        Public ReadOnly Property DeleteReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteReceipt, Function(o) SelectedReceipt IsNot Nothing AndAlso ReceiptPermissions IsNot Nothing AndAlso ReceiptPermissions.CanDelete)
            End Get
        End Property
        Public ReadOnly Property PostReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePostReceipt, Function(o) SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.VoucherID > 0 AndAlso Not SelectedReceipt.IsPosted AndAlso ReceiptPermissions IsNot Nothing AndAlso ReceiptPermissions.CanEdit)
            End Get
        End Property
        Public ReadOnly Property UnpostReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteUnpostReceipt, Function(o) SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.VoucherID > 0 AndAlso SelectedReceipt.IsPosted AndAlso ReceiptPermissions IsNot Nothing AndAlso ReceiptPermissions.CanDelete)
            End Get
        End Property
        Public ReadOnly Property ToggleReceiptEditorCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsReceiptEditorExpanded = Not IsReceiptEditorExpanded)
            End Get
        End Property
        Public ReadOnly Property PrintReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePrintReceipt, Function(o) (TryCast(o, Voucher) IsNot Nothing AndAlso DirectCast(o, Voucher).VoucherID > 0) OrElse (SelectedReceipt IsNot Nothing AndAlso SelectedReceipt.VoucherID > 0))
            End Get
        End Property

        Public ReadOnly Property FirstReceiptPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasPreviousReceiptPage Then
                        ReceiptCurrentPageIndex = 1
                        LoadReceipts()
                    End If
                End Sub, Function(o) HasPreviousReceiptPage)
            End Get
        End Property

        Public ReadOnly Property PreviousReceiptPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasPreviousReceiptPage Then
                        ReceiptCurrentPageIndex -= 1
                        LoadReceipts()
                    End If
                End Sub, Function(o) HasPreviousReceiptPage)
            End Get
        End Property

        Public ReadOnly Property NextReceiptPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasNextReceiptPage Then
                        ReceiptCurrentPageIndex += 1
                        LoadReceipts()
                    End If
                End Sub, Function(o) HasNextReceiptPage)
            End Get
        End Property

        Public ReadOnly Property LastReceiptPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasNextReceiptPage Then
                        ReceiptCurrentPageIndex = ReceiptTotalPages
                        LoadReceipts()
                    End If
                End Sub, Function(o) HasNextReceiptPage)
            End Get
        End Property
#End Region

#Region "Commands - Payments"
        Public ReadOnly Property SavePaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSavePayment, Function(o) IsPaymentEditAllowed AndAlso (PaymentPermissions Is Nothing OrElse If(IsEditingPayment, PaymentPermissions.CanEdit, PaymentPermissions.CanAdd)))
            End Get
        End Property
        Public ReadOnly Property NewPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewPayment, Function(o) PaymentPermissions Is Nothing OrElse PaymentPermissions.CanAdd)
            End Get
        End Property
        Public ReadOnly Property DeletePaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeletePayment, Function(o) SelectedPayment IsNot Nothing AndAlso PaymentPermissions IsNot Nothing AndAlso PaymentPermissions.CanDelete)
            End Get
        End Property
        Public ReadOnly Property PostPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePostPayment, Function(o) SelectedPayment IsNot Nothing AndAlso SelectedPayment.VoucherID > 0 AndAlso Not SelectedPayment.IsPosted AndAlso PaymentPermissions IsNot Nothing AndAlso PaymentPermissions.CanEdit)
            End Get
        End Property
        Public ReadOnly Property UnpostPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteUnpostPayment, Function(o) SelectedPayment IsNot Nothing AndAlso SelectedPayment.VoucherID > 0 AndAlso SelectedPayment.IsPosted AndAlso PaymentPermissions IsNot Nothing AndAlso PaymentPermissions.CanDelete)
            End Get
        End Property
        Public ReadOnly Property TogglePaymentEditorCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsPaymentEditorExpanded = Not IsPaymentEditorExpanded)
            End Get
        End Property
        Public ReadOnly Property PrintPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePrintPayment, Function(o) (TryCast(o, Voucher) IsNot Nothing AndAlso DirectCast(o, Voucher).VoucherID > 0) OrElse (SelectedPayment IsNot Nothing AndAlso SelectedPayment.VoucherID > 0))
            End Get
        End Property

        Public ReadOnly Property FirstPaymentPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasPreviousPaymentPage Then
                        PaymentCurrentPageIndex = 1
                        LoadPayments()
                    End If
                End Sub, Function(o) HasPreviousPaymentPage)
            End Get
        End Property

        Public ReadOnly Property PreviousPaymentPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasPreviousPaymentPage Then
                        PaymentCurrentPageIndex -= 1
                        LoadPayments()
                    End If
                End Sub, Function(o) HasPreviousPaymentPage)
            End Get
        End Property

        Public ReadOnly Property NextPaymentPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasNextPaymentPage Then
                        PaymentCurrentPageIndex += 1
                        LoadPayments()
                    End If
                End Sub, Function(o) HasNextPaymentPage)
            End Get
        End Property

        Public ReadOnly Property LastPaymentPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If HasNextPaymentPage Then
                        PaymentCurrentPageIndex = PaymentTotalPages
                        LoadPayments()
                    End If
                End Sub, Function(o) HasNextPaymentPage)
            End Get
        End Property
#End Region

#Region "Methods - Receipts"
        Private Sub LoadReceipts()
            Try
                Dim count As Integer = 0
                Dim list = _voucherService.GetPagedVouchers("Receipt", ReceiptCurrentPageIndex, ReceiptPageSize, ReceiptSearchText, count)
                ReceiptTotalCount = count
                EnrichPaymentMethodNames(list)
                Receipts = New ObservableCollection(Of Voucher)(list)
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub SearchReceipts()
            ReceiptCurrentPageIndex = 1
            LoadReceipts()
        End Sub

        Private Sub ExecuteNewReceipt(obj As Object)
            SelectedReceipt = Nothing
            EditReceiptDate = DateTime.Now
            EditReceiptPartnerID = Nothing
            EditReceiptAccountID = Nothing
            EditReceiptAmount = 0
            EditReceiptDescription = ""
            If PaymentMethods IsNot Nothing AndAlso PaymentMethods.Count > 0 Then
                EditReceiptPaymentMethod = PaymentMethods.First().AccountID.ToString()
            Else
                EditReceiptPaymentMethod = ""
            End If
            IsEditingReceipt = False
            ReceiptAmountError = Nothing
            RaiseEvent ReceiptLoaded(Nothing, Nothing)
            NotifyReceiptButtonStates()
        End Sub

        Private Sub ExecuteSaveReceipt(obj As Object)
            If Not IsEditingReceipt AndAlso ReceiptPermissions IsNot Nothing AndAlso Not ReceiptPermissions.CanAdd Then
                ReceiptStatusMessage = "ليس لديك صلاحية لإضافة سند قبض جديد."
                Return
            End If
            If IsEditingReceipt AndAlso ReceiptPermissions IsNot Nothing AndAlso Not ReceiptPermissions.CanEdit Then
                ReceiptStatusMessage = "ليس لديك صلاحية لتعديل سند القبض."
                Return
            End If

            If EditReceiptAmount <= 0 Then
                ReceiptAmountError = "المبلغ يجب أن يكون أكبر من صفر"
                Return
            End If

            Try
                Dim v As New Voucher With {
                    .VoucherID = If(IsEditingReceipt AndAlso SelectedReceipt IsNot Nothing, SelectedReceipt.VoucherID, 0),
                    .VoucherType = "Receipt",
                    .VoucherDate = EditReceiptDate,
                    .PartnerID = EditReceiptPartnerID,
                    .AccountID = EditReceiptAccountID,
                    .Amount = EditReceiptAmount,
                    .Description = EditReceiptDescription,
                    .PaymentMethod = EditReceiptPaymentMethod,
                    .UserID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0)
                }
                Dim savedId = _voucherService.SaveVoucher(v)
                Dim currentID = If(v.VoucherID = 0, savedId, v.VoucherID)
                ReceiptStatusMessage = If(v.VoucherID = 0, "تم إضافة سند القبض بنجاح. ✅", "تم تحديث سند القبض بنجاح. ✅")
                LoadReceipts()
                SelectedReceipt = Receipts.FirstOrDefault(Function(r) r.VoucherID = currentID)
                NotifyReceiptButtonStates()
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteReceipt(obj As Object)
            If SelectedReceipt Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من حذف هذا السند؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _voucherService.DeleteVoucher(SelectedReceipt.VoucherID)
                    ReceiptStatusMessage = "تم حذف السند. ✅"
                    LoadReceipts()
                    ExecuteNewReceipt(Nothing)
                Catch ex As Exception
                    ReceiptStatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecutePostReceipt(obj As Object)
            If SelectedReceipt Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من ترحيل هذا السند؟" & vbCrLf & "سيتم إنشاء قيد محاسبي تلقائياً.",
                               "تأكيد الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    Dim currentID = SelectedReceipt.VoucherID
                    _voucherService.PostVoucher(currentID)
                    ReceiptStatusMessage = "تم ترحيل السند وإنشاء القيد بنجاح. ✅"
                    LoadReceipts()
                    ' Re-select the same voucher so user sees unpost button and updated status
                    SelectedReceipt = Receipts.FirstOrDefault(Function(v) v.VoucherID = currentID)
                    NotifyReceiptButtonStates()
                Catch ex As Exception
                    ReceiptStatusMessage = "خطأ أثناء الترحيل: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecuteUnpostReceipt(obj As Object)
            If SelectedReceipt Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من إلغاء ترحيل سند القبض هذا؟ سيتم حذف القيود المحاسبية المرتبطة به من الدفتر العام وإرجاع السند كغير مرحّل.", "تأكيد إلغاء الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    Dim currentID = SelectedReceipt.VoucherID
                    _voucherService.UnpostVoucher(currentID)
                    ReceiptStatusMessage = "تم إلغاء ترحيل سند القبض وحذف قيوده بنجاح. ✅"
                    LoadReceipts()
                    SelectedReceipt = Receipts.FirstOrDefault(Function(v) v.VoucherID = currentID)
                    NotifyReceiptButtonStates()
                Catch ex As Exception
                    ReceiptStatusMessage = "خطأ أثناء إلغاء الترحيل: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecutePrintReceipt(obj As Object)
            Dim voucherToPrint = TryCast(obj, Voucher)
            If voucherToPrint Is Nothing Then voucherToPrint = SelectedReceipt
            If voucherToPrint Is Nothing Then Return
            
            Try
                Helpers.ReportExporter.ExportReceiptVoucherToPdf(voucherToPrint)
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ في الطباعة: " & ex.Message
            End Try
        End Sub
#End Region

#Region "Methods - Payments"
        Private Sub LoadPayments()
            Try
                Dim count As Integer = 0
                Dim list = _voucherService.GetPagedVouchers("Payment", PaymentCurrentPageIndex, PaymentPageSize, PaymentSearchText, count)
                PaymentTotalCount = count
                EnrichPaymentMethodNames(list)
                Payments = New ObservableCollection(Of Voucher)(list)
            Catch ex As Exception
                PaymentStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub SearchPayments()
            PaymentCurrentPageIndex = 1
            LoadPayments()
        End Sub

        Private Sub ExecuteNewPayment(obj As Object)
            SelectedPayment = Nothing
            EditPaymentDate = DateTime.Now
            EditPaymentPartnerID = Nothing
            EditPaymentAccountID = Nothing
            EditPaymentAmount = 0
            EditPaymentDescription = ""
            If PaymentMethods IsNot Nothing AndAlso PaymentMethods.Count > 0 Then
                EditPaymentPaymentMethod = PaymentMethods.First().AccountID.ToString()
            Else
                EditPaymentPaymentMethod = ""
            End If
            IsEditingPayment = False
            PaymentAmountError = Nothing
            RaiseEvent PaymentLoaded(Nothing, Nothing)
            NotifyPaymentButtonStates()
        End Sub

        Private Sub ExecuteSavePayment(obj As Object)
            If Not IsEditingPayment AndAlso PaymentPermissions IsNot Nothing AndAlso Not PaymentPermissions.CanAdd Then
                PaymentStatusMessage = "ليس لديك صلاحية لإضافة سند صرف جديد."
                Return
            End If
            If IsEditingPayment AndAlso PaymentPermissions IsNot Nothing AndAlso Not PaymentPermissions.CanEdit Then
                PaymentStatusMessage = "ليس لديك صلاحية لتعديل سند الصرف."
                Return
            End If

            If EditPaymentAmount <= 0 Then
                PaymentAmountError = "المبلغ يجب أن يكون أكبر من صفر"
                Return
            End If

            Try
                Dim v As New Voucher With {
                    .VoucherID = If(IsEditingPayment AndAlso SelectedPayment IsNot Nothing, SelectedPayment.VoucherID, 0),
                    .VoucherType = "Payment",
                    .VoucherDate = EditPaymentDate,
                    .PartnerID = EditPaymentPartnerID,
                    .AccountID = EditPaymentAccountID,
                    .Amount = EditPaymentAmount,
                    .Description = EditPaymentDescription,
                    .PaymentMethod = EditPaymentPaymentMethod,
                    .UserID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0)
                }
                Dim savedId = _voucherService.SaveVoucher(v)
                Dim currentID = If(v.VoucherID = 0, savedId, v.VoucherID)
                PaymentStatusMessage = If(v.VoucherID = 0, "تم إضافة سند الصرف بنجاح. ✅", "تم تحديث سند الصرف بنجاح. ✅")
                LoadPayments()
                SelectedPayment = Payments.FirstOrDefault(Function(p) p.VoucherID = currentID)
                NotifyPaymentButtonStates()
            Catch ex As Exception
                PaymentStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeletePayment(obj As Object)
            If SelectedPayment Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من حذف هذا السند؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _voucherService.DeleteVoucher(SelectedPayment.VoucherID)
                    PaymentStatusMessage = "تم حذف السند. ✅"
                    LoadPayments()
                    ExecuteNewPayment(Nothing)
                Catch ex As Exception
                    PaymentStatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecutePostPayment(obj As Object)
            If SelectedPayment Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من ترحيل هذا السند؟" & vbCrLf & "سيتم إنشاء قيد محاسبي تلقائياً.",
                               "تأكيد الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    Dim currentID = SelectedPayment.VoucherID
                    _voucherService.PostVoucher(currentID)
                    PaymentStatusMessage = "تم ترحيل السند وإنشاء القيد بنجاح. ✅"
                    LoadPayments()
                    ' Re-select the same voucher so user sees unpost button and updated status
                    SelectedPayment = Payments.FirstOrDefault(Function(v) v.VoucherID = currentID)
                    NotifyPaymentButtonStates()
                Catch ex As Exception
                    PaymentStatusMessage = "خطأ أثناء الترحيل: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecuteUnpostPayment(obj As Object)
            If SelectedPayment Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من إلغاء ترحيل سند الصرف هذا؟ سيتم حذف القيود المحاسبية المرتبطة به من الدفتر العام وإرجاع السند كغير مرحّل.", "تأكيد إلغاء الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    Dim currentID = SelectedPayment.VoucherID
                    _voucherService.UnpostVoucher(currentID)
                    PaymentStatusMessage = "تم إلغاء ترحيل سند الصرف وحذف قيوده بنجاح. ✅"
                    LoadPayments()
                    SelectedPayment = Payments.FirstOrDefault(Function(v) v.VoucherID = currentID)
                    NotifyPaymentButtonStates()
                Catch ex As Exception
                    PaymentStatusMessage = "خطأ أثناء إلغاء الترحيل: " & ex.Message
                End Try
            End If
        End Sub

        Private Sub ExecutePrintPayment(obj As Object)
            Dim voucherToPrint = TryCast(obj, Voucher)
            If voucherToPrint Is Nothing Then voucherToPrint = SelectedPayment
            If voucherToPrint Is Nothing Then Return
            
            Try
                Helpers.ReportExporter.ExportPaymentVoucherToPdf(voucherToPrint)
            Catch ex As Exception
                PaymentStatusMessage = "خطأ في الطباعة: " & ex.Message
            End Try
        End Sub
#End Region

    End Class
End Namespace
