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

        ' === Mode & UI State ===
        Private _isEditMode As Boolean = False
        Public Property IsEditMode As Boolean
            Get
                Return _isEditMode
            End Get
            Set(value As Boolean)
                If SetProperty(_isEditMode, value) Then
                    NotifyStateChanged()
                End If
            End Set
        End Property

        Public ReadOnly Property FormTitle As String
            Get
                If IsEditMode AndAlso NewLeave IsNot Nothing AndAlso NewLeave.LeaveID > 0 Then
                    Return $"✏️ تعديل بيانات الإجازة (رقم السجل: #{NewLeave.LeaveID})"
                Else
                    Return "🏖️ تقديم طلب إجازة جديد"
                End If
            End Get
        End Property

        Public ReadOnly Property SaveButtonText As String
            Get
                If IsEditMode Then
                    Return "💾 حفظ التعديلات على الإجازة"
                Else
                    Return "✈️ تسجيل واعتماد الإجازة"
                End If
            End Get
        End Property

        Public ReadOnly Property SaveButtonBackground As String
            Get
                If IsEditMode Then
                    Return "#059669"
                Else
                    Return "#4F46E5"
                End If
            End Get
        End Property

        ' === Permissions ===
        Public ReadOnly Property CanAdd As Boolean
            Get
                Return CurrentPermissions Is Nothing OrElse CurrentPermissions.CanAdd
            End Get
        End Property

        Public ReadOnly Property CanEdit As Boolean
            Get
                Return CurrentPermissions Is Nothing OrElse CurrentPermissions.CanEdit
            End Get
        End Property

        Public ReadOnly Property CanDelete As Boolean
            Get
                Return CurrentPermissions Is Nothing OrElse CurrentPermissions.CanDelete
            End Get
        End Property

        Public ReadOnly Property CanPrint As Boolean
            Get
                Return CurrentPermissions Is Nothing OrElse CurrentPermissions.CanPrint
            End Get
        End Property

        Public ReadOnly Property CanSaveLeave As Boolean
            Get
                If IsEditMode Then
                    Return CanEdit
                Else
                    Return CanAdd
                End If
            End Get
        End Property

        Public ReadOnly Property CanRecordResumption As Boolean
            Get
                Return CanEdit AndAlso SelectedLeave IsNot Nothing
            End Get
        End Property

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
                            NewLeave.EmployeeCode = value.EmployeeCode
                            NewLeave.EmployeeName = value.FullName
                            NewLeave.Department = value.Department
                        End If
                        LoadLeaveBalance(value.EmployeeID)
                    Else
                        If NewLeave IsNot Nothing AndAlso Not IsEditMode Then
                            NewLeave.EmployeeID = 0
                            NewLeave.EmployeeCode = String.Empty
                            NewLeave.EmployeeName = String.Empty
                            NewLeave.Department = String.Empty
                        End If
                        AccruedDays = 0
                        UsedDays = 0
                        RemainingBalance = 0
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
                If SetProperty(_selectedLeave, value) Then
                    If value IsNot Nothing Then
                        LoadSelectedLeaveDetails(value)
                    End If
                    NotifyStateChanged()
                End If
            End Set
        End Property

        ' === New / Edit Leave Request Model ===
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
        Public Property NewLeaveCommand As ICommand
        Public Property SaveLeaveCommand As ICommand
        Public Property RecordResumptionCommand As ICommand
        Public Property PrintLeaveCommand As ICommand
        Public Property PrintCommencementCommand As ICommand
        Public Property RefreshCommand As ICommand

        ' === Events ===
        Public Event RequestSnackbar As Action(Of String)
        Public Event RequestClearDropdown As Action
        Public Event RequestExpandSidePanel As Action

        Public Sub New()
            Leaves = New ObservableCollection(Of EmployeeLeave)()
            EmployeesList = New ObservableCollection(Of Employee)()
            FilteredEmployees = New ObservableCollection(Of Employee)()
            LeaveTypesList = New ObservableCollection(Of LeaveType)()

            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            NewLeaveCommand = New RelayCommand(AddressOf ExecuteNewLeave)
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

        Public Shadows Sub LoadPermissions(formName As String)
            MyBase.LoadPermissions(formName)
            NotifyStateChanged()
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

                If LeaveTypesList.Any() AndAlso NewLeave IsNot Nothing Then
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
                .LeaveID = 0,
                .StartDate = DateTime.Today.AddDays(1),
                .EndDate = DateTime.Today.AddDays(7),
                .ExpectedReturnDate = DateTime.Today.AddDays(8),
                .DaysCount = 7,
                .Status = "Approved",
                .Reason = String.Empty
            }
            If LeaveTypesList IsNot Nothing AndAlso LeaveTypesList.Any() Then
                NewLeave.LeaveTypeID = LeaveTypesList.First().LeaveTypeID
            End If
        End Sub

        Public Sub ExecuteNewLeave(parameter As Object)
            _selectedLeave = Nothing
            OnPropertyChanged(NameOf(SelectedLeave))

            IsEditMode = False
            ResetNewLeave()

            _selectedEmployeeForLeave = Nothing
            OnPropertyChanged(NameOf(SelectedEmployeeForLeave))
            FilterEmployees(String.Empty)

            AccruedDays = 0
            UsedDays = 0
            RemainingBalance = 0

            ResumptionActualDate = DateTime.Today
            ResumptionNotes = String.Empty
            DelayDaysCount = 0

            NotifyStateChanged()
            RaiseEvent RequestClearDropdown()
            RaiseEvent RequestExpandSidePanel()
            RaiseEvent RequestSnackbar("📄 تم تفريغ الحقول لإضافة سجل جديد")
        End Sub

        Private Sub LoadSelectedLeaveDetails(leave As EmployeeLeave)
            If leave Is Nothing Then Return

            IsEditMode = True

            ' 1. Synchronize Employee in Dropdown
            FilterEmployees(String.Empty)
            Dim emp = EmployeesList.FirstOrDefault(Function(e) e.EmployeeID = leave.EmployeeID)
            If emp Is Nothing AndAlso leave.EmployeeID > 0 Then
                emp = _hrService.GetEmployeeById(leave.EmployeeID)
                If emp IsNot Nothing Then
                    EmployeesList.Add(emp)
                    FilteredEmployees.Add(emp)
                End If
            End If
            SelectedEmployeeForLeave = emp

            ' 2. Populate Leave Form Data for Editing
            NewLeave = New EmployeeLeave With {
                .LeaveID = leave.LeaveID,
                .EmployeeID = leave.EmployeeID,
                .EmployeeCode = leave.EmployeeCode,
                .EmployeeName = leave.EmployeeName,
                .Department = leave.Department,
                .LeaveTypeID = leave.LeaveTypeID,
                .LeaveTypeName = leave.LeaveTypeName,
                .StartDate = leave.StartDate,
                .EndDate = leave.EndDate,
                .DaysCount = leave.DaysCount,
                .Reason = leave.Reason,
                .Status = leave.Status,
                .ExpectedReturnDate = leave.ExpectedReturnDate,
                .ActualReturnDate = leave.ActualReturnDate,
                .ResumptionDate = leave.ResumptionDate,
                .DelayDays = leave.DelayDays,
                .ResumptionNotes = leave.ResumptionNotes,
                .ApprovedBy = leave.ApprovedBy,
                .CreatedAt = leave.CreatedAt
            }

            ' 3. Populate Resumption Data
            ResumptionActualDate = If(leave.ActualReturnDate.HasValue, leave.ActualReturnDate.Value, If(leave.ResumptionDate.HasValue, leave.ResumptionDate.Value, DateTime.Today))
            ResumptionNotes = If(leave.ResumptionNotes, String.Empty)
            CalculateResumptionDelay()

            ' 4. Load Balance
            LoadLeaveBalance(leave.EmployeeID)

            ' 5. Notify UI & Expand side panel if collapsed
            NotifyStateChanged()
            RaiseEvent RequestExpandSidePanel()
        End Sub

        Private Sub SaveLeave(parameter As Object)
            If NewLeave Is Nothing OrElse NewLeave.EmployeeID <= 0 Then
                MessageBox.Show("يرجى اختيار الموظف أولاً", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If NewLeave.EndDate < NewLeave.StartDate Then
                MessageBox.Show("تاريخ انتهاء الإجازة يجب أن يكون بعد تاريخ البدء", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Dim isUpdate = (NewLeave.LeaveID > 0)
            If isUpdate AndAlso Not CanEdit Then
                MessageBox.Show("ليس لديك صلاحية لتعديل سجلات الإجازات", "صلاحيات غير كافية", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If
            If Not isUpdate AndAlso Not CanAdd Then
                MessageBox.Show("ليس لديك صلاحية لإضافة إجازات جديدة", "صلاحيات غير كافية", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            NewLeave.DaysCount = Math.Max(1, CInt((NewLeave.EndDate - NewLeave.StartDate).TotalDays) + 1)
            NewLeave.ExpectedReturnDate = NewLeave.EndDate.AddDays(1)
            NewLeave.ApprovedBy = If(Session.CurrentUser?.Username, "Admin")

            Try
                Dim savedId = _hrService.SaveLeave(NewLeave)
                NewLeave.LeaveID = savedId

                If isUpdate Then
                    RaiseEvent RequestSnackbar("💾 تم تعديل وحفظ بيانات الإجازة بنجاح 👌")
                Else
                    RaiseEvent RequestSnackbar("🏖️ تم تسجيل واعتماد طلب الإجازة بنجاح 👌")
                End If

                LoadLeaves()
                LoadLeaveBalance(NewLeave.EmployeeID)

                If isUpdate Then
                    _selectedLeave = Leaves.FirstOrDefault(Function(l) l.LeaveID = savedId)
                    OnPropertyChanged(NameOf(SelectedLeave))
                    NotifyStateChanged()
                Else
                    ExecuteNewLeave(Nothing)
                End If
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

            If Not CanEdit Then
                MessageBox.Show("ليس لديك صلاحية لتسجيل أو تعديل مباشرة العمل", "صلاحيات غير كافية", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                _hrService.RecordResumption(SelectedLeave.LeaveID, ResumptionActualDate, ResumptionActualDate, ResumptionNotes)
                RaiseEvent RequestSnackbar("🏢 تم اعتماد مباشرة العمل وتحديث حالة الموظف بنجاح 👌")
                Dim curId = SelectedLeave.LeaveID
                LoadLeaves()
                SelectedLeave = Leaves.FirstOrDefault(Function(l) l.LeaveID = curId)
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

        Private Sub NotifyStateChanged()
            OnPropertyChanged(NameOf(IsEditMode))
            OnPropertyChanged(NameOf(FormTitle))
            OnPropertyChanged(NameOf(SaveButtonText))
            OnPropertyChanged(NameOf(SaveButtonBackground))
            OnPropertyChanged(NameOf(CanAdd))
            OnPropertyChanged(NameOf(CanEdit))
            OnPropertyChanged(NameOf(CanDelete))
            OnPropertyChanged(NameOf(CanPrint))
            OnPropertyChanged(NameOf(CanSaveLeave))
            OnPropertyChanged(NameOf(CanRecordResumption))
            CommandManager.InvalidateRequerySuggested()
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
