Imports System.Windows.Controls

Namespace Views
    Partial Public Class VouchersPage
        Private _voucherType As String

        Public Sub New()
            InitializeComponent()
        End Sub

        Public Sub New(voucherType As String)
            InitializeComponent()
            _voucherType = voucherType

            ' اختيار التبويب المناسب تلقائياً
            If voucherType = "Payment" Then
                VoucherTabControl.SelectedIndex = 1
            Else
                VoucherTabControl.SelectedIndex = 0
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
        Private Sub ReceiptDate_LostFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim parsed As DateTime
            If ParseDateInput(tb.Text, parsed) Then
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

        Private Sub PaymentDate_LostFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim parsed As DateTime
            If ParseDateInput(tb.Text, parsed) Then
                Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.EditPaymentDate = parsed
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

        Private Function ParseDateInput(raw As String, ByRef parsed As DateTime) As Boolean
            raw = raw.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Return DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                          System.Globalization.CultureInfo.InvariantCulture,
                                          System.Globalization.DateTimeStyles.None, parsed)
        End Function
    
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

        ' ══════════════════════════════════════════════════════
        '  Account SearchableDropdown — سندات القبض والصرف
        ' ══════════════════════════════════════════════════════

        Private Sub ReceiptAccountDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.FilterAccounts(e)
        End Sub

        Private Sub ReceiptAccountDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Account)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.EditReceiptAccountID = selected.AccountID
        End Sub

        Private Sub PaymentAccountDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then vm.FilterAccounts(e)
        End Sub

        Private Sub PaymentAccountDropdown_ItemSelected(sender As Object, e As Object)
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

        ' ══════════════════════════════════════════════════════
        '  Voucher Synchronization
        ' ══════════════════════════════════════════════════════

        Private Sub VouchersPage_Loaded(sender As Object, e As System.Windows.RoutedEventArgs) Handles Me.Loaded
            Dim vm = TryCast(Me.DataContext, ViewModels.VouchersViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.ReceiptLoaded, AddressOf OnReceiptLoaded
                AddHandler vm.ReceiptLoaded, AddressOf OnReceiptLoaded
                
                RemoveHandler vm.PaymentLoaded, AddressOf OnPaymentLoaded
                AddHandler vm.PaymentLoaded, AddressOf OnPaymentLoaded

                ' تهيئة الحالة الأولية
                If Not vm.IsEditingReceipt Then ReceiptAccountDropdown.ClearSelection()
                If Not vm.IsEditingPayment Then PaymentAccountDropdown.ClearSelection()
            End If
        End Sub

        Private Sub OnReceiptLoaded(accountID As Integer?, accountName As String)
            Dispatcher.BeginInvoke(Sub()
                If accountID.HasValue AndAlso Not String.IsNullOrEmpty(accountName) Then
                    ReceiptAccountDropdown.SetDisplayText(accountName)
                Else
                    ReceiptAccountDropdown.ClearSelection()
                End If
            End Sub, System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

        Private Sub OnPaymentLoaded(accountID As Integer?, accountName As String)
            Dispatcher.BeginInvoke(Sub()
                If accountID.HasValue AndAlso Not String.IsNullOrEmpty(accountName) Then
                    PaymentAccountDropdown.SetDisplayText(accountName)
                Else
                    PaymentAccountDropdown.ClearSelection()
                End If
            End Sub, System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

    End Class
End Namespace
