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

        Public Sub New()
            PartnerTypesList = New ObservableCollection(Of String)({"Customer", "Supplier", "Employee", "Delegate", "Other"})
            EditReceiptDate = DateTime.Now
            EditPaymentDate = DateTime.Now
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
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ في تحميل البيانات: " & ex.Message
            End Try
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
                End If
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
                End If
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
#End Region

#Region "Commands - Receipts"
        Public ReadOnly Property SaveReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveReceipt)
            End Get
        End Property
        Public ReadOnly Property NewReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewReceipt)
            End Get
        End Property
        Public ReadOnly Property DeleteReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteReceipt, Function(o) SelectedReceipt IsNot Nothing)
            End Get
        End Property
        Public ReadOnly Property PostReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePostReceipt, Function(o) SelectedReceipt IsNot Nothing AndAlso Not SelectedReceipt.IsPosted)
            End Get
        End Property
        Public ReadOnly Property PrintReceiptCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePrintReceipt, Function(o) SelectedReceipt IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Commands - Payments"
        Public ReadOnly Property SavePaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSavePayment)
            End Get
        End Property
        Public ReadOnly Property NewPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewPayment)
            End Get
        End Property
        Public ReadOnly Property DeletePaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeletePayment, Function(o) SelectedPayment IsNot Nothing)
            End Get
        End Property
        Public ReadOnly Property PostPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePostPayment, Function(o) SelectedPayment IsNot Nothing AndAlso Not SelectedPayment.IsPosted)
            End Get
        End Property
        Public ReadOnly Property PrintPaymentCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecutePrintPayment, Function(o) SelectedPayment IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Methods - Receipts"
        Private Sub LoadReceipts()
            Try
                Receipts = New ObservableCollection(Of Voucher)(_voucherService.GetAllVouchers("Receipt"))
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub SearchReceipts()
            Try
                Receipts = New ObservableCollection(Of Voucher)(_voucherService.SearchVouchers("Receipt", ReceiptSearchText))
            Catch ex As Exception
                ReceiptStatusMessage = "خطأ في البحث: " & ex.Message
            End Try
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
        End Sub

        Private Sub ExecuteSaveReceipt(obj As Object)
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
                _voucherService.SaveVoucher(v)
                ReceiptStatusMessage = If(v.VoucherID = 0, "تم إضافة سند القبض بنجاح. ✅", "تم تحديث سند القبض بنجاح. ✅")
                LoadReceipts()
                ExecuteNewReceipt(Nothing)
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
                    ' Re-select the same voucher so user can print it
                    SelectedReceipt = Receipts.FirstOrDefault(Function(v) v.VoucherID = currentID)
                Catch ex As Exception
                    ReceiptStatusMessage = "خطأ: " & ex.Message
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
                Payments = New ObservableCollection(Of Voucher)(_voucherService.GetAllVouchers("Payment"))
            Catch ex As Exception
                PaymentStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub SearchPayments()
            Try
                Payments = New ObservableCollection(Of Voucher)(_voucherService.SearchVouchers("Payment", PaymentSearchText))
            Catch ex As Exception
                PaymentStatusMessage = "خطأ في البحث: " & ex.Message
            End Try
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
        End Sub

        Private Sub ExecuteSavePayment(obj As Object)
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
                _voucherService.SaveVoucher(v)
                PaymentStatusMessage = If(v.VoucherID = 0, "تم إضافة سند الصرف بنجاح. ✅", "تم تحديث سند الصرف بنجاح. ✅")
                LoadPayments()
                ExecuteNewPayment(Nothing)
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
                    ' Re-select the same voucher so user can print it
                    SelectedPayment = Payments.FirstOrDefault(Function(v) v.VoucherID = currentID)
                Catch ex As Exception
                    PaymentStatusMessage = "خطأ: " & ex.Message
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
