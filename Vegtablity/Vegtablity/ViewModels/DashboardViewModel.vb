Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class DashboardViewModel
        Inherits BaseViewModel

        Private ReadOnly _permissionService As New Services.PermissionService()
        Private _menuItems As ObservableCollection(Of MenuItem)
        Private _selectedMenuItem As MenuItem
        Private _currentUserName As String
        Private _currentRoleName As String
        Private _isSidebarExpanded As Boolean = True
        Private _currentPageTitle As String = "الرئيسية"
        Private _currentPage As Object
        Private _isHomePage As Boolean = True

        Public Sub New()
            If Services.Session.CurrentUser IsNot Nothing Then
                CurrentUserName = Services.Session.CurrentUser.FullName
                CurrentRoleName = Services.Session.CurrentUser.RoleName
            End If
            LoadMenuItems()
        End Sub

        Public Property MenuItems As ObservableCollection(Of MenuItem)
            Get
                Return _menuItems
            End Get
            Set(value As ObservableCollection(Of MenuItem))
                SetProperty(_menuItems, value)
            End Set
        End Property

        Public Property SelectedMenuItem As MenuItem
            Get
                Return _selectedMenuItem
            End Get
            Set(value As MenuItem)
                If _selectedMenuItem IsNot Nothing Then _selectedMenuItem.IsSelected = False
                SetProperty(_selectedMenuItem, value)
                If _selectedMenuItem IsNot Nothing Then
                    _selectedMenuItem.IsSelected = True
                    CurrentPageTitle = _selectedMenuItem.Title
                End If
            End Set
        End Property

        Public Property CurrentUserName As String
            Get
                Return _currentUserName
            End Get
            Set(value As String)
                SetProperty(_currentUserName, value)
            End Set
        End Property

        Public Property CurrentRoleName As String
            Get
                Return _currentRoleName
            End Get
            Set(value As String)
                SetProperty(_currentRoleName, value)
            End Set
        End Property

        Public Property IsSidebarExpanded As Boolean
            Get
                Return _isSidebarExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isSidebarExpanded, value)
            End Set
        End Property

        Public Property CurrentPageTitle As String
            Get
                Return _currentPageTitle
            End Get
            Set(value As String)
                SetProperty(_currentPageTitle, value)
            End Set
        End Property

        ''' <summary>
        ''' الصفحة الحالية المعروضة في منطقة المحتوى (UserControl)
        ''' </summary>
        Public Property CurrentPage As Object
            Get
                Return _currentPage
            End Get
            Set(value As Object)
                SetProperty(_currentPage, value)
            End Set
        End Property

        ''' <summary>
        ''' هل الصفحة الرئيسية معروضة (لإظهار/إخفاء الكروت)
        ''' </summary>
        Public Property IsHomePage As Boolean
            Get
                Return _isHomePage
            End Get
            Set(value As Boolean)
                SetProperty(_isHomePage, value)
            End Set
        End Property

        Public ReadOnly Property ToggleSidebarCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) IsSidebarExpanded = Not IsSidebarExpanded)
            End Get
        End Property

        Public ReadOnly Property LogoutCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteLogout)
            End Get
        End Property

        Public ReadOnly Property NavigateCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNavigate)
            End Get
        End Property

        Private Sub LoadMenuItems()
            Dim allItems As New List(Of MenuItem)()

            ' Define all navigation sections
            allItems.Add(New MenuItem With {.Title = "الرئيسية", .Icon = "🏠", .FormName = "Dashboard", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "المبيعات", .Icon = "🛒", .FormName = "Sales", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "المشتريات", .Icon = "📦", .FormName = "Purchases", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "المخزون", .Icon = "🏪", .FormName = "Inventory", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "الحسابات", .Icon = "📊", .FormName = "Accounting", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "العملاء والموردين", .Icon = "👥", .FormName = "Partners", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "التقارير", .Icon = "📈", .FormName = "Reports", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "الإعدادات", .Icon = "⚙", .FormName = "Settings", .IsVisible = True})
            allItems.Add(New MenuItem With {.Title = "إدارة المستخدمين", .Icon = "🔐", .FormName = "UserManagement", .IsVisible = True})

            ' Filter by permissions
            Dim isAdmin As Boolean = String.Equals(CurrentRoleName, "Admin", StringComparison.OrdinalIgnoreCase)
            Dim visibleItems As New ObservableCollection(Of MenuItem)()

            For Each item In allItems
                If isAdmin Then
                    visibleItems.Add(item)
                Else
                    ' Check DB permissions
                    If item.FormName = "Dashboard" Then
                        visibleItems.Add(item) ' Dashboard always visible
                    ElseIf Services.Session.CurrentUser IsNot Nothing Then
                        Try
                            Dim canView = _permissionService.CanViewForm(Services.Session.CurrentUser.RoleID, item.FormName)
                            If canView Then
                                visibleItems.Add(item)
                            End If
                        Catch
                            ' If permission check fails, show the item (fallback)
                            visibleItems.Add(item)
                        End Try
                    End If
                End If
            Next

            MenuItems = visibleItems

            ' Select first item (Dashboard)
            If MenuItems.Count > 0 Then
                SelectedMenuItem = MenuItems(0)
            End If
        End Sub

        Private Sub ExecuteNavigate(parameter As Object)
            Dim item = TryCast(parameter, MenuItem)
            If item IsNot Nothing Then
                SelectedMenuItem = item

                ' Navigate to page based on FormName
                Select Case item.FormName
                    Case "Dashboard"
                        CurrentPage = Nothing
                        IsHomePage = True

                    Case "UserManagement"
                        CurrentPage = New Views.UserManagementPage()
                        IsHomePage = False

                    Case "Settings"
                        CurrentPage = New Views.SettingsPage()
                        IsHomePage = False

                    Case Else
                        ' Future pages will be added here
                        CurrentPage = Nothing
                        IsHomePage = True
                End Select
            End If
        End Sub

        Private Sub ExecuteLogout(obj As Object)
            Services.Session.CurrentUser = Nothing
            Dim loginWin As New Views.LoginWindow()
            loginWin.Show()

            For Each win As Window In Application.Current.Windows
                If TypeOf win Is Views.DashboardWindow Then
                    win.Close()
                    Exit For
                End If
            Next
        End Sub
    End Class
End Namespace
