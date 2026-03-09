Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class AccountingViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New Services.AccountingService()

        Private _accounts As ObservableCollection(Of Account)
        Private _parentAccounts As ObservableCollection(Of Account)
        Private _selectedAccount As Account
        Private _isEditing As Boolean
        Private _searchText As String
        Private _isInternalSync As Boolean = False

        ' حقول التعديل
        Private _editAccountCode As String
        Private _editAccountName As String
        Private _editParentAccountID As Integer?
        Private _editAccountType As String
        Private _editAccountLevel As Integer
        Private _editIsTransactional As Boolean
        Private _isTransactionalEnabled As Boolean = True
        Private _panelTitle As String = "إضافة حساب جديد"
        Private _saveActionText As String = "إضافة"
        Private _displayParentAccounts As ObservableCollection(Of Account)

        ' أخطاء
        Private _accountCodeError As String
        Private _accountNameError As String
        Private _statusMessage As String

        ' أنواع الحسابات
        Private _accountTypes As ObservableCollection(Of String)

        Public Sub New()
            AccountTypes = New ObservableCollection(Of String)({"Assets", "Liabilities", "Equity", "Expenses", "Revenue"})
            LoadPermissions("ChartOfAccounts")
            LoadAccounts()
            LoadParentAccounts()
            EditIsTransactional = True
            EditAccountLevel = 1
            PanelTitle = "📁 إضافة حساب جديد"
            SaveActionText = "إضافة"
            UpdateDisplayParentAccounts()
            StatusMessage = "جاهز " & DateTime.Now.ToString("HH:mm:ss")
        End Sub

#Region "Properties"
        Public Property Accounts As ObservableCollection(Of Account)
            Get
                Return _accounts
            End Get
            Set(value As ObservableCollection(Of Account))
                SetProperty(_accounts, value)
            End Set
        End Property

        Public Property ParentAccounts As ObservableCollection(Of Account)
            Get
                Return _parentAccounts
            End Get
            Set(value As ObservableCollection(Of Account))
                SetProperty(_parentAccounts, value)
            End Set
        End Property

        Public Property SelectedAccount As Account
            Get
                Return _selectedAccount
            End Get
            Set(value As Account)
                ' Using SetProperty to ensure correct notification and change detection
                If SetProperty(_selectedAccount, value) Then
                    UpdateFieldsFromSelected()
                End If
            End Set
        End Property

        Private Sub UpdateFieldsFromSelected()
            ' Deep Sync: Prevent recursive UI feedback during data loading
            _isInternalSync = True
            
            Try
                ' 1. Clear validation state
                AccountCodeError = Nothing
                AccountNameError = Nothing

                If _selectedAccount IsNot Nothing Then
                    ' 2. Prepare the UI Context FIRST
                    ' We update the lists before setting the values to ensure ComboBoxes find their items
                    UpdateDisplayParentAccounts()
                    
                    ' 3. Enter Editing Mode (Set properties directly to trigger individual notifications)
                    IsEditing = True
                    PanelTitle = "✏️ تعديل بيانات الحساب"
                    SaveActionText = "تحديث"

                    ' 4. Map Data Fields
                    EditAccountCode = _selectedAccount.AccountCode
                    EditAccountName = _selectedAccount.AccountName
                    EditParentAccountID = _selectedAccount.ParentAccountID
                    EditAccountType = _selectedAccount.AccountType
                    EditAccountLevel = _selectedAccount.AccountLevel
                    EditIsTransactional = _selectedAccount.IsTransactional
                    
                    ' 5. UI State check
                    Dim hasChildren = If(Accounts IsNot Nothing, Accounts.Any(Function(a) a.ParentAccountID.HasValue AndAlso a.ParentAccountID.Value = _selectedAccount.AccountID), False)
                    IsTransactionalEnabled = Not hasChildren
                    
                    StatusMessage = "✅ وضع التعديل: تحميل بيانات [" & _selectedAccount.AccountName & "]"
                Else
                    ' Reset to Add Mode
                    IsEditing = False
                    PanelTitle = "📁 إضافة حساب جديد"
                    SaveActionText = "إضافة"
                    
                    EditAccountCode = ""
                    EditAccountName = ""
                    EditParentAccountID = Nothing
                    EditAccountType = "Assets"
                    EditAccountLevel = 1
                    EditIsTransactional = True
                    IsTransactionalEnabled = True
                    
                    UpdateDisplayParentAccounts()
                    StatusMessage = "ℹ️ وضع الإضافة: في انتظار اختيار حساب..."
                End If
            Catch ex As Exception
                StatusMessage = "❌ خطأ في تحميل البيانات: " & ex.Message
            Finally
                _isInternalSync = False
            End Try
            
            ' Final broadcast to ensure any complex bindings or triggers refresh
            ' Note: We use string.Empty to refresh all properties on this instance
            OnPropertyChanged("") 
        End Sub

        Public Property IsEditing As Boolean
            Get
                Return _isEditing
            End Get
            Set(value As Boolean)
                SetProperty(_isEditing, value)
            End Set
        End Property

        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                SetProperty(_searchText, value)
                If String.IsNullOrWhiteSpace(value) Then
                    LoadAccounts()
                Else
                    SearchAccounts()
                End If
            End Set
        End Property

        Public Property AccountTypes As ObservableCollection(Of String)
            Get
                Return _accountTypes
            End Get
            Set(value As ObservableCollection(Of String))
                SetProperty(_accountTypes, value)
            End Set
        End Property

        Public Property EditAccountCode As String
            Get
                Return _editAccountCode
            End Get
            Set(value As String)
                SetProperty(_editAccountCode, value)
                If Not String.IsNullOrEmpty(value) Then AccountCodeError = Nothing
            End Set
        End Property

        Public Property EditAccountName As String
            Get
                Return _editAccountName
            End Get
            Set(value As String)
                SetProperty(_editAccountName, value)
                If Not String.IsNullOrEmpty(value) Then AccountNameError = Nothing
            End Set
        End Property

        Public Property EditParentAccountID As Integer?
            Get
                Return _editParentAccountID
            End Get
            Set(value As Integer?)
                If SetProperty(_editParentAccountID, value) Then
                    ' Only automate if this is a user change (not during selection load)
                    If Not _isInternalSync Then
                        If value.HasValue AndAlso ParentAccounts IsNot Nothing Then
                            ' Automate Level and Type inheritance
                            Dim parent = ParentAccounts.FirstOrDefault(Function(a) a.AccountID = value.Value)
                            If parent IsNot Nothing Then
                                EditAccountLevel = parent.AccountLevel + 1
                                EditAccountType = parent.AccountType
                            End If
                        ElseIf Not value.HasValue Then
                            ' Reset to default if no parent
                            EditAccountLevel = 1
                        End If
                    End If
                End If
            End Set
        End Property

        Public Property EditAccountType As String
            Get
                Return _editAccountType
            End Get
            Set(value As String)
                SetProperty(_editAccountType, value)
            End Set
        End Property

        Public Property EditAccountLevel As Integer
            Get
                Return _editAccountLevel
            End Get
            Set(value As Integer)
                SetProperty(_editAccountLevel, value)
            End Set
        End Property

        Public Property EditIsTransactional As Boolean
            Get
                Return _editIsTransactional
            End Get
            Set(value As Boolean)
                SetProperty(_editIsTransactional, value)
            End Set
        End Property

        Public Property IsTransactionalEnabled As Boolean
            Get
                Return _isTransactionalEnabled
            End Get
            Set(value As Boolean)
                SetProperty(_isTransactionalEnabled, value)
            End Set
        End Property

        Public Property PanelTitle As String
            Get
                Return _panelTitle
            End Get
            Set(value As String)
                SetProperty(_panelTitle, value)
            End Set
        End Property

        Public Property SaveActionText As String
            Get
                Return _saveActionText
            End Get
            Set(value As String)
                SetProperty(_saveActionText, value)
            End Set
        End Property

        Public Property DisplayParentAccounts As ObservableCollection(Of Account)
            Get
                Return _displayParentAccounts
            End Get
            Set(value As ObservableCollection(Of Account))
                SetProperty(_displayParentAccounts, value)
            End Set
        End Property

        Public Property AccountCodeError As String
            Get
                Return _accountCodeError
            End Get
            Set(value As String)
                SetProperty(_accountCodeError, value)
            End Set
        End Property

        Public Property AccountNameError As String
            Get
                Return _accountNameError
            End Get
            Set(value As String)
                SetProperty(_accountNameError, value)
            End Set
        End Property

        Public Property StatusMessage As String
            Get
                Return _statusMessage
            End Get
            Set(value As String)
                SetProperty(_statusMessage, value)
            End Set
        End Property
#End Region

#Region "Commands"
        Public ReadOnly Property SaveCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSave)
            End Get
        End Property

        Public ReadOnly Property NewCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNew)
            End Get
        End Property

        Public ReadOnly Property DeleteCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDelete, Function(o) SelectedAccount IsNot Nothing AndAlso CurrentPermissions IsNot Nothing AndAlso CurrentPermissions.CanDelete)
            End Get
        End Property
#End Region

#Region "Methods"
        Private Sub LoadAccounts()
            Try
                Accounts = New ObservableCollection(Of Account)(_accountingService.GetAllAccounts())
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل الحسابات: " & ex.Message
            End Try
        End Sub

        Private Sub LoadParentAccounts()
            Try
                ParentAccounts = New ObservableCollection(Of Account)(_accountingService.GetParentAccounts())
                UpdateDisplayParentAccounts()
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل الحسابات الأب: " & ex.Message
            End Try
        End Sub

        Private Sub UpdateDisplayParentAccounts()
            If ParentAccounts Is Nothing Then 
                DisplayParentAccounts = New ObservableCollection(Of Account)()
                Return
            End If
            
            ' Prevent circular reference:
            ' 1. Hide the account itself
            ' 2. Hide all its descendants (children, grandchildren, etc.)
            If SelectedAccount IsNot Nothing Then
                Dim invalidIDs As New HashSet(Of Integer)()
                invalidIDs.Add(SelectedAccount.AccountID)
                
                ' Simple recursive discovery of descendants in the current flat list
                AddDescendantsToSet(SelectedAccount.AccountID, invalidIDs)

                DisplayParentAccounts = New ObservableCollection(Of Account)(
                    ParentAccounts.Where(Function(a) Not invalidIDs.Contains(a.AccountID))
                )
            Else
                DisplayParentAccounts = New ObservableCollection(Of Account)(ParentAccounts)
            End If
        End Sub

        Private Sub AddDescendantsToSet(parentID As Integer, visitedSet As HashSet(Of Integer))
            If Accounts Is Nothing Then Return
            ' Safely compare Nullable(Of Integer) to Integer
            Dim children = Accounts.Where(Function(a) a.ParentAccountID.HasValue AndAlso a.ParentAccountID.Value = parentID).Select(Function(a) a.AccountID).ToList()
            For Each childID In children
                If visitedSet.Add(childID) Then
                    AddDescendantsToSet(childID, visitedSet)
                End If
            Next
        End Sub

        Private Sub SearchAccounts()
            Try
                Accounts = New ObservableCollection(Of Account)(_accountingService.SearchAccounts(SearchText))
            Catch ex As Exception
                StatusMessage = "خطأ في البحث: " & ex.Message
            End Try
        End Sub

        Private Function ValidateAccount() As Boolean
            Dim isValid = True
            AccountCodeError = Helpers.ValidationHelper.IsRequired(EditAccountCode, "رمز الحساب")
            If AccountCodeError IsNot Nothing Then isValid = False

            AccountNameError = Helpers.ValidationHelper.IsRequired(EditAccountName, "اسم الحساب")
            If AccountNameError IsNot Nothing Then isValid = False

            Return isValid
        End Function

        Private Sub ExecuteNew(obj As Object)
            SelectedAccount = Nothing
            EditAccountCode = ""
            EditAccountName = ""
            EditParentAccountID = Nothing
            EditAccountType = "Assets"
            EditAccountLevel = 1
            EditIsTransactional = True
            IsEditing = False
            PanelTitle = "📁 إضافة حساب جديد"
            SaveActionText = "إضافة"
            AccountCodeError = Nothing
            AccountNameError = Nothing
            StatusMessage = "تم البدء بإضافة حساب جديد."
        End Sub

        Private Sub ExecuteSave(obj As Object)
            If Not IsEditing AndAlso Not CurrentPermissions.CanAdd Then
                StatusMessage = "ليس لديك صلاحية لإضافة حساب جديد."
                Return
            End If
            If IsEditing AndAlso Not CurrentPermissions.CanEdit Then
                StatusMessage = "ليس لديك صلاحية لتعديل هذا الحساب."
                Return
            End If

            If Not ValidateAccount() Then Return

            ' Confirmation for updates
            If IsEditing AndAlso SelectedAccount IsNot Nothing Then
                If MessageBox.Show("هل أنت متأكد من حفظ التعديلات على حساب: " & SelectedAccount.AccountName & "؟",
                                   "تأكيد التعديل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.No Then
                    Return
                End If
            End If

            Try
                Dim a As New Account With {
                    .AccountID = If(IsEditing AndAlso SelectedAccount IsNot Nothing, SelectedAccount.AccountID, 0),
                    .AccountCode = EditAccountCode,
                    .AccountName = EditAccountName,
                    .ParentAccountID = EditParentAccountID,
                    .AccountType = EditAccountType,
                    .AccountLevel = EditAccountLevel,
                    .IsTransactional = EditIsTransactional
                }
                _accountingService.SaveAccount(a)
                StatusMessage = If(a.AccountID = 0, "تم إضافة الحساب بنجاح. ✅", "تم تحديث الحساب بنجاح. ✅")
                LoadAccounts()
                LoadParentAccounts()
                ExecuteNew(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDelete(obj As Object)
            If SelectedAccount Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من حذف هذا الحساب؟" & vbCrLf & "لن يتم الحذف إذا كان مستخدماً في قيود أو له حسابات فرعية.",
                               "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _accountingService.DeleteAccount(SelectedAccount.AccountID)
                    StatusMessage = "تم حذف الحساب. ✅"
                    LoadAccounts()
                    LoadParentAccounts()
                    ExecuteNew(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub
#End Region

    End Class
End Namespace
