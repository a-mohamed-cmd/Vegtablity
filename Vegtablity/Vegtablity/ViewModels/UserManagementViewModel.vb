Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class UserManagementViewModel
        Inherits BaseViewModel

        Private ReadOnly _userService As New Services.UserManagementService()
        Private ReadOnly _roleService As New Services.RoleService()

        ' ===== Users =====
        Private _users As ObservableCollection(Of User)
        Private _selectedUser As User
        Private _editUserName As String
        Private _editFullName As String
        Private _editPassword As String
        Private _editIsActive As Boolean = True
        Private _editRoleID As Integer
        Private _isEditingUser As Boolean
        Private _userStatusMessage As String

        ' ===== User Validation Errors =====
        Private _userNameError As String
        Private _fullNameError As String
        Private _passwordError As String
        Private _roleError As String

        ' ===== Roles =====
        Private _roles As ObservableCollection(Of Role)
        Private _selectedRole As Role
        Private _editRoleName As String
        Private _editRoleDescription As String
        Private _isEditingRole As Boolean

        ' ===== Role Validation Errors =====
        Private _roleNameError As String

        ' ===== Permissions =====
        Private _permissions As ObservableCollection(Of RolePermission)
        Private _selectedPermissionRole As Role
        Private _availableForms As Dictionary(Of String, String)

        Public Sub New()
            Dim settingsService As New Services.SettingsService()
            Dim compInfo = settingsService.GetCompanyInfo()
            Dim isProductionMode As Boolean = (compInfo IsNot Nothing AndAlso compInfo.ProductionMode)
            Dim enableDailyOrders As Boolean = (compInfo IsNot Nothing AndAlso compInfo.EnableDailyOrders)

            Dim formsMap As New Dictionary(Of String, String) From {
                {"Dashboard", "لوحة المعلومات الرئيسية"},
                {"Sales", "فاتورة مبيعات"},
                {"Purchases", "فاتورة مشتريات"},
                {"Inventory", "المخزون والمنتجات"},
                {"InvoiceDashboard", "لوحة الفواتير"},
                {"Accounting", "الحسابات (الرئيسية)"},
                {"ChartOfAccounts", "شجرة الحسابات"},
                {"ReceiptVoucher", "سند قبض"},
                {"PaymentVoucher", "سند صرف"},
                {"JournalEntries", "قيود اليومية"},
                {"AccountStatement", "كشف حساب"},
                {"TrialBalance", "ميزان المراجعة"},
                {"BalanceSheet", "المركز المالي"},
                {"ProfitLoss", "أرباح وخسائر"},
                {"YearEndClose", "الإقفال السنوي"},
                {"Partners", "العملاء والموردين"},
                {"Quotes", "عروض الأسعار"},
                {"PurchaseQuotes", "عروض المشتريات"},
                {"Shifts", "الورديات"},
                {"Reports", "التقارير"},
                {"SettingsParent", "قسم الإعدادات"},
                {"Settings", "إعدادات عامة"},
                {"CompanySettings", "بيانات الشركة"},
                {"UserManagement", "إدارة المستخدمين"},
                {"Wastage", "إدارة التوالف والهوالك"},
                {"StockTaking", "إدارة الجرد الآلي"}
            }

            If enableDailyOrders Then
                formsMap.Add("DailyOrders", "الطلبات اليومية")
            End If

            If isProductionMode Then
                formsMap.Add("Recipes", "وصفات المنتجات")
            End If

            AvailableForms = formsMap
            LoadData()
        End Sub

#Region "Properties - Users"
        Public Property Users As ObservableCollection(Of User)
            Get
                Return _users
            End Get
            Set(value As ObservableCollection(Of User))
                SetProperty(_users, value)
            End Set
        End Property

        Public Property SelectedUser As User
            Get
                Return _selectedUser
            End Get
            Set(value As User)
                SetProperty(_selectedUser, value)
                If value IsNot Nothing Then
                    EditUserName = value.Username
                    EditFullName = value.FullName
                    EditIsActive = value.IsActive
                    EditRoleID = value.RoleID
                    EditPassword = ""
                    IsEditingUser = True
                    ClearUserErrors()
                End If
            End Set
        End Property

        Public Property EditUserName As String
            Get
                Return _editUserName
            End Get
            Set(value As String)
                SetProperty(_editUserName, value)
                If Not String.IsNullOrEmpty(value) Then UserNameError = Nothing
            End Set
        End Property

        Public Property EditFullName As String
            Get
                Return _editFullName
            End Get
            Set(value As String)
                SetProperty(_editFullName, value)
                If Not String.IsNullOrEmpty(value) Then FullNameError = Nothing
            End Set
        End Property

        Public Property EditPassword As String
            Get
                Return _editPassword
            End Get
            Set(value As String)
                SetProperty(_editPassword, value)
                If Not String.IsNullOrEmpty(value) Then PasswordError = Nothing
            End Set
        End Property

        Public Property EditIsActive As Boolean
            Get
                Return _editIsActive
            End Get
            Set(value As Boolean)
                SetProperty(_editIsActive, value)
            End Set
        End Property

        Public Property EditRoleID As Integer
            Get
                Return _editRoleID
            End Get
            Set(value As Integer)
                SetProperty(_editRoleID, value)
                If value > 0 Then RoleError = Nothing
            End Set
        End Property

        Public Property IsEditingUser As Boolean
            Get
                Return _isEditingUser
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingUser, value)
            End Set
        End Property

        Public Property UserStatusMessage As String
            Get
                Return _userStatusMessage
            End Get
            Set(value As String)
                SetProperty(_userStatusMessage, value)
            End Set
        End Property
#End Region

#Region "Properties - User Validation Errors"
        Public Property UserNameError As String
            Get
                Return _userNameError
            End Get
            Set(value As String)
                SetProperty(_userNameError, value)
            End Set
        End Property

        Public Property FullNameError As String
            Get
                Return _fullNameError
            End Get
            Set(value As String)
                SetProperty(_fullNameError, value)
            End Set
        End Property

        Public Property PasswordError As String
            Get
                Return _passwordError
            End Get
            Set(value As String)
                SetProperty(_passwordError, value)
            End Set
        End Property

        Public Property RoleError As String
            Get
                Return _roleError
            End Get
            Set(value As String)
                SetProperty(_roleError, value)
            End Set
        End Property
#End Region

#Region "Properties - Roles"
        Public Property Roles As ObservableCollection(Of Role)
            Get
                Return _roles
            End Get
            Set(value As ObservableCollection(Of Role))
                SetProperty(_roles, value)
            End Set
        End Property

        Public Property SelectedRole As Role
            Get
                Return _selectedRole
            End Get
            Set(value As Role)
                SetProperty(_selectedRole, value)
                If value IsNot Nothing Then
                    EditRoleName = value.RoleName
                    EditRoleDescription = value.Description
                    IsEditingRole = True
                    ClearRoleErrors()
                End If
            End Set
        End Property

        Public Property EditRoleName As String
            Get
                Return _editRoleName
            End Get
            Set(value As String)
                SetProperty(_editRoleName, value)
                If Not String.IsNullOrEmpty(value) Then RoleNameError = Nothing
            End Set
        End Property

        Public Property EditRoleDescription As String
            Get
                Return _editRoleDescription
            End Get
            Set(value As String)
                SetProperty(_editRoleDescription, value)
            End Set
        End Property

        Public Property IsEditingRole As Boolean
            Get
                Return _isEditingRole
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingRole, value)
            End Set
        End Property

        Public Property RoleNameError As String
            Get
                Return _roleNameError
            End Get
            Set(value As String)
                SetProperty(_roleNameError, value)
            End Set
        End Property
#End Region

#Region "Properties - Permissions"
        Public Property Permissions As ObservableCollection(Of RolePermission)
            Get
                Return _permissions
            End Get
            Set(value As ObservableCollection(Of RolePermission))
                SetProperty(_permissions, value)
            End Set
        End Property

        Public Property SelectedPermissionRole As Role
            Get
                Return _selectedPermissionRole
            End Get
            Set(value As Role)
                SetProperty(_selectedPermissionRole, value)
                If value IsNot Nothing Then
                    LoadPermissionsForRole(value.RoleID)
                End If
            End Set
        End Property

        Public Property AvailableForms As Dictionary(Of String, String)
            Get
                Return _availableForms
            End Get
            Set(value As Dictionary(Of String, String))
                SetProperty(_availableForms, value)
            End Set
        End Property
#End Region

#Region "Commands"
        Public ReadOnly Property SaveUserCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveUser)
            End Get
        End Property

        Public ReadOnly Property NewUserCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewUser)
            End Get
        End Property

        Public ReadOnly Property DeleteUserCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteUser, Function(o) SelectedUser IsNot Nothing)
            End Get
        End Property

        Public ReadOnly Property SaveRoleCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveRole)
            End Get
        End Property

        Public ReadOnly Property NewRoleCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewRole)
            End Get
        End Property

        Public ReadOnly Property DeleteRoleCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteRole, Function(o) SelectedRole IsNot Nothing)
            End Get
        End Property

        Public ReadOnly Property SavePermissionsCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSavePermissions)
            End Get
        End Property

        Public ReadOnly Property SelectAllPermissionsCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSelectAllPermissions)
            End Get
        End Property
#End Region

#Region "Methods"
        Private Sub ClearUserErrors()
            UserNameError = Nothing
            FullNameError = Nothing
            PasswordError = Nothing
            RoleError = Nothing
        End Sub

        Private Sub ClearRoleErrors()
            RoleNameError = Nothing
        End Sub

        Private Function ValidateUser() As Boolean
            ClearUserErrors()
            Dim hasError As Boolean = False

            ' Username
            Dim err As String = Helpers.ValidationHelper.IsRequired(EditUserName, "اسم المستخدم")
            If err IsNot Nothing Then
                UserNameError = err
                hasError = True
            Else
                err = Helpers.ValidationHelper.MinLength(EditUserName, 3, "اسم المستخدم")
                If err IsNot Nothing Then
                    UserNameError = err
                    hasError = True
                Else
                    err = Helpers.ValidationHelper.MaxLength(EditUserName, 50, "اسم المستخدم")
                    If err IsNot Nothing Then
                        UserNameError = err
                        hasError = True
                    End If
                End If
            End If

            ' Full Name
            err = Helpers.ValidationHelper.IsRequired(EditFullName, "الاسم الكامل")
            If err IsNot Nothing Then
                FullNameError = err
                hasError = True
            Else
                err = Helpers.ValidationHelper.MaxLength(EditFullName, 100, "الاسم الكامل")
                If err IsNot Nothing Then
                    FullNameError = err
                    hasError = True
                End If
            End If

            ' Password (required for new users only)
            If Not IsEditingUser Then
                err = Helpers.ValidationHelper.IsRequired(EditPassword, "كلمة المرور")
                If err IsNot Nothing Then
                    PasswordError = err
                    hasError = True
                Else
                    err = Helpers.ValidationHelper.MinLength(EditPassword, 3, "كلمة المرور")
                    If err IsNot Nothing Then
                        PasswordError = err
                        hasError = True
                    End If
                End If
            End If

            ' Role
            err = Helpers.ValidationHelper.IsSelected(EditRoleID, "الدور")
            If err IsNot Nothing Then
                RoleError = err
                hasError = True
            End If

            Return Not hasError
        End Function

        Private Function ValidateRole() As Boolean
            ClearRoleErrors()
            Dim hasError As Boolean = False

            Dim err As String = Helpers.ValidationHelper.IsRequired(EditRoleName, "اسم الدور")
            If err IsNot Nothing Then
                RoleNameError = err
                hasError = True
            Else
                err = Helpers.ValidationHelper.MaxLength(EditRoleName, 50, "اسم الدور")
                If err IsNot Nothing Then
                    RoleNameError = err
                    hasError = True
                End If
            End If

            Return Not hasError
        End Function

        Private Sub LoadData()
            Try
                Users = New ObservableCollection(Of User)(_userService.GetAllUsers())
                Roles = New ObservableCollection(Of Role)(_roleService.GetAllRoles())
            Catch ex As Exception
                UserStatusMessage = "خطأ في تحميل البيانات: " & ex.Message
            End Try
        End Sub

        Private Sub LoadPermissionsForRole(roleID As Integer)
            Try
                Dim existingPerms = _roleService.GetPermissionsForRole(roleID)
                Dim allPerms As New List(Of RolePermission)

                For Each kvp In AvailableForms
                    Dim formName = kvp.Key
                    Dim displayName = kvp.Value
                    
                    Dim existing = existingPerms.FirstOrDefault(Function(p) p.FormName = formName)
                    If existing IsNot Nothing Then
                        existing.DisplayName = displayName
                        allPerms.Add(existing)
                    Else
                        allPerms.Add(New RolePermission With {
                            .RoleID = roleID,
                            .FormName = formName,
                            .DisplayName = displayName,
                            .CanView = False,
                            .CanAdd = False,
                            .CanEdit = False,
                            .CanDelete = False,
                            .CanPrint = False
                        })
                    End If
                Next

                Permissions = New ObservableCollection(Of RolePermission)(allPerms)
            Catch ex As Exception
                UserStatusMessage = "خطأ في تحميل الصلاحيات: " & ex.Message
            End Try
        End Sub

        ' --- User CRUD ---
        Private Sub ExecuteNewUser(obj As Object)
            SelectedUser = Nothing
            EditUserName = ""
            EditFullName = ""
            EditPassword = ""
            EditIsActive = True
            EditRoleID = If(Roles.Count > 0, Roles(0).RoleID, 0)
            IsEditingUser = False
            ClearUserErrors()
        End Sub

        Private Sub ExecuteSaveUser(obj As Object)
            If Not ValidateUser() Then Return

            Try
                If IsEditingUser AndAlso SelectedUser IsNot Nothing Then
                    ' Update
                    SelectedUser.Username = EditUserName
                    SelectedUser.FullName = EditFullName
                    SelectedUser.IsActive = EditIsActive
                    SelectedUser.RoleID = EditRoleID
                    _userService.UpdateUser(SelectedUser)

                    If Not String.IsNullOrWhiteSpace(EditPassword) Then
                        _userService.ResetPassword(SelectedUser.UserID, EditPassword)
                    End If
                    UserStatusMessage = "تم تحديث المستخدم بنجاح. ✅"
                Else
                    ' Add
                    Dim newUser As New User With {
                        .Username = EditUserName,
                        .FullName = EditFullName,
                        .IsActive = EditIsActive,
                        .RoleID = EditRoleID
                    }
                    _userService.AddUser(newUser, EditPassword)
                    UserStatusMessage = "تم إضافة المستخدم بنجاح. ✅"
                End If

                LoadData()
                ExecuteNewUser(Nothing)
            Catch ex As Exception
                UserStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteUser(obj As Object)
            If SelectedUser Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من حذف هذا المستخدم؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _userService.DeleteUser(SelectedUser.UserID)
                    UserStatusMessage = "تم حذف المستخدم. ✅"
                    LoadData()
                    ExecuteNewUser(Nothing)
                Catch ex As Exception
                    UserStatusMessage = "خطأ في الحذف: " & ex.Message
                End Try
            End If
        End Sub

        ' --- Role CRUD ---
        Private Sub ExecuteNewRole(obj As Object)
            SelectedRole = Nothing
            EditRoleName = ""
            EditRoleDescription = ""
            IsEditingRole = False
            ClearRoleErrors()
        End Sub

        Private Sub ExecuteSaveRole(obj As Object)
            If Not ValidateRole() Then Return

            Try
                If IsEditingRole AndAlso SelectedRole IsNot Nothing Then
                    SelectedRole.RoleName = EditRoleName
                    SelectedRole.Description = EditRoleDescription
                    _roleService.UpdateRole(SelectedRole)
                    UserStatusMessage = "تم تحديث الدور. ✅"
                Else
                    Dim newRole As New Role With {.RoleName = EditRoleName, .Description = EditRoleDescription}
                    _roleService.AddRole(newRole)
                    UserStatusMessage = "تم إضافة الدور. ✅"
                End If

                LoadData()
                ExecuteNewRole(Nothing)
            Catch ex As Exception
                UserStatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteRole(obj As Object)
            If SelectedRole Is Nothing Then Return
            If SelectedRole.RoleName = "Admin" Then
                UserStatusMessage = "لا يمكن حذف دور المسؤول."
                Return
            End If
            If MessageBox.Show("هل أنت متأكد من حذف هذا الدور وجميع صلاحياته؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _roleService.DeleteRole(SelectedRole.RoleID)
                    UserStatusMessage = "تم حذف الدور. ✅"
                    LoadData()
                    ExecuteNewRole(Nothing)
                Catch ex As Exception
                    UserStatusMessage = "خطأ في الحذف: " & ex.Message
                End Try
            End If
        End Sub

        ' --- Permissions ---
        Private Sub ExecuteSelectAllPermissions(obj As Object)
            If Permissions IsNot Nothing Then
                For Each perm In Permissions
                    perm.CanView = True
                    perm.CanAdd = True
                    perm.CanEdit = True
                    perm.CanDelete = True
                    perm.CanPrint = True
                Next
                UserStatusMessage = "تم تحديد جميع الصلاحيات. يرجى الحفظ."
            End If
        End Sub

        Private Sub ExecuteSavePermissions(obj As Object)
            If SelectedPermissionRole Is Nothing OrElse Permissions Is Nothing Then
                UserStatusMessage = "يرجى اختيار الدور أولاً."
                Return
            End If
            Try
                For Each perm In Permissions
                    perm.RoleID = SelectedPermissionRole.RoleID
                    _roleService.SavePermission(perm)
                Next
                UserStatusMessage = "تم حفظ الصلاحيات بنجاح. ✅"
                LoadPermissionsForRole(SelectedPermissionRole.RoleID)
            Catch ex As Exception
                UserStatusMessage = "خطأ في حفظ الصلاحيات: " & ex.Message
            End Try
        End Sub
#End Region

    End Class
End Namespace
