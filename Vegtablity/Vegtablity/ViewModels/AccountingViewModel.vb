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
        Private _selectedNode As AccountNode
        Private _accountTree As ObservableCollection(Of AccountNode)
        Private _allTreeNodes As List(Of AccountNode)
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

        ' إحصائيات الشجرة
        Private _totalAccountsCount As Integer
        Private _rootAccountsCount As Integer
        Private _transactionalAccountsCount As Integer

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
                BuildAccountTree()
            End Set
        End Property

        Public Property AccountTree As ObservableCollection(Of AccountNode)
            Get
                Return _accountTree
            End Get
            Set(value As ObservableCollection(Of AccountNode))
                SetProperty(_accountTree, value)
            End Set
        End Property

        Public Property SelectedNode As AccountNode
            Get
                Return _selectedNode
            End Get
            Set(value As AccountNode)
                If SetProperty(_selectedNode, value) Then
                    If value IsNot Nothing AndAlso value.Account IsNot Nothing Then
                        SelectedAccount = value.Account
                    End If
                End If
            End Set
        End Property

        Public Property TotalAccountsCount As Integer
            Get
                Return _totalAccountsCount
            End Get
            Set(value As Integer)
                SetProperty(_totalAccountsCount, value)
            End Set
        End Property

        Public Property RootAccountsCount As Integer
            Get
                Return _rootAccountsCount
            End Get
            Set(value As Integer)
                SetProperty(_rootAccountsCount, value)
            End Set
        End Property

        Public Property TransactionalAccountsCount As Integer
            Get
                Return _transactionalAccountsCount
            End Get
            Set(value As Integer)
                SetProperty(_transactionalAccountsCount, value)
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
                If SetProperty(_selectedAccount, value) Then
                    UpdateFieldsFromSelected()
                End If
            End Set
        End Property

        Private Sub UpdateFieldsFromSelected()
            _isInternalSync = True
            
            Try
                AccountCodeError = Nothing
                AccountNameError = Nothing

                If _selectedAccount IsNot Nothing Then
                    UpdateDisplayParentAccounts()
                    
                    IsEditing = True
                    PanelTitle = "✏️ تعديل بيانات الحساب"
                    SaveActionText = "تحديث"

                    EditAccountCode = _selectedAccount.AccountCode
                    EditAccountName = _selectedAccount.AccountName
                    EditParentAccountID = _selectedAccount.ParentAccountID
                    EditAccountType = _selectedAccount.AccountType
                    EditAccountLevel = _selectedAccount.AccountLevel
                    EditIsTransactional = _selectedAccount.IsTransactional
                    
                    Dim hasChildren = If(Accounts IsNot Nothing, Accounts.Any(Function(a) a.ParentAccountID.HasValue AndAlso a.ParentAccountID.Value = _selectedAccount.AccountID), False)
                    IsTransactionalEnabled = Not hasChildren
                    
                    StatusMessage = "✅ تم تحديد الحساب: [" & _selectedAccount.AccountCode & " - " & _selectedAccount.AccountName & "]"
                Else
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
                    StatusMessage = "ℹ️ في انتظار اختيار أو إضافة حساب..."
                End If
            Catch ex As Exception
                StatusMessage = "❌ خطأ في تحميل البيانات: " & ex.Message
            Finally
                _isInternalSync = False
            End Try
            
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
                FilterAccountTree(value)
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
                    If Not _isInternalSync Then
                        If value.HasValue AndAlso ParentAccounts IsNot Nothing Then
                            Dim parent = ParentAccounts.FirstOrDefault(Function(a) a.AccountID = value.Value)
                            If parent IsNot Nothing Then
                                EditAccountLevel = parent.AccountLevel + 1
                                EditAccountType = parent.AccountType
                            End If
                        ElseIf Not value.HasValue Then
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

        Public ReadOnly Property ExpandAllTreeCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If _allTreeNodes IsNot Nothing Then
                        For Each node In _allTreeNodes
                            node.IsExpanded = True
                        Next
                    End If
                End Sub)
            End Get
        End Property

        Public ReadOnly Property CollapseAllTreeCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                    If _allTreeNodes IsNot Nothing Then
                        For Each node In _allTreeNodes
                            node.IsExpanded = False
                        Next
                    End If
                End Sub)
            End Get
        End Property

        Public ReadOnly Property AddChildAccountCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteAddChildAccount)
            End Get
        End Property
#End Region

#Region "Methods & Tree Construction"
        Private Sub LoadAccounts()
            Try
                Dim list = _accountingService.GetAllAccounts()
                Accounts = New ObservableCollection(Of Account)(list)
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل الحسابات: " & ex.Message
            End Try
        End Sub

        Private Sub BuildAccountTree()
            If Accounts Is Nothing OrElse Accounts.Count = 0 Then
                AccountTree = New ObservableCollection(Of AccountNode)()
                _allTreeNodes = New List(Of AccountNode)()
                TotalAccountsCount = 0
                RootAccountsCount = 0
                TransactionalAccountsCount = 0
                Return
            End If

            TotalAccountsCount = Accounts.Count
            TransactionalAccountsCount = Accounts.Where(Function(a) a.IsTransactional).Count()

            ' Group by ParentAccountID
            Dim accountMap = Accounts.ToDictionary(Function(a) a.AccountID)
            Dim childrenLookup = Accounts.Where(Function(a) a.ParentAccountID.HasValue).ToLookup(Function(a) a.ParentAccountID.Value)

            ' Root Accounts (Level 0): ParentAccountID is Nothing or 0 or Parent ID not found in current dictionary
            Dim rootAccounts = Accounts.Where(Function(a) Not a.ParentAccountID.HasValue OrElse a.ParentAccountID.Value = 0 OrElse Not accountMap.ContainsKey(a.ParentAccountID.Value)).OrderBy(Function(a) a.AccountCode).ToList()

            RootAccountsCount = rootAccounts.Count

            Dim allNodes As New List(Of AccountNode)()
            Dim treeRoots As New ObservableCollection(Of AccountNode)()

            For Each rootAcc In rootAccounts
                Dim rootNode = CreateNodeRecursive(rootAcc, Nothing, 0, childrenLookup, allNodes)
                treeRoots.Add(rootNode)
            Next

            _allTreeNodes = allNodes
            AccountTree = treeRoots
        End Sub

        Private Function CreateNodeRecursive(acc As Account, parent As AccountNode, currentLevel As Integer, childrenLookup As ILookup(Of Integer, Account), allNodes As List(Of AccountNode)) As AccountNode
            Dim node As New AccountNode(acc, parent, currentLevel)
            allNodes.Add(node)

            If childrenLookup.Contains(acc.AccountID) Then
                For Each childAcc In childrenLookup(acc.AccountID).OrderBy(Function(c) c.AccountCode)
                    Dim childNode = CreateNodeRecursive(childAcc, node, currentLevel + 1, childrenLookup, allNodes)
                    node.Children.Add(childNode)
                Next
            End If

            Return node
        End Function

        Private Sub FilterAccountTree(query As String)
            If _allTreeNodes Is Nothing Then Return

            If String.IsNullOrWhiteSpace(query) Then
                ' Reset all nodes visibility & highlight
                For Each node In _allTreeNodes
                    node.IsVisible = True
                    node.IsHighlighted = False
                Next
                Return
            End If

            Dim term = query.Trim().ToLowerInvariant()

            ' 1. Reset
            For Each node In _allTreeNodes
                node.IsVisible = False
                node.IsHighlighted = False
            Next

            ' 2. Mark matching nodes and unhide their entire path
            For Each node In _allTreeNodes
                Dim match = (node.AccountCode IsNot Nothing AndAlso node.AccountCode.ToLowerInvariant().Contains(term)) OrElse
                            (node.AccountName IsNot Nothing AndAlso node.AccountName.ToLowerInvariant().Contains(term))

                If match Then
                    node.IsVisible = True
                    node.IsHighlighted = True
                    node.IsExpanded = True

                    ' Unhide and expand all ancestors
                    Dim p = node.ParentNode
                    While p IsNot Nothing
                        p.IsVisible = True
                        p.IsExpanded = True
                        p = p.ParentNode
                    End While

                    ' Also make all direct children visible so user sees the context
                    If node.Children IsNot Nothing Then
                        For Each c In node.Children
                            c.IsVisible = True
                        Next
                    End If
                End If
            Next
        End Sub

        Private Sub ExecuteAddChildAccount(obj As Object)
            Dim targetNode = TryCast(obj, AccountNode)
            If targetNode Is Nothing Then targetNode = SelectedNode
            If targetNode Is Nothing Then
                ExecuteNew(Nothing)
                Return
            End If

            ' Initialize Add mode under this parent
            SelectedAccount = Nothing
            IsEditing = False
            EditAccountCode = SuggestNextChildCode(targetNode.Account.AccountCode)
            EditAccountName = ""
            EditParentAccountID = targetNode.Account.AccountID
            EditAccountType = targetNode.Account.AccountType
            EditAccountLevel = targetNode.Level + 1
            EditIsTransactional = True
            IsTransactionalEnabled = True
            
            PanelTitle = "➕ إضافة حساب فرعي تابع لـ: [" & targetNode.Account.AccountName & "]"
            SaveActionText = "إضافة الحساب الفرعي"
            AccountCodeError = Nothing
            AccountNameError = Nothing
            StatusMessage = "جاهز لإضافة حساب فرعي للمستوى " & (targetNode.Level + 1)
        End Sub

        Private Function SuggestNextChildCode(parentCode As String) As String
            If String.IsNullOrEmpty(parentCode) Then Return ""
            If Accounts Is Nothing Then Return parentCode & "01"

            Dim existingSiblings = Accounts.Where(Function(a) a.AccountCode.StartsWith(parentCode) AndAlso a.AccountCode.Length > parentCode.Length).Select(Function(a) a.AccountCode).ToList()
            If existingSiblings.Count = 0 Then
                Return parentCode & "01"
            End If

            ' Find max numeric suffix if possible
            Dim maxSuffix As Long = 0
            For Each code In existingSiblings
                Dim subPart = code.Substring(parentCode.Length)
                Dim num As Long
                If Long.TryParse(subPart, num) AndAlso num > maxSuffix Then
                    maxSuffix = num
                End If
            Next

            Dim nextNum = maxSuffix + 1
            Return parentCode & nextNum.ToString().PadLeft(2, "0"c)
        End Function

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
            
            If SelectedAccount IsNot Nothing Then
                Dim invalidIDs As New HashSet(Of Integer)()
                invalidIDs.Add(SelectedAccount.AccountID)
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
            Dim children = Accounts.Where(Function(a) a.ParentAccountID.HasValue AndAlso a.ParentAccountID.Value = parentID).Select(Function(a) a.AccountID).ToList()
            For Each childID In children
                If visitedSet.Add(childID) Then
                    AddDescendantsToSet(childID, visitedSet)
                End If
            Next
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
            SelectedNode = Nothing
            SelectedAccount = Nothing
            EditAccountCode = ""
            EditAccountName = ""
            EditParentAccountID = Nothing
            EditAccountType = "Assets"
            EditAccountLevel = 0
            EditIsTransactional = True
            IsEditing = False
            PanelTitle = "📁 إضافة حساب رئيسي جديد (مستوى 0)"
            SaveActionText = "إضافة"
            AccountCodeError = Nothing
            AccountNameError = Nothing
            StatusMessage = "تم البدء بإضافة حساب رئيسي جديد."
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

            If IsEditing AndAlso SelectedAccount IsNot Nothing Then
                If MessageBox.Show("هل أنت متأكد من حفظ التعديلات على حساب: " & SelectedAccount.AccountName & "؟",
                                   "تأكيد التعديل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.No Then
                    Return
                End If
            End If

            Try
                Dim targetID = If(IsEditing AndAlso SelectedAccount IsNot Nothing, SelectedAccount.AccountID, 0)
                Dim a As New Account With {
                    .AccountID = targetID,
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

                ' Locate and re-select node in tree
                If _allTreeNodes IsNot Nothing Then
                    Dim node = _allTreeNodes.FirstOrDefault(Function(n) n.Account.AccountCode = a.AccountCode)
                    If node IsNot Nothing Then
                        node.IsSelected = True
                        SelectedNode = node
                    End If
                End If
            Catch ex As Exception
                StatusMessage = "خطأ في حفظ الحساب: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDelete(obj As Object)
            If SelectedAccount Is Nothing Then Return
            
            Dim hasChildren = If(Accounts IsNot Nothing, Accounts.Any(Function(a) a.ParentAccountID.HasValue AndAlso a.ParentAccountID.Value = SelectedAccount.AccountID), False)
            If hasChildren Then
                MessageBox.Show("لا يمكن حذف حساب رئيسي يحتوي على حسابات فرعية تابعة له. يرجى حذف الحسابات الفرعية أولاً.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If MessageBox.Show("هل أنت متأكد من حذف الحساب: " & SelectedAccount.AccountName & "؟" & vbCrLf & "ملاحظة: لا يمكن حذف حساب عليه قيود محاسبية مسجلة.",
                               "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _accountingService.DeleteAccount(SelectedAccount.AccountID)
                    StatusMessage = "تم حذف الحساب بنجاح. ✅"
                    LoadAccounts()
                    LoadParentAccounts()
                    ExecuteNew(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ في حذف الحساب: " & ex.Message
                End Try
            End If
        End Sub
#End Region
    End Class
End Namespace
