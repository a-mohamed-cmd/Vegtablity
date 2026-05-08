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

        Private _isFilteringAccount As Boolean = False
        
        Private Sub AccountComboBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            If _isFilteringAccount Then Return
            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            Dim tb = TryCast(e.OriginalSource, TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm Is Nothing Then Return

            Dim searchText = tb.Text
            vm.FilterAccounts(searchText)
            
            _isFilteringAccount = True
            cb.IsDropDownOpen = True
            tb.Text = searchText
            tb.CaretIndex = tb.Text.Length
            _isFilteringAccount = False
        End Sub

                Private Sub AccountComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim cb = TryCast(sender, ComboBox)
                If cb Is Nothing Then Return

                If cb.IsDropDownOpen Then cb.IsDropDownOpen = False

                Dim moveFocusNext = Sub()
                    cb.Dispatcher.BeginInvoke(New Action(Sub()
                        Try
                            Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                            Dim focusedElement = TryCast(System.Windows.Input.Keyboard.FocusedElement, System.Windows.UIElement)
                            If focusedElement IsNot Nothing Then
                                focusedElement.MoveFocus(request)
                            Else
                                cb.MoveFocus(request)
                            End If
                        Catch ex As Exception
                        End Try
                    End Sub), System.Windows.Threading.DispatcherPriority.Background)
                End Sub
                
                Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
                If vm Is Nothing Then Return
                
                If cb.SelectedItem IsNot Nothing Then
                    moveFocusNext()
                    Return
                End If
                
                Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
                If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim match As Models.Account = Nothing
                    
                    If vm.Accounts IsNot Nothing Then
                        match = System.Linq.Enumerable.FirstOrDefault(vm.Accounts, Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower() = searchText) OrElse (a.AccountCode IsNot Nothing AndAlso a.AccountCode = searchText))
                    End If
                    
                    If match Is Nothing AndAlso vm.FilteredAccounts IsNot Nothing Then
                        match = System.Linq.Enumerable.FirstOrDefault(vm.FilteredAccounts, Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower() = searchText) OrElse (a.AccountCode IsNot Nothing AndAlso a.AccountCode = searchText))
                    End If
                    
                    If match Is Nothing AndAlso vm.FilteredAccounts IsNot Nothing AndAlso vm.FilteredAccounts.Count = 1 Then
                        match = vm.FilteredAccounts(0)
                    End If
                    
                    If match IsNot Nothing Then
                        cb.SelectedItem = match
                        moveFocusNext()
                        Return
                    End If
                End If

                ShowSnackbar("الرجاء اختيار اسم أو رقم الحساب الصحيح من القائمة")
            End If
        End Sub
    End Class
End Namespace