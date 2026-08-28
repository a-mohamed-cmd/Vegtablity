Imports System
Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Linq
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HRPayrollViewModel
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

        ' === Month & Year Generator Selection ===
        Private _selectedMonth As Integer = DateTime.Today.Month
        Public Property SelectedMonth As Integer
            Get
                Return _selectedMonth
            End Get
            Set(value As Integer)
                SetProperty(_selectedMonth, value)
            End Set
        End Property

        Private _selectedYear As Integer = DateTime.Today.Year
        Public Property SelectedYear As Integer
            Get
                Return _selectedYear
            End Get
            Set(value As Integer)
                SetProperty(_selectedYear, value)
            End Set
        End Property

        Public Property MonthsList As ObservableCollection(Of Integer)
        Public Property YearsList As ObservableCollection(Of Integer)

        ' === Collections & Models ===
        Public Property Batches As ObservableCollection(Of PayrollBatch)

        Private _selectedBatch As PayrollBatch
        Public Property SelectedBatch As PayrollBatch
            Get
                Return _selectedBatch
            End Get
            Set(value As PayrollBatch)
                If SetProperty(_selectedBatch, value) Then
                    If value IsNot Nothing Then
                        LoadBatchDetails(value.BatchID)
                    End If
                    NotifyBatchStatusChanged()
                End If
            End Set
        End Property

        Public Property PayrollDetailsList As ObservableCollection(Of PayrollDetail)

        ' === Batch Approval State Properties ===
        Public ReadOnly Property IsBatchApproved As Boolean
            Get
                Return SelectedBatch IsNot Nothing AndAlso SelectedBatch.IsApproved
            End Get
        End Property

        Public ReadOnly Property IsBatchEditable As Boolean
            Get
                Return SelectedBatch IsNot Nothing AndAlso SelectedBatch.IsEditable
            End Get
        End Property

        Public ReadOnly Property ApproveButtonText As String
            Get
                If IsBatchApproved Then
                    Return "إلغاء الاعتماد"
                Else
                    Return "اعتماد"
                End If
            End Get
        End Property

        Public ReadOnly Property ApproveButtonBackground As String
            Get
                If IsBatchApproved Then
                    Return "#E11D48" ' Bold Red for Unapprove
                Else
                    Return "#10B981" ' Emerald Green for Approve
                End If
            End Get
        End Property

        ' === Events & Commands ===
        Public Event RequestSnackbar As Action(Of String)

        Public Property NextPageCommand As ICommand
        Public Property PreviousPageCommand As ICommand
        Public Property GenerateBatchCommand As ICommand
        Public Property SaveDetailCommand As ICommand
        Public Property ApproveBatchCommand As ICommand
        Public Property PrintPayslipCommand As ICommand
        Public Property PrintFullBatchCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Sub New()
            Batches = New ObservableCollection(Of PayrollBatch)()
            PayrollDetailsList = New ObservableCollection(Of PayrollDetail)()

            MonthsList = New ObservableCollection(Of Integer) From {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
            YearsList = New ObservableCollection(Of Integer) From {DateTime.Today.Year - 1, DateTime.Today.Year, DateTime.Today.Year + 1}

            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            GenerateBatchCommand = New RelayCommand(AddressOf GenerateBatch)
            SaveDetailCommand = New RelayCommand(AddressOf SaveDetail)
            ApproveBatchCommand = New RelayCommand(AddressOf ApproveBatch)
            PrintPayslipCommand = New RelayCommand(AddressOf PrintPayslip)
            PrintFullBatchCommand = New RelayCommand(AddressOf PrintFullBatch)
            RefreshCommand = New RelayCommand(Sub() LoadBatches())

            LoadPermissions("HRPayroll")
            LoadBatches()
        End Sub

        Private Sub LoadBatches()
            Try
                Dim res = _hrService.GetPayrollBatchesPaged(CurrentPage, PageSize)
                Batches.Clear()
                For Each b In res.Data
                    Batches.Add(b)
                Next
                TotalRecords = res.TotalCount
                NotifyPaginationChanged()

                If Batches.Any() AndAlso SelectedBatch Is Nothing Then
                    SelectedBatch = Batches.First()
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب مسيرات الرواتب: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub LoadBatchDetails(batchID As Integer)
            Try
                Dim batch = _hrService.GetPayrollBatchDetails(batchID)
                If batch IsNot Nothing Then
                    PayrollDetailsList.Clear()
                    For Each d In batch.Details
                        AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                        PayrollDetailsList.Add(d)
                    Next
                    If SelectedBatch IsNot Nothing Then
                        SelectedBatch.Details = PayrollDetailsList
                        SelectedBatch.RecalculateTotals()
                    End If
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب تفاصيل المسير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If SelectedBatch IsNot Nothing Then
                SelectedBatch.RecalculateTotals()
            End If
        End Sub

        Private Sub GenerateBatch(parameter As Object)
            Try
                Dim user = If(Session.CurrentUser?.Username, "Admin")
                Dim batchID = _hrService.GeneratePayrollBatch(SelectedMonth, SelectedYear, user)
                LoadBatches()
                SelectedBatch = Batches.FirstOrDefault(Function(b) b.BatchID = batchID)
                RaiseEvent RequestSnackbar($"⚡ تم توليد واحتساب مسير رواتب شهر {SelectedMonth:D2} / {SelectedYear} بنجاح!")
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء توليد المسير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Public Sub SaveDetail(parameter As Object)
            If IsBatchApproved Then
                RaiseEvent RequestSnackbar("⚠️ مسير الرواتب معتمد ومقفل. يرجى إلغاء الاعتماد أولاً لإجراء أي تعديل.")
                Return
            End If

            Dim d = TryCast(parameter, PayrollDetail)
            If d Is Nothing Then Return
            Try
                d.Recalculate()
                _hrService.SavePayrollDetail(d)
                If SelectedBatch IsNot Nothing Then
                    SelectedBatch.RecalculateTotals()
                End If
                RaiseEvent RequestSnackbar($"💾 تم حفظ تعديلات راتب ({d.EmployeeName}) والصافي: {d.NetSalary:N3} 👌")
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ التعديل: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ApproveBatch(parameter As Object)
            If SelectedBatch Is Nothing Then
                RaiseEvent RequestSnackbar("⚠️ يرجى اختيار مسير أولاً")
                Return
            End If

            If SelectedBatch.IsApproved Then
                ' Re-open / Unapprove batch
                If MessageBox.Show($"هل أنت متأكد من إلغاء اعتماد مسير رواتب شهر {SelectedBatch.Month:D2} / {SelectedBatch.Year} وفتحه للتعديل مجدداً؟", "تأكيد إلغاء الاعتماد", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                    Try
                        _hrService.UnapprovePayrollBatch(SelectedBatch.BatchID)
                        SelectedBatch.Status = "Draft"
                        SelectedBatch.ApprovedBy = Nothing
                        SelectedBatch.ApprovedAt = Nothing
                        NotifyBatchStatusChanged()
                        RaiseEvent RequestSnackbar("🔓 تم إلغاء اعتماد مسير الرواتب وفتحه للتعديل بنجاح!")
                    Catch ex As Exception
                        MessageBox.Show("خطأ أثناء إلغاء اعتماد المسير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                    End Try
                End If
            Else
                ' Final approve batch
                If MessageBox.Show($"هل أنت متأكد من اعتماد مسير رواتب شهر {SelectedBatch.Month:D2} / {SelectedBatch.Year} نهائياً وترحيل القيد المحاسبي؟", "تأكيد الاعتماد النهائي", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                    Try
                        Dim user = If(Session.CurrentUser?.Username, "Admin")
                        _hrService.ApprovePayrollBatch(SelectedBatch.BatchID, user)
                        SelectedBatch.Status = "Approved"
                        SelectedBatch.ApprovedBy = user
                        SelectedBatch.ApprovedAt = DateTime.Now
                        NotifyBatchStatusChanged()
                        RaiseEvent RequestSnackbar("✔ تم اعتماد مسير الرواتب وترحيل القيد المحاسبي بنجاح!")
                    Catch ex As Exception
                        MessageBox.Show("خطأ أثناء اعتماد المسير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                    End Try
                End If
            End If
        End Sub

        Public Sub NotifyBatchStatusChanged()
            OnPropertyChanged(NameOf(IsBatchApproved))
            OnPropertyChanged(NameOf(IsBatchEditable))
            OnPropertyChanged(NameOf(ApproveButtonText))
            OnPropertyChanged(NameOf(ApproveButtonBackground))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub PrintPayslip(parameter As Object)
            Dim detail = TryCast(parameter, PayrollDetail)
            If detail Is Nothing Then
                RaiseEvent RequestSnackbar("⚠️ يرجى اختيار موظف لطباعة قسيمة راتبه")
                Return
            End If

            Dim emp = _hrService.GetEmployeeById(detail.EmployeeID)
            _printer.PrintSalaryPayslip(emp, detail, SelectedBatch)
        End Sub

        Private Sub PrintFullBatch(parameter As Object)
            If SelectedBatch Is Nothing OrElse Not PayrollDetailsList.Any() Then
                RaiseEvent RequestSnackbar("⚠️ لا يوجد بيانات مسير حالية للطباعة")
                Return
            End If

            _printer.PrintPayrollBatchReport(SelectedBatch, PayrollDetailsList)
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
                LoadBatches()
            End If
        End Sub

        Public Sub GoToPreviousPage()
            If HasPreviousPage Then
                CurrentPage -= 1
                LoadBatches()
            End If
        End Sub
    End Class
End Namespace
