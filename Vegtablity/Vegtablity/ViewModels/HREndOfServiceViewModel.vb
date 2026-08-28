Imports System
Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HREndOfServiceViewModel
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

        ' === Events & Searchable Properties ===
        Public Event RequestSnackbar As Action(Of String)

        ' === Collections & Models ===
        Public Property Settlements As ObservableCollection(Of EndOfServiceSettlement)
        Public Property EmployeesList As ObservableCollection(Of Employee)
        Public Property FilteredEmployees As ObservableCollection(Of Employee)
        Public Property DepartureReasonsList As ObservableCollection(Of String)

        Private _selectedEmployee As Employee
        Public Property SelectedEmployee As Employee
            Get
                Return _selectedEmployee
            End Get
            Set(value As Employee)
                If SetProperty(_selectedEmployee, value) Then
                    If value IsNot Nothing Then
                        OnEmployeeSelected(value)
                    End If
                End If
            End Set
        End Property

        Private _selectedSettlement As EndOfServiceSettlement
        Public Property SelectedSettlement As EndOfServiceSettlement
            Get
                Return _selectedSettlement
            End Get
            Set(value As EndOfServiceSettlement)
                SetProperty(_selectedSettlement, value)
            End Set
        End Property

        Private _currentSettlement As EndOfServiceSettlement
        Public Property CurrentSettlement As EndOfServiceSettlement
            Get
                Return _currentSettlement
            End Get
            Set(value As EndOfServiceSettlement)
                SetProperty(_currentSettlement, value)
            End Set
        End Property

        ' === Commands ===
        Public Property NextPageCommand As ICommand
        Public Property PreviousPageCommand As ICommand
        Public Property SaveSettlementCommand As ICommand
        Public Property CalculateCommand As ICommand
        Public Property PrintSettlementCommand As ICommand
        Public Property NewSettlementCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Sub New()
            Settlements = New ObservableCollection(Of EndOfServiceSettlement)()
            EmployeesList = New ObservableCollection(Of Employee)()
            FilteredEmployees = New ObservableCollection(Of Employee)()
            DepartureReasonsList = New ObservableCollection(Of String) From {"Termination", "Resignation", "ContractExpiry", "Retirement"}

            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            SaveSettlementCommand = New RelayCommand(AddressOf SaveSettlement)
            CalculateCommand = New RelayCommand(AddressOf Recalculate)
            PrintSettlementCommand = New RelayCommand(AddressOf PrintSettlement)
            NewSettlementCommand = New RelayCommand(AddressOf ResetNewSettlement)
            RefreshCommand = New RelayCommand(Sub() LoadSettlements())

            LoadPermissions("HREndOfService")
            ResetNewSettlement(Nothing)
            LoadEmployees()
            LoadSettlements()
        End Sub

        Private Sub LoadEmployees()
            Try
                Dim res = _hrService.GetEmployeesPaged(1, 1000)
                EmployeesList.Clear()
                FilteredEmployees.Clear()
                For Each emp In res.Data
                    EmployeesList.Add(emp)
                    FilteredEmployees.Add(emp)
                Next

                If EmployeesList.Any() Then
                    SelectedEmployee = EmployeesList.First()
                End If
            Catch
            End Try
        End Sub

        Public Sub FilterEmployees(query As String)
            If String.IsNullOrWhiteSpace(query) Then
                FilteredEmployees.Clear()
                For Each emp In EmployeesList
                    FilteredEmployees.Add(emp)
                Next
            Else
                Dim q = query.Trim().ToLower()
                FilteredEmployees.Clear()
                For Each emp In EmployeesList.Where(Function(e) (e.FullName IsNot Nothing AndAlso e.FullName.ToLower().Contains(q)) OrElse
                                                                (e.EmployeeCode IsNot Nothing AndAlso e.EmployeeCode.ToLower().Contains(q)) OrElse
                                                                (e.JobTitle IsNot Nothing AndAlso e.JobTitle.ToLower().Contains(q)) OrElse
                                                                (e.Department IsNot Nothing AndAlso e.Department.ToLower().Contains(q)))
                    FilteredEmployees.Add(emp)
                Next
            End If
        End Sub

        Public Sub OnEmployeeSelected(emp As Employee)
            If emp Is Nothing OrElse CurrentSettlement Is Nothing Then Return
            CurrentSettlement.EmployeeID = emp.EmployeeID
            CurrentSettlement.EmployeeCode = emp.EmployeeCode
            CurrentSettlement.EmployeeName = emp.FullName
            CurrentSettlement.Department = emp.Department
            CurrentSettlement.HireDate = emp.HireDate
            CurrentSettlement.LastBasicSalary = emp.BasicSalary
            CurrentSettlement.LastAllowances = emp.HousingAllowance + emp.TransportAllowance + emp.OtherAllowances

            ' Fetch leave balance
            Try
                Dim bal = _hrService.GetLeaveBalance(emp.EmployeeID)
                CurrentSettlement.UnpaidLeaveBalanceDays = bal.RemainingBalance
            Catch
            End Try

            Recalculate(Nothing)
        End Sub

        Private Sub ResetNewSettlement(parameter As Object)
            CurrentSettlement = New EndOfServiceSettlement With {
                .EndDate = DateTime.Today,
                .DepartureReason = "Termination",
                .Status = "Approved"
            }
            If EmployeesList.Any() Then
                SelectedEmployee = EmployeesList.First()
            End If
            RaiseEvent RequestSnackbar("➕ تم فتح نموذج تصفية نهاية خدمة جديد")
        End Sub

        Public Sub Recalculate(parameter As Object)
            If CurrentSettlement Is Nothing Then Return
            CurrentSettlement.Calculate()
            OnPropertyChanged(NameOf(CurrentSettlement))
        End Sub

        Private Sub LoadSettlements()
            Try
                Dim res = _hrService.GetEndOfServiceSettlementsPaged(CurrentPage, PageSize)
                Settlements.Clear()
                For Each s In res.Data
                    Settlements.Add(s)
                Next
                TotalRecords = res.TotalCount
                NotifyPaginationChanged()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب تصفيات نهاية الخدمة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub SaveSettlement(parameter As Object)
            If CurrentSettlement.EmployeeID <= 0 Then
                RaiseEvent RequestSnackbar("⚠️ يرجى اختيار الموظف أولاً")
                Return
            End If

            Recalculate(Nothing)

            Try
                Dim user = If(Session.CurrentUser?.Username, "Admin")
                _hrService.SaveEndOfServiceSettlement(CurrentSettlement, user)
                RaiseEvent RequestSnackbar($"💾 تم حفظ واعتماد تصفية نهاية الخدمة للموظف ({CurrentSettlement.EmployeeName}) بنجاح!")
                LoadSettlements()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ التصفية: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Public Sub PrintSettlement(parameter As Object)
            Dim s = If(TryCast(parameter, EndOfServiceSettlement), CurrentSettlement)
            If s Is Nothing OrElse s.EmployeeID <= 0 Then
                RaiseEvent RequestSnackbar("⚠️ يرجى اختيار تصفية لطباعتها")
                Return
            End If

            Try
                Dim emp = _hrService.GetEmployeeById(s.EmployeeID)
                _printer.PrintEndOfServiceSettlement(emp, s)
                RaiseEvent RequestSnackbar($"🖨️ جاري طباعة مخالصة نهاية الخدمة للموظف ({s.EmployeeName})...")
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الطباعة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
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
                LoadSettlements()
            End If
        End Sub

        Public Sub GoToPreviousPage()
            If HasPreviousPage Then
                CurrentPage -= 1
                LoadSettlements()
            End If
        End Sub
    End Class
End Namespace
