Imports System.Windows.Controls

Namespace Views
    Partial Public Class JournalEntryPage
        Public Sub New()
            InitializeComponent()
        End Sub

        ' Update totals if user finishes editing a cell
        Public Sub DataGrid_CellEditEnding(sender As Object, e As DataGridCellEditEndingEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm IsNot Nothing Then
                ' Use Dispatcher to wait for the value to be committed to the model
                Dispatcher.BeginInvoke(Sub() vm.UpdateTotals(), Windows.Threading.DispatcherPriority.Background)
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
        Private Sub Date_LostFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentJournal IsNot Nothing Then
                    vm.CurrentJournal.JDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub Date_GotFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub
    
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
                If tb IsNot Nothing Then
                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub

        Private Async Sub ShowSnackbar(message As String)
            If SnackbarBorder Is Nothing Then Return
            SnackbarText.Text = message
            SnackbarIcon.Text = "⚠️"
            SnackbarBorder.Visibility = Visibility.Visible
            Await System.Threading.Tasks.Task.Delay(3000)
            SnackbarBorder.Visibility = Visibility.Collapsed
        End Sub
        ' ═══════════════════════════════════════════════════════════════════
        '  Account ComboBox — منطق البحث والاختيار (نهج نظيف موحد)
        ' ═══════════════════════════════════════════════════════════════════

        Private _cbSuppressEvents As Boolean = False

        Private Sub AccountComboBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            If _cbSuppressEvents Then Return
            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            Dim tb = TryCast(e.OriginalSource, TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm Is Nothing Then Return

            Dim selected = TryCast(cb.SelectedItem, Models.Account)
            If selected IsNot Nothing Then
                Dim expectedText = selected.AccountCode & " - " & selected.AccountName
                If tb.Text = expectedText Then Return
            End If

            _cbSuppressEvents = True
            cb.SelectedItem = Nothing
            _cbSuppressEvents = False

            Dim searchText = tb.Text.Trim()
            vm.FilterAccounts(searchText)

            cb.IsDropDownOpen = True

            Dispatcher.BeginInvoke(New Action(Sub()
                tb.CaretIndex = tb.Text.Length
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        Private Sub AccountComboBox_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            If _cbSuppressEvents Then Return
            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            Dim selected = TryCast(cb.SelectedItem, Models.Account)
            If selected Is Nothing Then Return

            _cbSuppressEvents = True
            Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
            If tb IsNot Nothing Then
                tb.Text = selected.AccountCode & " - " & selected.AccountName
                tb.CaretIndex = tb.Text.Length
            End If
            cb.IsDropDownOpen = False
            _cbSuppressEvents = False
        End Sub

        Private Sub AccountComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key <> Key.Enter Then Return
            e.Handled = True

            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            If cb.IsDropDownOpen Then cb.IsDropDownOpen = False

            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm Is Nothing Then Return

            If cb.SelectedItem IsNot Nothing Then
                AccountComboBox_MoveNext(cb)
                Return
            End If

            Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
            If tb Is Nothing OrElse String.IsNullOrWhiteSpace(tb.Text) Then
                ShowSnackbar("الرجاء اختيار أو كتابة اسم/رقم الحساب")
                Return
            End If

            Dim searchText = tb.Text.Trim().ToLower()
            Dim allSource = If(vm.Accounts, New System.Collections.ObjectModel.ObservableCollection(Of Models.Account)())
            Dim filtered = If(vm.FilteredAccounts, allSource)

            Dim match As Models.Account = Nothing

            match = System.Linq.Enumerable.FirstOrDefault(allSource,
                Function(a) String.Equals(a.AccountCode, searchText, StringComparison.OrdinalIgnoreCase) OrElse
                            String.Equals(a.AccountName, searchText, StringComparison.OrdinalIgnoreCase))

            If match Is Nothing Then
                match = System.Linq.Enumerable.FirstOrDefault(filtered,
                    Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower().Contains(searchText)) OrElse
                                (a.AccountCode IsNot Nothing AndAlso a.AccountCode.Contains(searchText)))
            End If

            If match Is Nothing AndAlso filtered.Count = 1 Then
                match = filtered(0)
            End If

            If match IsNot Nothing Then
                _cbSuppressEvents = True
                cb.SelectedItem = match
                _cbSuppressEvents = False
                AccountComboBox_MoveNext(cb)
            Else
                ShowSnackbar("لم يُعثر على حساب بهذا الاسم أو الرقم")
            End If
        End Sub

        Private Sub AccountComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            If _cbSuppressEvents Then Return
            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            Dim selected = TryCast(cb.SelectedItem, Models.Account)
            If selected Is Nothing Then Return

            Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
            If tb IsNot Nothing Then
                _cbSuppressEvents = True
                tb.Text = selected.AccountCode & " - " & selected.AccountName
                _cbSuppressEvents = False
            End If
        End Sub

        Private Sub AccountComboBox_MoveNext(cb As ComboBox)
            Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
            Dim focused = TryCast(System.Windows.Input.Keyboard.FocusedElement, System.Windows.UIElement)
            If focused IsNot Nothing Then
                focused.MoveFocus(request)
            Else
                cb.MoveFocus(request)
            End If
        End Sub

    End Class
End Namespace
