Imports System.Windows.Input

Namespace Views
    Partial Public Class PaymentVoucherPage
        Private Sub Amount_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim regex As New System.Text.RegularExpressions.Regex("[^0-9.]+")
            If regex.IsMatch(e.Text) Then
                e.Handled = True
                Return
            End If
            
            Dim txt As System.Windows.Controls.TextBox = TryCast(sender, System.Windows.Controls.TextBox)
            If txt IsNot Nothing AndAlso e.Text = "." AndAlso txt.Text.Contains(".") Then
                e.Handled = True
            End If
        End Sub

        Private Function ParseDateInput(raw As String, ByRef parsed As DateTime) As Boolean
            raw = raw.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Return DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed)
        End Function

        Private Sub Date_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub PaymentDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm Is Nothing Then Return

            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return

            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.EditPaymentDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
                tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy"
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
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

            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
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
                
                Dim moveFocus = Sub()
                                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                                    Dim focusedElement = TryCast(System.Windows.Input.Keyboard.FocusedElement, System.Windows.UIElement)
                                    If focusedElement IsNot Nothing Then
                                        focusedElement.MoveFocus(request)
                                    Else
                                        cb.MoveFocus(request)
                                    End If
                                End Sub

                Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
                If vm Is Nothing Then Return
                
                If cb.SelectedItem IsNot Nothing Then
                    moveFocus()
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
                        moveFocus()
                        Return
                    End If
                End If

                ShowSnackbar("الرجاء اختيار اسم أو رقم الحساب الصحيح من القائمة")
            End If
        End Sub

        Private Sub AccountComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then
                If cb.SelectedItem IsNot Nothing Then
                    Dim selected = TryCast(cb.SelectedItem, Models.Account)
                    Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
                    If tb IsNot Nothing AndAlso selected IsNot Nothing Then
                        _isFilteringAccount = True
                        tb.Text = selected.AccountCode & " - " & selected.AccountName
                        _isFilteringAccount = False
                    End If
                End If
            End If
        End Sub
End Class
End Namespace
