Imports System.Windows
Imports System.Windows.Input
Imports System.Windows.Controls

Namespace Views
    Partial Public Class PaymentVoucherPage
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

        ''' <summary>زر الرجوع — يعود للصفحة السابقة في النافيجاشن ستاك</summary>
        Private Sub BtnGoBack_Click(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing AndAlso parent.CanGoBack Then
                parent.GoBack()
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Sidebar / Edit Panel Collapse & Expand Animation
        ' ══════════════════════════════════════════════════
        Private Sub ToggleEditorButton_Click(sender As Object, e As RoutedEventArgs)
            If EditColumn Is Nothing OrElse EditPanelBorder Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            
            Dim isCollapsing As Boolean = (EditColumn.Width.Value > 50)
            Dim startVal As Double = If(isCollapsing, 380, 0)
            Dim endVal As Double = If(isCollapsing, 0, 380)

            Dim anim As New System.Windows.Media.Animation.DoubleAnimation() With {
                .From = startVal,
                .To = endVal,
                .Duration = TimeSpan.FromMilliseconds(220),
                .EasingFunction = New System.Windows.Media.Animation.CubicEase() With {.EasingMode = System.Windows.Media.Animation.EasingMode.EaseOut}
            }
            
            AddHandler anim.Completed, Sub(s, args)
                                          EditColumn.Width = New GridLength(endVal)
                                       End Sub
            EditPanelBorder.BeginAnimation(FrameworkElement.WidthProperty, anim)
            EditColumn.Width = New GridLength(endVal)
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
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
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub PaymentDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
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
                tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub
    
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    PaymentDate_LostFocus(tb, Nothing)
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

        ' ══════════════════════════════════════════════════
        '  Account SearchableDropdown — سند الصرف
        ' ══════════════════════════════════════════════════

        Private Sub AccountDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.FilterAccounts(e)
        End Sub

        Private Sub AccountDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Account)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.EditPaymentAccountID = selected.AccountID
        End Sub

        Private Sub AccountDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then ctrl.MoveFocus(req)
        End Sub

        ' ══════════════════════════════════════════════════
        '  Voucher Synchronization
        ' ══════════════════════════════════════════════════

        Private Sub PaymentVoucherPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.PaymentLoaded, AddressOf OnPaymentLoaded
                AddHandler vm.PaymentLoaded, AddressOf OnPaymentLoaded
                
                ' تهيئة الحالة الأولية
                If Not vm.IsEditingPayment Then
                    AccountDropdown.ClearSelection()
                End If
            End If
        End Sub

        Private Sub OnPaymentLoaded(accountID As Integer?, accountName As String)
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
