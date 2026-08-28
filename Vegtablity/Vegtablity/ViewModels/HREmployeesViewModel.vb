Imports System
Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HREmployeesViewModel
        Inherits BaseViewModel

        Private ReadOnly _hrService As New HRService()
        Private ReadOnly _printer As New HRDocumentPrinter()

        ' === Pagination Properties (10 per page) ===
        Private _currentPage As Integer = 1
        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                SetProperty(_currentPage, value)
            End Set
        End Property

        Public Const PageSize As Integer = 10

        Private _totalRecords As Integer = 0
        Public Property TotalRecords As Integer
            Get
                Return _totalRecords
            End Get
            Set(value As Integer)
                SetProperty(_totalRecords, value)
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(TotalRecords / CDbl(PageSize))))
            End Get
        End Property

        Public ReadOnly Property HasPreviousPage As Boolean
            Get
                Return CurrentPage > 1
            End Get
        End Property

        Public ReadOnly Property HasNextPage As Boolean
            Get
                Return CurrentPage < TotalPages
            End Get
        End Property

        Public ReadOnly Property PageInfo As String
            Get
                Return $"صفحة {CurrentPage} من {TotalPages} (إجمالي: {TotalRecords})"
            End Get
        End Property

        ' === Filtering Properties ===
        Private _searchText As String = ""
        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                If SetProperty(_searchText, value) Then
                    CurrentPage = 1
                    LoadEmployees()
                End If
            End Set
        End Property

        Private _selectedDepartment As String = "الكل"
        Public Property SelectedDepartment As String
            Get
                Return _selectedDepartment
            End Get
            Set(value As String)
                If SetProperty(_selectedDepartment, value) Then
                    CurrentPage = 1
                    LoadEmployees()
                End If
            End Set
        End Property

        Private _selectedStatusFilter As String = "الكل"
        Public Property SelectedStatusFilter As String
            Get
                Return _selectedStatusFilter
            End Get
            Set(value As String)
                If SetProperty(_selectedStatusFilter, value) Then
                    CurrentPage = 1
                    LoadEmployees()
                End If
            End Set
        End Property

        Public Property DepartmentsList As ObservableCollection(Of String)
        Public Property StatusList As ObservableCollection(Of String)

        ' === Employees Collection ===
        Public Property Employees As ObservableCollection(Of Employee)

        Private _selectedEmployee As Employee
        Public Property SelectedEmployee As Employee
            Get
                Return _selectedEmployee
            End Get
            Set(value As Employee)
                If SetProperty(_selectedEmployee, value) AndAlso value IsNot Nothing Then
                    LoadEmployeeDetails(value.EmployeeID)
                End If
            End Set
        End Property

        ' === Editing Model ===
        Private _editEmployee As Employee
        Public Property EditEmployee As Employee
            Get
                Return _editEmployee
            End Get
            Set(value As Employee)
                SetProperty(_editEmployee, value)
            End Set
        End Property

        ' === Commands ===
        Public Property NextPageCommand As ICommand
        Public Property PreviousPageCommand As ICommand
        Public Property FirstPageCommand As ICommand
        Public Property LastPageCommand As ICommand
        Public Property SaveEmployeeCommand As ICommand
        Public Property NewEmployeeCommand As ICommand
        Public Property DeleteEmployeeCommand As ICommand
        Public Property RefreshCommand As ICommand
        Public Property PrintCommencementCommand As ICommand

        Public Event RequestSnackbar As Action(Of String)

        Public Sub New()
            Employees = New ObservableCollection(Of Employee)()
            DepartmentsList = New ObservableCollection(Of String) From {"الكل", "الإدارة المالية", "المستودعات والمخازن", "المبيعات والتسويق", "المطبخ والإنتاج", "الموارد البشرية", "خدمة العملاء", "أخرى"}
            StatusList = New ObservableCollection(Of String) From {"الكل", "Active", "OnLeave", "Resigned", "Terminated"}

            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            FirstPageCommand = New RelayCommand(AddressOf GoToFirstPage, Function() HasPreviousPage)
            LastPageCommand = New RelayCommand(AddressOf GoToLastPage, Function() HasNextPage)

            SaveEmployeeCommand = New RelayCommand(AddressOf SaveEmployee)
            NewEmployeeCommand = New RelayCommand(AddressOf NewEmployee)
            DeleteEmployeeCommand = New RelayCommand(AddressOf DeleteEmployee)
            RefreshCommand = New RelayCommand(Sub() LoadEmployees())
            PrintCommencementCommand = New RelayCommand(AddressOf PrintCommencement)

            LoadPermissions("HREmployees")
            NewEmployee(Nothing)
            LoadEmployees()
        End Sub

        Private Sub LoadEmployees()
            Try
                Dim dept = If(SelectedDepartment = "الكل", Nothing, SelectedDepartment)
                Dim status = If(SelectedStatusFilter = "الكل", Nothing, SelectedStatusFilter)

                Dim result = _hrService.GetEmployeesPaged(CurrentPage, PageSize, SearchText, dept, status)
                Employees.Clear()
                For Each emp In result.Data
                    Employees.Add(emp)
                Next
                TotalRecords = result.TotalCount
                NotifyPaginationChanged()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تحميل بيانات الموظفين: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub LoadEmployeeDetails(employeeID As Integer)
            Try
                Dim emp = _hrService.GetEmployeeById(employeeID)
                If emp IsNot Nothing Then
                    ' Ensure all custom field definitions are represented
                    Dim allDefs = _hrService.GetCustomFields()
                    For Each def In allDefs
                        If Not emp.CustomValues.Any(Function(cv) cv.FieldID = def.FieldID) Then
                            emp.CustomValues.Add(New EmployeeCustomValue With {
                                .EmployeeID = emp.EmployeeID,
                                .FieldID = def.FieldID,
                                .FieldKey = def.FieldKey,
                                .FieldNameAr = def.FieldNameAr,
                                .FieldType = def.FieldType,
                                .IsAlertable = def.IsAlertable,
                                .AlertDaysBefore = def.AlertDaysBefore
                            })
                        End If
                    Next
                    EditEmployee = emp
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب تفاصيل الموظف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub NewEmployee(parameter As Object)
            Dim newEmp As New Employee() With {
                .EmployeeCode = "EMP-" & (TotalRecords + 1).ToString("D3"),
                .FullName = String.Empty,
                .HireDate = DateTime.Today,
                .Department = "الإدارة المالية",
                .JobTitle = "موظف",
                .Status = "Active"
            }

            ' Pre-populate custom field definitions
            Try
                Dim defs = _hrService.GetCustomFields()
                For Each def In defs
                    newEmp.CustomValues.Add(New EmployeeCustomValue With {
                        .FieldID = def.FieldID,
                        .FieldKey = def.FieldKey,
                        .FieldNameAr = def.FieldNameAr,
                        .FieldType = def.FieldType,
                        .IsAlertable = def.IsAlertable,
                        .AlertDaysBefore = def.AlertDaysBefore
                    })
                Next
            Catch
            End Try

            EditEmployee = newEmp
            SelectedEmployee = Nothing
        End Sub

        Private Sub SaveEmployee(parameter As Object)
            If EditEmployee Is Nothing Then Return
            If String.IsNullOrWhiteSpace(EditEmployee.FullName) Then
                MessageBox.Show("يرجى إدخال اسم الموظف الكامل", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If
            If String.IsNullOrWhiteSpace(EditEmployee.EmployeeCode) Then
                MessageBox.Show("يرجى إدخال كود أو رقم الموظف", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If EditEmployee.BasicSalary < 0 Then
                MessageBox.Show("لا يمكن أن تكون قيمة الراتب الأساسي أقل من الصفر", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If EditEmployee.HousingAllowance < 0 OrElse EditEmployee.TransportAllowance < 0 OrElse EditEmployee.OtherAllowances < 0 Then
                MessageBox.Show("لا يمكن أن تكون قيمة أي من البدلات سالبة", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Dim isUpdate = (EditEmployee.EmployeeID > 0)
            Try
                Dim username = If(Session.CurrentUser?.Username, "Admin")
                Dim id = _hrService.SaveEmployee(EditEmployee, username)
                EditEmployee.EmployeeID = id
                If isUpdate Then
                    RaiseEvent RequestSnackbar("💾 تم تعديل وحفظ بيانات الموظف بنجاح 👌")
                Else
                    RaiseEvent RequestSnackbar("✅ تم إضافة الموظف الجديد وحفظ بياناته بنجاح 👌")
                End If
                LoadEmployees()
                SelectedEmployee = Employees.FirstOrDefault(Function(e) e.EmployeeID = id)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الموظف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub DeleteEmployee(parameter As Object)
            If EditEmployee Is Nothing OrElse EditEmployee.EmployeeID <= 0 Then
                MessageBox.Show("يرجى اختيار موظف مسجل لحذفه", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If MessageBox.Show($"هل أنت متأكد من حذف بيانات الموظف '{EditEmployee.FullName}' وكافة سجلاته وحقوله؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    _hrService.DeleteEmployee(EditEmployee.EmployeeID)
                    RaiseEvent RequestSnackbar("🗑️ تم حذف بيانات الموظف بنجاح من قاعدة البيانات")
                    NewEmployee(Nothing)
                    LoadEmployees()
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء حذف الموظف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Sub PrintCommencement(parameter As Object)
            If EditEmployee Is Nothing OrElse EditEmployee.EmployeeID <= 0 Then
                MessageBox.Show("يرجى اختيار موظف أولاً لطباعة نموذج المباشرة", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If
            _printer.PrintJobCommencement(EditEmployee, Nothing, "مباشرة عمل وتعيين جديد")
        End Sub

        Private Sub NotifyPaginationChanged()
            OnPropertyChanged(NameOf(CurrentPage))
            OnPropertyChanged(NameOf(TotalRecords))
            OnPropertyChanged(NameOf(TotalPages))
            OnPropertyChanged(NameOf(HasPreviousPage))
            OnPropertyChanged(NameOf(HasNextPage))
            OnPropertyChanged(NameOf(PageInfo))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        Public Sub GoToNextPage()
            If HasNextPage Then
                CurrentPage += 1
                LoadEmployees()
            End If
        End Sub

        Public Sub GoToPreviousPage()
            If HasPreviousPage Then
                CurrentPage -= 1
                LoadEmployees()
            End If
        End Sub

        Public Sub GoToFirstPage()
            If CurrentPage <> 1 Then
                CurrentPage = 1
                LoadEmployees()
            End If
        End Sub

        Public Sub GoToLastPage()
            If CurrentPage <> TotalPages Then
                CurrentPage = TotalPages
                LoadEmployees()
            End If
        End Sub
    End Class
End Namespace
