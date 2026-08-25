Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class JournalEntryViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New AccountingService()
        
        ' === Properties ===

        Private _journalList As ObservableCollection(Of JournalHeader)
        Public Property JournalList As ObservableCollection(Of JournalHeader)
            Get
                Return _journalList
            End Get
            Set(value As ObservableCollection(Of JournalHeader))
                _journalList = value
                OnPropertyChanged()
            End Set
        End Property

        Private _currentJournal As JournalHeader
        Public Property CurrentJournal As JournalHeader
            Get
                Return _currentJournal
            End Get
            Set(value As JournalHeader)
                _currentJournal = value
                OnPropertyChanged()
                UpdateTotals()
                ' مزامنة نص التاريخ
                If value IsNot Nothing Then
                    _jDateText = value.JDate.ToString("dd/MM/yyyy")
                    OnPropertyChanged(NameOf(JDateText))
                End If
                NotifyButtonStates()
            End Set
        End Property

        ' === Smart Button Visibility Properties ===
        Public ReadOnly Property IsJournalPosted As Boolean
            Get
                Return CurrentJournal IsNot Nothing AndAlso CurrentJournal.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsEditAllowed As Boolean
            Get
                Return CurrentJournal IsNot Nothing AndAlso Not CurrentJournal.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsSaveVisible As Boolean
            Get
                Return CurrentJournal IsNot Nothing AndAlso Not CurrentJournal.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsPostVisible As Boolean
            Get
                Return CurrentJournal IsNot Nothing AndAlso CurrentJournal.JID > 0 AndAlso Not CurrentJournal.IsPosted
            End Get
        End Property

        Public ReadOnly Property IsUnpostVisible As Boolean
            Get
                Return CurrentJournal IsNot Nothing AndAlso CurrentJournal.JID > 0 AndAlso CurrentJournal.IsPosted
            End Get
        End Property

        Public Sub NotifyButtonStates()
            OnPropertyChanged(NameOf(IsJournalPosted))
            OnPropertyChanged(NameOf(IsEditAllowed))
            OnPropertyChanged(NameOf(IsSaveVisible))
            OnPropertyChanged(NameOf(IsPostVisible))
            OnPropertyChanged(NameOf(IsUnpostVisible))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        ''' <summary>نص تاريخ القيد للإدخال اليدوي — يُزامن مع CurrentJournal.JDate</summary>
        Private _jDateText As String = DateTime.Now.ToString("dd/MM/yyyy")
        Public Property JDateText As String
            Get
                Return _jDateText
            End Get
            Set(value As String)
                _jDateText = If(value, "")
                OnPropertyChanged(NameOf(JDateText))
            End Set
        End Property

        Private _selectedJournal As JournalHeader
        Public Property SelectedJournal As JournalHeader
            Get
                Return _selectedJournal
            End Get
            Set(value As JournalHeader)
                _selectedJournal = value
                OnPropertyChanged()
                If value IsNot Nothing Then
                    LoadJournal(value.JID)
                End If
            End Set
        End Property

        Private _accounts As ObservableCollection(Of Account)
        
        Private _filteredAccounts As ObservableCollection(Of Account)
        Public Property FilteredAccounts As ObservableCollection(Of Account)
            Get
                Return _filteredAccounts
            End Get
            Set(value As ObservableCollection(Of Account))
                _filteredAccounts = value
                OnPropertyChanged()
            End Set
        End Property

        Public Sub FilterAccounts(searchText As String)
            If String.IsNullOrWhiteSpace(searchText) Then
                FilteredAccounts = Accounts
            Else
                Dim lower = searchText.ToLower()
                FilteredAccounts = New ObservableCollection(Of Account)(
                    System.Linq.Enumerable.Where(Accounts, Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower().Contains(lower)) OrElse 
                                               (a.AccountCode IsNot Nothing AndAlso a.AccountCode.Contains(searchText)))
                )
            End If
        End Sub

        Public Property Accounts As ObservableCollection(Of Account)
            Get
                Return _accounts
            End Get
            Set(value As ObservableCollection(Of Account))
                _accounts = value
                OnPropertyChanged()
            End Set
        End Property

        ' === Pagination Properties ===
        Private _currentPageIndex As Integer = 1
        Public Property CurrentPageIndex As Integer
            Get
                Return _currentPageIndex
            End Get
            Set(value As Integer)
                _currentPageIndex = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(HasPreviousPage))
                OnPropertyChanged(NameOf(HasNextPage))
                OnPropertyChanged(NameOf(PageInfoText))
            End Set
        End Property

        Private _pageSize As Integer = 20
        Public Property PageSize As Integer
            Get
                Return _pageSize
            End Get
            Set(value As Integer)
                _pageSize = Math.Max(1, value)
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(HasPreviousPage))
                OnPropertyChanged(NameOf(HasNextPage))
                OnPropertyChanged(NameOf(PageInfoText))
            End Set
        End Property

        Private _totalCount As Integer = 0
        Public Property TotalCount As Integer
            Get
                Return _totalCount
            End Get
            Set(value As Integer)
                _totalCount = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(TotalPages))
                OnPropertyChanged(NameOf(HasPreviousPage))
                OnPropertyChanged(NameOf(HasNextPage))
                OnPropertyChanged(NameOf(PageInfoText))
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                If PageSize <= 0 Then Return 1
                Return Math.Max(1, CInt(Math.Ceiling(TotalCount / CDbl(PageSize))))
            End Get
        End Property

        Public ReadOnly Property HasPreviousPage As Boolean
            Get
                Return CurrentPageIndex > 1
            End Get
        End Property

        Public ReadOnly Property HasNextPage As Boolean
            Get
                Return CurrentPageIndex < TotalPages
            End Get
        End Property

        Public ReadOnly Property PageInfoText As String
            Get
                Return "صفحة " & CurrentPageIndex & " من " & TotalPages & " (" & TotalCount & " قيد)"
            End Get
        End Property

        ' === Sidebar Collapse Property ===
        Private _isJournalListCollapsed As Boolean = False
        Public Property IsJournalListCollapsed As Boolean
            Get
                Return _isJournalListCollapsed
            End Get
            Set(value As Boolean)
                _isJournalListCollapsed = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(ToggleIconText))
            End Set
        End Property

        Public ReadOnly Property ToggleIconText As String
            Get
                Return If(IsJournalListCollapsed, "▶", "◀")
            End Get
        End Property

        ' --- Calculations ---
        Private _totalDebit As Decimal
        Public Property TotalDebit As Decimal
            Get
                Return _totalDebit
            End Get
            Set(value As Decimal)
                _totalDebit = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(Difference))
                OnPropertyChanged(NameOf(DifferenceFormatted))
                OnPropertyChanged(NameOf(DifferenceColor))
                OnPropertyChanged(NameOf(IsBalanced))
            End Set
        End Property

        Private _totalCredit As Decimal
        Public Property TotalCredit As Decimal
            Get
                Return _totalCredit
            End Get
            Set(value As Decimal)
                _totalCredit = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(Difference))
                OnPropertyChanged(NameOf(DifferenceFormatted))
                OnPropertyChanged(NameOf(DifferenceColor))
                OnPropertyChanged(NameOf(IsBalanced))
            End Set
        End Property

        Public ReadOnly Property Difference As Decimal
            Get
                Return TotalDebit - TotalCredit
            End Get
        End Property

        Public ReadOnly Property DifferenceFormatted As String
            Get
                Dim diff = Difference
                If diff = 0 Then
                    Return "متزن (0.000)"
                ElseIf diff < 0 Then
                    Return "الفرق: (" & Math.Abs(diff).ToString("N3") & ")"
                Else
                    Return "الفرق: " & diff.ToString("N3")
                End If
            End Get
        End Property

        Public ReadOnly Property DifferenceColor As String
            Get
                Return If(Difference = 0, "#27ae60", "#e74c3c")
            End Get
        End Property

        Public ReadOnly Property IsBalanced As Boolean
            Get
                Return TotalDebit = TotalCredit AndAlso TotalDebit > 0
            End Get
        End Property

        ' === Search & Filter Properties ===
        Private _searchJournalNo As String = ""
        Public Property SearchJournalNo As String
            Get
                Return _searchJournalNo
            End Get
            Set(value As String)
                _searchJournalNo = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchDescription As String = ""
        Public Property SearchDescription As String
            Get
                Return _searchDescription
            End Get
            Set(value As String)
                _searchDescription = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchStatusIndex As Integer = 0 ' 0: الكل, 1: مرحل, 2: غير مرحل
        Public Property SearchStatusIndex As Integer
            Get
                Return _searchStatusIndex
            End Get
            Set(value As Integer)
                _searchStatusIndex = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _isDateFilterEnabled As Boolean = False
        Public Property IsDateFilterEnabled As Boolean
            Get
                Return _isDateFilterEnabled
            End Get
            Set(value As Boolean)
                _isDateFilterEnabled = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchDateFrom As DateTime? = Nothing
        Public Property SearchDateFrom As DateTime?
            Get
                Return _searchDateFrom
            End Get
            Set(value As DateTime?)
                _searchDateFrom = value
                OnPropertyChanged()
                If value.HasValue Then
                    _searchDateFromText = value.Value.ToString("dd/MM/yyyy")
                    OnPropertyChanged(NameOf(SearchDateFromText))
                End If
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchDateFromText As String = ""
        Public Property SearchDateFromText As String
            Get
                Return _searchDateFromText
            End Get
            Set(value As String)
                _searchDateFromText = If(value, "")
                OnPropertyChanged()
                
                Dim raw = _searchDateFromText.Trim().Replace("-", "/").Replace(".", "/")
                If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                    raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
                End If
                Dim parsed As DateTime
                If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                          System.Globalization.CultureInfo.InvariantCulture,
                                          System.Globalization.DateTimeStyles.None, parsed) Then
                    _searchDateFrom = parsed
                ElseIf String.IsNullOrWhiteSpace(raw) Then
                    _searchDateFrom = Nothing
                End If
                OnPropertyChanged(NameOf(SearchDateFrom))
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchDateTo As DateTime? = Nothing
        Public Property SearchDateTo As DateTime?
            Get
                Return _searchDateTo
            End Get
            Set(value As DateTime?)
                _searchDateTo = value
                OnPropertyChanged()
                If value.HasValue Then
                    _searchDateToText = value.Value.ToString("dd/MM/yyyy")
                    OnPropertyChanged(NameOf(SearchDateToText))
                End If
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _searchDateToText As String = ""
        Public Property SearchDateToText As String
            Get
                Return _searchDateToText
            End Get
            Set(value As String)
                _searchDateToText = If(value, "")
                OnPropertyChanged()
                
                Dim raw = _searchDateToText.Trim().Replace("-", "/").Replace(".", "/")
                If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                    raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
                End If
                Dim parsed As DateTime
                If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                          System.Globalization.CultureInfo.InvariantCulture,
                                          System.Globalization.DateTimeStyles.None, parsed) Then
                    _searchDateTo = parsed
                ElseIf String.IsNullOrWhiteSpace(raw) Then
                    _searchDateTo = Nothing
                End If
                OnPropertyChanged(NameOf(SearchDateTo))
                OnPropertyChanged(NameOf(IsFilterActive))
            End Set
        End Property

        Private _isFilterCardExpanded As Boolean = False
        Public Property IsFilterCardExpanded As Boolean
            Get
                Return _isFilterCardExpanded
            End Get
            Set(value As Boolean)
                _isFilterCardExpanded = value
                OnPropertyChanged()
            End Set
        End Property

        Public ReadOnly Property IsFilterActive As Boolean
            Get
                Return (Not String.IsNullOrWhiteSpace(SearchJournalNo)) OrElse
                       (Not String.IsNullOrWhiteSpace(SearchDescription)) OrElse
                       (SearchStatusIndex <> 0) OrElse
                       (IsDateFilterEnabled AndAlso (SearchDateFrom.HasValue OrElse SearchDateTo.HasValue))
            End Get
        End Property

        Public ReadOnly Property ActiveFilterSummaryText As String
            Get
                If Not IsFilterActive Then Return ""
                Return $"نتائج التصفية: {TotalCount} قيد"
            End Get
        End Property

        ' === Commands ===
        Public Property NewCommand As RelayCommand
        Public Property SaveCommand As RelayCommand
        Public Property PostCommand As RelayCommand
        Public Property UnpostCommand As RelayCommand
        Public Property AddLineCommand As RelayCommand
        Public Property DeleteLineCommand As RelayCommand
        Public Property PrintCommand As RelayCommand
        Public Property ExportPdfCommand As RelayCommand
        Public Property NextPageCommand As RelayCommand
        Public Property PreviousPageCommand As RelayCommand
        Public Property ToggleListCommand As RelayCommand
        Public Property AutoBalanceCommand As RelayCommand
        Public Property RefreshCommand As RelayCommand
        Public Property ApplyFilterCommand As RelayCommand
        Public Property ClearFilterCommand As RelayCommand
        Public Property ToggleFilterCardCommand As RelayCommand

        Public Sub New()
            LoadPermissions("JournalEntries")
            LoadAccounts()
            LoadList()
            NewJournal()

            NewCommand = New RelayCommand(AddressOf NewJournal)
            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanSave)
            PostCommand = New RelayCommand(AddressOf ExecutePost, AddressOf CanPost)
            UnpostCommand = New RelayCommand(AddressOf ExecuteUnpost, AddressOf CanUnpost)
            AddLineCommand = New RelayCommand(AddressOf AddLine)
            DeleteLineCommand = New RelayCommand(AddressOf DeleteLine)
            PrintCommand = New RelayCommand(AddressOf ExecutePrint, AddressOf CanPrint)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, AddressOf CanPrint)
            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function(o) HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function(o) HasPreviousPage)
            ToggleListCommand = New RelayCommand(AddressOf ToggleList)
            AutoBalanceCommand = New RelayCommand(AddressOf ExecuteAutoBalance)
            RefreshCommand = New RelayCommand(AddressOf ExecuteRefresh)
            ApplyFilterCommand = New RelayCommand(AddressOf ExecuteApplyFilter)
            ClearFilterCommand = New RelayCommand(AddressOf ExecuteClearFilter)
            ToggleFilterCardCommand = New RelayCommand(AddressOf ToggleFilterCard)
        End Sub

        Public Sub ToggleFilterCard(Optional obj As Object = Nothing)
            IsFilterCardExpanded = Not IsFilterCardExpanded
        End Sub

        Public Sub ExecuteApplyFilter(Optional obj As Object = Nothing)
            ParseDateText(SearchDateFromText, _searchDateFrom)
            ParseDateText(SearchDateToText, _searchDateTo)
            OnPropertyChanged(NameOf(SearchDateFrom))
            OnPropertyChanged(NameOf(SearchDateTo))
            CurrentPageIndex = 1
            LoadList()
            OnPropertyChanged(NameOf(IsFilterActive))
            OnPropertyChanged(NameOf(ActiveFilterSummaryText))
        End Sub

        Private Sub ParseDateText(text As String, ByRef target As DateTime?)
            If String.IsNullOrWhiteSpace(text) Then
                target = Nothing
                Return
            End If
            Dim raw = text.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                target = parsed
            Else
                target = Nothing
            End If
        End Sub

        Public Sub ExecuteClearFilter(Optional obj As Object = Nothing)
            _searchJournalNo = ""
            _searchDescription = ""
            _searchStatusIndex = 0
            _isDateFilterEnabled = False
            _searchDateFrom = Nothing
            _searchDateTo = Nothing
            _searchDateFromText = ""
            _searchDateToText = ""
            OnPropertyChanged(NameOf(SearchJournalNo))
            OnPropertyChanged(NameOf(SearchDescription))
            OnPropertyChanged(NameOf(SearchStatusIndex))
            OnPropertyChanged(NameOf(IsDateFilterEnabled))
            OnPropertyChanged(NameOf(SearchDateFrom))
            OnPropertyChanged(NameOf(SearchDateTo))
            OnPropertyChanged(NameOf(SearchDateFromText))
            OnPropertyChanged(NameOf(SearchDateToText))
            OnPropertyChanged(NameOf(IsFilterActive))
            OnPropertyChanged(NameOf(ActiveFilterSummaryText))
            CurrentPageIndex = 1
            LoadList()
        End Sub

        ' === Methods ===

        Public Sub ExecuteRefresh(Optional obj As Object = Nothing)
            LoadAccounts()
            LoadList()
            NewJournal()
        End Sub

        Private Sub LoadAccounts()
            Dim accs = _accountingService.GetAllAccounts().Where(Function(a) a.IsTransactional).ToList()
            Accounts = New ObservableCollection(Of Account)(accs)
            FilteredAccounts = Accounts
        End Sub

        Public Sub LoadList()
            Dim isPosted As Boolean? = Nothing
            If SearchStatusIndex = 1 Then
                isPosted = True
            ElseIf SearchStatusIndex = 2 Then
                isPosted = False
            End If

            Dim startDate As DateTime? = SearchDateFrom
            Dim endDate As DateTime? = SearchDateTo

            Try
                Dim count As Integer = 0
                Dim headers = _accountingService.GetPagedJournalHeaders(
                    CurrentPageIndex,
                    PageSize,
                    count,
                    SearchJournalNo,
                    SearchDescription,
                    isPosted,
                    startDate,
                    endDate
                )
                TotalCount = count
                JournalList = New ObservableCollection(Of JournalHeader)(headers)
            Catch ex As Exception
                ' Fallback with full in-memory filtering if GetPaged SP fails or lacks new parameters
                Dim all = _accountingService.GetAllJournalHeaders().AsEnumerable()

                If Not String.IsNullOrWhiteSpace(SearchJournalNo) Then
                    all = all.Where(Function(j) j.JournalNo.ToString().Contains(SearchJournalNo.Trim()))
                End If
                If Not String.IsNullOrWhiteSpace(SearchDescription) Then
                    all = all.Where(Function(j) j.Description IsNot Nothing AndAlso j.Description.IndexOf(SearchDescription.Trim(), StringComparison.OrdinalIgnoreCase) >= 0)
                End If
                If isPosted.HasValue Then
                    all = all.Where(Function(j) j.IsPosted = isPosted.Value)
                End If
                If startDate.HasValue Then
                    all = all.Where(Function(j) j.JDate.Date >= startDate.Value.Date)
                End If
                If endDate.HasValue Then
                    all = all.Where(Function(j) j.JDate.Date <= endDate.Value.Date)
                End If

                Dim filteredList = all.ToList()
                TotalCount = filteredList.Count
                Dim paged = filteredList.Skip((CurrentPageIndex - 1) * PageSize).Take(PageSize)
                JournalList = New ObservableCollection(Of JournalHeader)(paged)
            End Try
        End Sub

        Private Sub GoToNextPage(obj As Object)
            If HasNextPage Then
                CurrentPageIndex += 1
                LoadList()
            End If
        End Sub

        Private Sub GoToPreviousPage(obj As Object)
            If HasPreviousPage Then
                CurrentPageIndex -= 1
                LoadList()
            End If
        End Sub

        Private Sub ToggleList(obj As Object)
            IsJournalListCollapsed = Not IsJournalListCollapsed
        End Sub

        Private Sub LoadJournal(jid As Integer)
            ' Fetch details from DB directly to ensure header & details are complete
            Dim details = _accountingService.GetJournalDetails(jid)
            
            Dim header = JournalList.FirstOrDefault(Function(j) j.JID = jid)
            If header Is Nothing Then
                header = New JournalHeader() With {.JID = jid}
            End If

            header.Details = New ObservableCollection(Of JournalDetail)(details)
            
            ' Add listeners to existing rows
            For Each d In header.Details
                AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
            Next
            
            CurrentJournal = header
            UpdateTotals()
        End Sub

        Private Sub NewJournal()
            CurrentJournal = New JournalHeader() With {
                .JDate = DateTime.Now,
                .UserID = Session.CurrentUser?.UserID,
                .Details = New ObservableCollection(Of JournalDetail)()
            }
            ' Add one default line
            AddLine()
            UpdateTotals()
            NotifyButtonStates()
        End Sub

        Public Sub AddLine()
            Dim d As New JournalDetail()
            AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
            CurrentJournal.Details.Add(d)
            UpdateTotals()
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            Dim detail = TryCast(sender, JournalDetail)
            If detail Is Nothing Then Return

            If e.PropertyName = "Debit" OrElse e.PropertyName = "Credit" Then
                UpdateTotals()
            ElseIf e.PropertyName = "AccountID" Then
                ' Update name and code from the accounts list
                Dim account = Accounts.FirstOrDefault(Function(a) a.AccountID = detail.AccountID)
                If account IsNot Nothing Then
                    detail.AccountName = account.AccountName
                    detail.AccountCode = account.AccountCode
                End If
            End If
        End Sub

        Private Sub DeleteLine(obj As Object)
            Dim line = TryCast(obj, JournalDetail)
            If line IsNot Nothing Then
                RemoveHandler line.PropertyChanged, AddressOf OnDetailPropertyChanged
                CurrentJournal.Details.Remove(line)
                UpdateTotals()
            End If
        End Sub

        Public Sub UpdateTotals()
            If CurrentJournal IsNot Nothing AndAlso CurrentJournal.Details IsNot Nothing Then
                TotalDebit = CurrentJournal.Details.Sum(Function(d) d.Debit)
                TotalCredit = CurrentJournal.Details.Sum(Function(d) d.Credit)
                CurrentJournal.TotalAmount = TotalDebit
            End If
        End Sub

        ''' <summary>تنظيف وحذف أي صفوف فارغة بدون حساب وبمبالغ صفرية قبل الحفظ</summary>
        Public Sub CleanupEmptyLines()
            If CurrentJournal Is Nothing OrElse CurrentJournal.Details Is Nothing Then Return
            
            Dim toRemove = CurrentJournal.Details.Where(Function(d) d.AccountID <= 0 AndAlso d.Debit = 0 AndAlso d.Credit = 0 AndAlso String.IsNullOrWhiteSpace(d.Notes)).ToList()
            
            For Each line In toRemove
                RemoveHandler line.PropertyChanged, AddressOf OnDetailPropertyChanged
                CurrentJournal.Details.Remove(line)
            Next
            
            UpdateTotals()
        End Sub

        Private Sub ExecuteAutoBalance(obj As Object)
            If CurrentJournal Is Nothing OrElse CurrentJournal.Details Is Nothing OrElse CurrentJournal.Details.Count = 0 Then Return
            
            UpdateTotals()
            Dim diff = Difference
            If diff = 0 Then Return

            Dim targetRow = CurrentJournal.Details.LastOrDefault()
            If targetRow IsNot Nothing Then
                If diff > 0 Then
                    targetRow.Credit += diff
                Else
                    targetRow.Debit += Math.Abs(diff)
                End If
                UpdateTotals()
            End If
        End Sub

        Private Function CanSave(obj As Object) As Boolean
            If CurrentPermissions Is Nothing Then Return False
            If CurrentJournal Is Nothing OrElse CurrentJournal.IsPosted Then Return False
            
            If CurrentJournal.JID = 0 AndAlso Not CurrentPermissions.CanAdd Then Return False
            If CurrentJournal.JID > 0 AndAlso Not CurrentPermissions.CanEdit Then Return False

            Return True
        End Function

        Private Sub ExecuteSave(obj As Object)
            ' 0. تنظيف وحذف الصفوف الفارغة قبل الحفظ أو التعديل
            CleanupEmptyLines()

            ' 1. التحقق من اتزان القيد
            If TotalDebit <> TotalCredit Then
                MessageBox.Show("القيد غير متزن! يجب أن يتساوى إجمالي المدين مع إجمالي الدائن." & vbCrLf & DifferenceFormatted,
                                "خطأ في الاتزان", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' 2. التحقق من وجود مبالغ
            If TotalDebit = 0 Then
                MessageBox.Show("لا يمكن حفظ قيد بقيمة صفر.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' 3. التحقق من اختيار الحسابات لكافة الأسطر المتبقية
            If CurrentJournal.Details.Any(Function(d) d.AccountID = 0) Then
                MessageBox.Show("يجب اختيار حساب لجميع الأسطر الموجودة في القيد.", "بيانات ناقصة", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' 4. التحقق من وجود سطرين على الأقل
            If CurrentJournal.Details.Count < 2 Then
                MessageBox.Show("يجب أن يحتوي القيد على سطرين على الأقل (مدين ودائن).", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                Dim jid = _accountingService.SaveJournalEntry(CurrentJournal)
                CurrentJournal.JID = jid
                CurrentJournal.IsPosted = False
                NotifyButtonStates()
                LoadList()
                ' Find and select the saved one
                SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = jid)
                NotifyButtonStates()
                MessageBox.Show("تم حفظ القيد بنجاح", "حفظ", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanPost(obj As Object) As Boolean
            If CurrentPermissions Is Nothing OrElse Not CurrentPermissions.CanEdit Then Return False
            
            Return CurrentJournal IsNot Nothing AndAlso
                   CurrentJournal.JID > 0 AndAlso
                   Not CurrentJournal.IsPosted
        End Function

        Private Sub ExecutePost(obj As Object)
            Try
                If MessageBox.Show("هل أنت متأكد من ترحيل القيد؟ لا يمكن التعديل بعد الترحيل", "تأكيد", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                    _accountingService.PostJournalEntry(CurrentJournal.JID)
                    CurrentJournal.IsPosted = True
                    NotifyButtonStates()
                    LoadList()
                    SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = CurrentJournal.JID)
                    NotifyButtonStates()
                    MessageBox.Show("تم ترحيل القيد بنجاح", "ترحيل", MessageBoxButton.OK, MessageBoxImage.Information)
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الترحيل: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanUnpost(obj As Object) As Boolean
            If CurrentPermissions Is Nothing OrElse Not CurrentPermissions.CanDelete Then Return False
            
            Return CurrentJournal IsNot Nothing AndAlso
                   CurrentJournal.JID > 0 AndAlso
                   CurrentJournal.IsPosted
        End Function

        Private Sub ExecuteUnpost(obj As Object)
            Try
                If MessageBox.Show("هل أنت متأكد من إلغاء ترحيل هذا القيد؟ سيتم حذف القيود المرتبطة من الدفتر العام وإرجاع القيد كغير مرحّل.", "تأكيد إلغاء الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                    _accountingService.UnpostJournalEntry(CurrentJournal.JID)
                    CurrentJournal.IsPosted = False
                    NotifyButtonStates()
                    LoadList()
                    SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = CurrentJournal.JID)
                    NotifyButtonStates()
                    MessageBox.Show("تم إلغاء ترحيل القيد وحذف مفرداته من الدفتر العام بنجاح", "إلغاء الترحيل", MessageBoxButton.OK, MessageBoxImage.Information)
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء إلغاء الترحيل: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanPrint(obj As Object) As Boolean
            Return CurrentJournal IsNot Nothing AndAlso CurrentJournal.JID > 0
        End Function

        Private Sub ExecutePrint(obj As Object)
            Try
                If CurrentJournal Is Nothing OrElse CurrentJournal.Details Is Nothing OrElse CurrentJournal.Details.Count = 0 Then
                    MessageBox.Show("لا توجد بيانات للطباعة.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If

                Dim printer As New Helpers.JournalPrinter()
                printer.PrintJournal(CurrentJournal)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الطباعة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteExportPdf(obj As Object)
            Try
                If CurrentJournal Is Nothing OrElse CurrentJournal.Details Is Nothing OrElse CurrentJournal.Details.Count = 0 Then
                    MessageBox.Show("لا توجد بيانات لتصديرها.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If

                ReportExporter.ExportJournalToPdf(CurrentJournal)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير PDF: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

    End Class
End Namespace
