Imports System.Collections.ObjectModel
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

        ' حقول التعديل
        Private _editAccountCode As String
        Private _editAccountName As String
        Private _editParentAccountID As Integer?
        Private _editAccountType As String
        Private _editAccountLevel As Integer
        Private _editIsTransactional As Boolean

        ' أخطاء
        Private _accountCodeError As String
        Private _accountNameError As String
        Private _statusMessage As String

        ' أنواع الحسابات
        Private _accountTypes As ObservableCollection(Of String)

        Public Sub New()
            AccountTypes = New ObservableCollection(Of String)({"Assets", "Liabilities", "Expenses", "Revenue"})
            LoadAccounts()
            LoadParentAccounts()
            EditIsTransactional = True
            EditAccountLevel = 1
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
                SetProperty(_selectedAccount, value)
                If value IsNot Nothing Then
                    EditAccountCode = value.AccountCode
                    EditAccountName = value.AccountName
                    EditParentAccountID = value.ParentAccountID
                    EditAccountType = value.AccountType
                    EditAccountLevel = value.AccountLevel
                    EditIsTransactional = value.IsTransactional
                    IsEditing = True
                    AccountCodeError = Nothing
                    AccountNameError = Nothing
                End If
            End Set
        End Property

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
                SetProperty(_editParentAccountID, value)
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
                Return New Helpers.RelayCommand(AddressOf ExecuteDelete, Function(o) SelectedAccount IsNot Nothing)
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
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل الحسابات الأب: " & ex.Message
            End Try
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
            AccountCodeError = Nothing
            AccountNameError = Nothing
        End Sub

        Private Sub ExecuteSave(obj As Object)
            If Not ValidateAccount() Then Return

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
