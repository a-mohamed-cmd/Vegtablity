Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class PartnersViewModel
        Inherits BaseViewModel

        Private ReadOnly _partnerService As New Services.PartnerService()

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
                End If
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
                End If
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
#End Region

#Region "Methods - Customers"
        Private Sub LoadCustomers()
            Try
                Customers = New ObservableCollection(Of Partner)(_partnerService.GetAllPartners("Customer"))
            Catch ex As Exception
                CustomerStatusMessage = "خطأ في تحميل العملاء: " & ex.Message
            End Try
        End Sub

        Private Sub SearchCustomers()
            Try
                Customers = New ObservableCollection(Of Partner)(_partnerService.SearchPartners("Customer", CustomerSearchText))
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
        Private Sub LoadSuppliers()
            Try
                Suppliers = New ObservableCollection(Of Partner)(_partnerService.GetAllPartners("Supplier"))
            Catch ex As Exception
                SupplierStatusMessage = "خطأ في تحميل الموردين: " & ex.Message
            End Try
        End Sub

        Private Sub SearchSuppliers()
            Try
                Suppliers = New ObservableCollection(Of Partner)(_partnerService.SearchPartners("Supplier", SupplierSearchText))
            Catch ex As Exception
                SupplierStatusMessage = "خطأ في البحث: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteNewSupplier(obj As Object)
            SelectedSupplier = Nothing
            EditSupplierName = ""
            EditSupplierPhone = ""
            EditSupplierAddress = ""
            IsEditingSupplier = False
            SupplierNameError = Nothing
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
