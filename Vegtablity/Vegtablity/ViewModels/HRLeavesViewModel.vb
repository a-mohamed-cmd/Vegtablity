Imports System
Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HRLeavesViewModel
        Inherits BaseViewModel

        Private ReadOnly _hrService As New HRService()
        Private ReadOnly _printer As New HRDocumentPrinter()

        ' === Pagination Properties ===
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

        ' === Collections & Models ===
        Public Property Leaves As ObservableCollection(Of EmployeeLeave)
        Public Property EmployeesList As ObservableCollection(Of Employee)
        Public Property FilteredEmployees As ObservableCollection(Of Employee)
        Public Property LeaveTypesList As ObservableCollection(Of LeaveType)

        Private _selectedEmployeeForLeave As Employee
        Public Property SelectedEmployeeForLeave As Employee
            Get
                Return _selectedEmployeeForLeave
            End Get
            Set(value As Employee)
                If SetProperty(_selectedEmployeeForLeave, value) Then
                    If value IsNot Nothing Then
                        If NewLeave IsNot Nothing Then
                            NewLeave.EmployeeID = value.EmployeeID
                        End If
                        LoadLeaveBalance(value.EmployeeID)
                    End If
                End If
            End Set
        End Property

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

        Private _selectedLeave As EmployeeLeave
        Public Property SelectedLeave As EmployeeLeave
            Get
                Return _selectedLeave
            End Get
            Set(value As EmployeeLeave)
                If SetProperty(_selectedLeave, value) AndAlso value IsNot Nothing Then
                    LoadLeaveBalance(value.EmployeeID)
                End If
            End Set
        End Property

        ' === New Leave Request Model ===
        Private _newLeave As EmployeeLeave
        Public Property NewLeave As EmployeeLeave
            Get
                Return _newLeave
            End Get
            Set(value As EmployeeLeave)
                SetProperty(_newLeave, value)
            End Set
        End Property

        ' === Resumption Model ===
        Private _resumptionActualDate As DateTime = DateTime.Today
        Public Property ResumptionActualDate As DateTime
            Get
                Return _resumptionActualDate
            End Get
            Set(value As DateTime)
                If SetProperty(_resumptionActualDate, value) Then
                    CalculateResumptionDelay()
                End If
            End Set
        End Property

        Private _resumptionNotes As String = ""
        Public Property ResumptionNotes As String
            Get
                Return _resumptionNotes
            End Get
            Set(value As String)
                SetProperty(_resumptionNotes, value)
            End Set
        End Property

        Private _delayDaysCount As Integer = 0
        Public Property DelayDaysCount As Integer
            Get
                Return _delayDaysCount
            End Get
            Set(value As Integer)
                SetProperty(_delayDaysCount, value)
            End Set
        End Property

        ' === Balance Summary ===
        Private _accruedDays As Decimal = 0
        Public Property AccruedDays As Decimal
            Get
                Return _accruedDays
            End Get
            Set(value As Decimal)
                SetProperty(_accruedDays, value)
            End Set
        End Property

        Private _usedDays As Integer = 0
        Public Property UsedDays As Integer
            Get
                Return _usedDays
            End Get
            Set(value As Integer)
                SetProperty(_usedDays, value)
            End Set
        End Property

        Private _remainingBalance As Decimal = 0
        Public Property RemainingBalance As Decimal
            Get
                Return _remainingBalance
            End Get
            Set(value As Decimal)
                SetProperty(_remainingBalance, value)
            End Set
        End Property

        ' === Commands ===
        Public Property NextPageCommand As ICommand
        Public Property PreviousPageCommand As ICommand
        Public Property SaveLeaveCommand As ICommand
        Public Property RecordResumptionCommand As ICommand
        Public Property PrintLeaveCommand As ICommand
        Public Property PrintCommencementCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Event RequestSnackbar As Action(Of String)

        Public Sub New()
            Leaves = New ObservableCollection(Of EmployeeLeave)()
            EmployeesList = New ObservableCollection(Of Employee)()
            FilteredEmployees = New ObservableCollection(Of Employee)()
            LeaveTypesList = New ObservableCollection(Of LeaveType)()

            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            SaveLeaveCommand = New RelayCommand(AddressOf SaveLeave)
            RecordResumptionCommand = New RelayCommand(AddressOf RecordResumption)
            PrintLeaveCommand = New RelayCommand(AddressOf PrintLeave)
            PrintCommencementCommand = New RelayCommand(AddressOf PrintCommencement)
            RefreshCommand = New RelayCommand(Sub() LoadLeaves())

            LoadPermissions("HRLeaves")
            ResetNewLeave()
            LoadInitialData()
            LoadLeaves()
        End Sub

        Private Sub LoadInitialData()
            Try
                Dim empRes = _hrService.GetEmployeesPaged(1, 1000)
                EmployeesList.Clear()
                FilteredEmployees.Clear()
                For Each emp In empRes.Data
                    EmployeesList.Add(emp)
                    FilteredEmployees.Add(emp)
                Next

                Dim ltList = _hrService.GetLeaveTypes()
                LeaveTypesList.Clear()
                For Each lt In ltList
                    LeaveTypesList.Add(lt)
                Next

                If EmployeesList.Any() Then
                    SelectedEmployeeForLeave = EmployeesList.First()
                End If
                If LeaveTypesList.Any() Then
                    NewLeave.LeaveTypeID = LeaveTypesList.First().LeaveTypeID
                End If
            Catch
            End Try
        End Sub

        Private Sub LoadLeaves()
            Try
                Dim result = _hrService.GetLeavesPaged(CurrentPage, PageSize)
                Leaves.Clear()
                For Each l In result.Data
                    Leaves.Add(l)
                Next
                TotalRecords = result.TotalCount
                NotifyPaginationChanged()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب سجل الإجازات: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Public Sub LoadLeaveBalance(employeeID As Integer)
            If employeeID <= 0 Then Return
            Try
                Dim bal = _hrService.GetLeaveBalance(employeeID)
                AccruedDays = bal.AccruedDays
                UsedDays = bal.UsedDays
                RemainingBalance = bal.RemainingBalance
            Catch
            End Try
        End Sub

        Private Sub ResetNewLeave()
            NewLeave = New EmployeeLeave With {
                .StartDate = DateTime.Today.AddDays(1),
                .EndDate = DateTime.Today.AddDays(7),
                .ExpectedReturnDate = DateTime.Today.AddDays(8),
                .DaysCount = 7,
                .Status = "Approved"
            }
        End Sub

        Private Sub SaveLeave(parameter As Object)
            If NewLeave.EmployeeID <= 0 Then
                MessageBox.Show("يرجى اختيار الموظف أولاً", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If NewLeave.EndDate < NewLeave.StartDate Then
                MessageBox.Show("تاريخ انتهاء الإجازة يجب أن يكون بعد تاريخ البدء", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            NewLeave.DaysCount = Math.Max(1, CInt((NewLeave.EndDate - NewLeave.StartDate).TotalDays) + 1)
            NewLeave.ExpectedReturnDate = NewLeave.EndDate.AddDays(1)
            NewLeave.ApprovedBy = If(Session.CurrentUser?.Username, "Admin")

            Try
                _hrService.SaveLeave(NewLeave)
                RaiseEvent RequestSnackbar("🏖️ تم تسجيل واعتماد طلب الإجازة بنجاح 👌")
                LoadLeaves()
                LoadLeaveBalance(NewLeave.EmployeeID)
                ResetNewLeave()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الإجازة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub CalculateResumptionDelay()
            If SelectedLeave Is Nothing Then Return
            Dim diff = CInt((ResumptionActualDate - SelectedLeave.ExpectedReturnDate).TotalDays)
            DelayDaysCount = Math.Max(0, diff)
        End Sub

        Private Sub RecordResumption(parameter As Object)
            If SelectedLeave Is Nothing Then
                MessageBox.Show("يرجى اختيار سجل الإجازة من القائمة أولاً", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                _hrService.RecordResumption(SelectedLeave.LeaveID, ResumptionActualDate, ResumptionActualDate, ResumptionNotes)
                RaiseEvent RequestSnackbar("🏢 تم تسجيل مباشرة العمل وتحديث حالة الموظف إلى نشط (Active) بنجاح 👌")
                LoadLeaves()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تسجيل المباشرة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub PrintLeave(parameter As Object)
            Dim l = If(TryCast(parameter, EmployeeLeave), SelectedLeave)
            If l Is Nothing Then
                MessageBox.Show("يرجى اختيار إجازة لطباعتها", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If
            Dim emp = _hrService.GetEmployeeById(l.EmployeeID)
            _printer.PrintLeaveApplication(emp, l, RemainingBalance)
        End Sub

        Private Sub PrintCommencement(parameter As Object)
            Dim l = If(TryCast(parameter, EmployeeLeave), SelectedLeave)
            If l Is Nothing Then
                MessageBox.Show("يرجى اختيار إجازة لطباعة نموذج مباشرتها", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If
            Dim emp = _hrService.GetEmployeeById(l.EmployeeID)
            _printer.PrintJobCommencement(emp, l, l.ResumptionNotes)
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
                LoadLeaves()
            End If
        End Sub

        Public Sub GoToPreviousPage()
            If HasPreviousPage Then
                CurrentPage -= 1
                LoadLeaves()
            End If
        End Sub
    End Class
End Namespace
