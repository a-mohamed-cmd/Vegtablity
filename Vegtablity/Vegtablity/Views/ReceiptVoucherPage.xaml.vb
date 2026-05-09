Imports System.Windows.Input
Imports System.Windows.Controls

Namespace Views
    Partial Public Class ReceiptVoucherPage
        Private Sub Amount_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim regex As New System.Text.RegularExpressions.Regex("[^0-9.]+")
            If regex.IsMatch(e.Text) Then
                e.Handled = True
                Return
            End If
            
            Dim txt As TextBox = TryCast(sender, TextBox)
            If txt IsNot Nothing AndAlso e.Text = "." AndAlso txt.Text.Contains(".") Then
                e.Handled = True
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
                Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.EditReceiptDate = parsed
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
        ' ══════════════════════════════════════════════════════
        '  Account SearchableDropdown — سند القبض
        ' ══════════════════════════════════════════════════════

        Private Sub AccountDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.FilterAccounts(e)
        End Sub

        Private Sub AccountDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Account)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.EditReceiptAccountID = selected.AccountID
        End Sub

        Private Sub AccountDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then ctrl.MoveFocus(req)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Voucher Synchronization
        ' ══════════════════════════════════════════════════════

        Private Sub ReceiptVoucherPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.ReceiptLoaded, AddressOf OnReceiptLoaded
                AddHandler vm.ReceiptLoaded, AddressOf OnReceiptLoaded
                
                ' تهيئة الحالة الأولية
                If Not vm.IsEditingReceipt Then
                    AccountDropdown.ClearSelection()
                End If
            End If
        End Sub

        Private Sub OnReceiptLoaded(accountID As Integer?, accountName As String)
            Dispatcher.BeginInvoke(Sub()
                If accountID.HasValue AndAlso Not String.IsNullOrEmpty(accountName) Then
                    AccountDropdown.SetDisplayText(accountName)
                Else
                    AccountDropdown.ClearSelection()
                End If
            End Sub, System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

    End Class
End Namespace
