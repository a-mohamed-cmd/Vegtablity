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
            End Set
        End Property

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
            End Set
        End Property

        Public ReadOnly Property Difference As Decimal
            Get
                Return TotalDebit - TotalCredit
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
        End Sub

        ' === Methods ===

        Private Sub LoadAccounts()
            Accounts = New ObservableCollection(Of Account)(_accountingService.GetAllAccounts().Where(Function(a) a.IsTransactional))
        End Sub

        Private Sub LoadList()
            JournalList = New ObservableCollection(Of JournalHeader)(_accountingService.GetAllJournalHeaders())
        End Sub

        Private Sub LoadJournal(jid As Integer)
            ' Find the header in the list
            Dim header = JournalList.FirstOrDefault(Function(j) j.JID = jid)
            If header IsNot Nothing Then
                ' Fetch details from DB
                Dim details = _accountingService.GetJournalDetails(jid)
                
                ' Populate Details first
                header.Details = New ObservableCollection(Of JournalDetail)(details)
                
                ' Add listeners to existing rows
                For Each d In header.Details
                    AddHandler d.PropertyChanged, AddressOf OnDetailPropertyChanged
                Next
                
                ' Now set as CurrentJournal to trigger UI notification
                CurrentJournal = header
                UpdateTotals()
            End If
        End Sub

        Private Sub NewJournal()
            CurrentJournal = New JournalHeader() With {
                .JDate = DateTime.Now,
                .UserID = Session.CurrentUser?.UserID,
                .Details = New ObservableCollection(Of JournalDetail)()
            }
            ' Add two default lines
            AddLine()
            AddLine()
            UpdateTotals()
        End Sub

        Private Sub AddLine()
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

        Private Function CanSave(obj As Object) As Boolean
            If CurrentPermissions Is Nothing Then Return False
            If CurrentJournal Is Nothing OrElse CurrentJournal.IsPosted Then Return False
            
            If CurrentJournal.JID = 0 AndAlso Not CurrentPermissions.CanAdd Then Return False
            If CurrentJournal.JID > 0 AndAlso Not CurrentPermissions.CanEdit Then Return False

            Return True
        End Function

        Private Sub ExecuteSave(obj As Object)
            ' 1. التحقق من اتزان القيد
            If TotalDebit <> TotalCredit Then
                MessageBox.Show("القيد غير متزن! يجب أن يتساوى إجمالي المدين مع إجمالي الدائن." & vbCrLf & "الفرق الحالي: " & Difference.ToString("N2"),
                                "خطأ في الاتزان", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' 2. التحقق من وجود مبالغ
            If TotalDebit = 0 Then
                MessageBox.Show("لا يمكن حفظ قيد بقيمة صفر.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' 3. التحقق من اختيار الحسابات لكافة الأسطر
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
                LoadList()
                ' Find and select the saved one
                SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = jid)
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
                    LoadList()
                    SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = CurrentJournal.JID)
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
                    LoadList()
                    SelectedJournal = JournalList.FirstOrDefault(Function(j) j.JID = CurrentJournal.JID)
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
            ReportExporter.ExportJournalToPdf(CurrentJournal)
        End Sub

    End Class
End Namespace
