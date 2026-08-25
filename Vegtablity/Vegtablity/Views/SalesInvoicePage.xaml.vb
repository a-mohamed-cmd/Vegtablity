Imports System.Windows.Input
Imports System.Windows.Controls
Imports System.Linq
Imports Vegtablity.ViewModels
Imports System.Windows.Controls.Primitives

Namespace Views
    Public Class SalesInvoicePage
        Public Sub New()
            InitializeComponent()
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.InvoiceLoaded, AddressOf OnInvoiceLoaded
            End If
            ' نضبط الواجهة بعد اكتمال تحميل كل عناصر الـ UI
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            ' يُستدعى مرة واحدة بعد اكتمال تحميل الصفحة — يضبط التاريخ للفاتورة الجديدة
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm Is Nothing Then Return
            TxtInvDate.Text = vm.InvDateText
            PartnerDropdown.ClearSelection()  ' فاتورة جديدة — بدون شريك
        End Sub

        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = System.Windows.Visibility.Visible
            Dim timer As New System.Windows.Threading.DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(s, e)
                                       SnackbarBorder.Visibility = System.Windows.Visibility.Collapsed
                                       DirectCast(s, System.Windows.Threading.DispatcherTimer).Stop()
                                   End Sub
            timer.Start()
        End Sub

        ''' <summary>زر الرجوع — يعود للصفحة السابقة في النافيجاشن ستاك</summary>
        Private Sub BtnGoBack_Click(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing AndAlso parent.CanGoBack Then
                parent.GoBack()
            End If
        End Sub

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                    Dim lastIndex = DetailsItemsControl.Items.Count - 1
                    Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                    If container IsNot Nothing Then
                        Dim rowCtrl = FindVisualChild(Of Controls.InvoiceItemRowControl)(container)
                        If rowCtrl IsNot Nothing Then
                            rowCtrl.FocusBarcode()
                        End If
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Background)
        End Sub

        Private Sub NewInvoiceButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub AddItemButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  InvoiceItemRowControl Event Handlers
        ' ══════════════════════════════════════════════════

        Private Sub InvoiceItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                vm.AddItemCommand.Execute(Nothing)
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub InvoiceItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.InvoiceItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.InvoiceDetail)
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing Then
                vm.RemoveItemCommand.Execute(detail)
            End If
        End Sub

        Private Sub InvoiceItemRow_AmountChanged(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing Then
                System.Windows.Input.CommandManager.InvalidateRequerySuggested()
            End If
        End Sub

        Private Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            For i As Integer = 0 To System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i)
                If child IsNot Nothing AndAlso TypeOf child Is T Then
                    Return DirectCast(child, T)
                Else
                    Dim childOfChild As T = FindVisualChild(Of T)(child)
                    If childOfChild IsNot Nothing Then
                        Return childOfChild
                    End If
                End If
            Next
            Return Nothing
        End Function

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then
                Return parent
            Else
                Return FindVisualParent(Of T)(parentObject)
            End If
        End Function

        ' ── Decimal-only input handlers (Discount & PaidAmount) ──
        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As Input.TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim newText = tb.Text.Substring(0, tb.SelectionStart) &
                          e.Text &
                          tb.Text.Substring(tb.SelectionStart + tb.SelectionLength)
            Dim isValid = System.Text.RegularExpressions.Regex.IsMatch(newText, "^\d*\.?\d*$")
            e.Handled = Not isValid
        End Sub

        Private Sub DecimalBox_PreviewKeyDown(sender As Object, e As Input.KeyEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim isDecimalKey = (e.Key = Input.Key.OemPeriod OrElse
                                e.Key = Input.Key.Decimal OrElse
                                e.Key = Input.Key.OemComma)
            If isDecimalKey Then
                If Not tb.Text.Contains(".") Then
                    Dim pos = tb.SelectionStart
                    Dim current = tb.Text.Remove(pos, tb.SelectionLength)
                    tb.Text = current.Insert(pos, ".")
                    tb.SelectionStart = pos + 1
                End If
                e.Handled = True
            End If
        End Sub

        Private Sub DecimalBox_Pasting(sender As Object, e As System.Windows.DataObjectPastingEventArgs)
            If e.DataObject.GetDataPresent(GetType(String)) Then
                Dim pastedText = CStr(e.DataObject.GetData(GetType(String)))
                If Not System.Text.RegularExpressions.Regex.IsMatch(pastedText, "^\d*\.?\d*$") Then
                    e.CancelCommand()
                End If
            Else
                e.CancelCommand()
            End If
        End Sub
        Private Sub HistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Visible
        End Sub

        Private Sub CloseHistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        Private Sub EditFromHistory_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing Then Return

            Dim invoice = TryCast(btn.DataContext, Models.InvoiceHeader)
            If invoice Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing Then
                vm.LoadInvoice(invoice.InvID)  ' InvoiceLoaded event يتكفل بتحديث الـ View
            End If

            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        ''' <summary>
        ''' يُستدعى تلقائياً بعد تحميل فاتورة موجودة أو إنشاء جديدة.
        ''' يضبط حقل التاريخ واسم الشريك في الأداة.
        ''' </summary>
        Private Sub OnInvoiceLoaded(partnerID As Integer?, partnerName As String)
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm Is Nothing Then Return

            ' تحديث حقل التاريخ
            TxtInvDate.Text = vm.InvDateText
            TxtInvDate.Foreground = System.Windows.Media.Brushes.Black

            ' تحديث اسم الشريك بعد اكتمال كل تحديثات الـ UI
            Dim capturedName = partnerName
            Dim capturedID = partnerID
            Dispatcher.BeginInvoke(New Action(Sub()
                If capturedID.HasValue AndAlso Not String.IsNullOrEmpty(capturedName) Then
                    PartnerDropdown.SetDisplayText(capturedName)
                Else
                    PartnerDropdown.ClearSelection()
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

        ' ══════════════════════════════════════════════════

        ' ══════════════════════════════════════════════════════
        '  Partner SearchableDropdown — فاتورة المبيعات
        ' ══════════════════════════════════════════════════════

        Private Sub PartnerDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing Then vm.ApplyPartnerFilter(e)
        End Sub

        Private Sub PartnerDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Partner)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing AndAlso vm.CurrentInvoice IsNot Nothing Then
                vm.CurrentInvoice.PartnerID = selected.PartnerID
            End If
        End Sub

        Private Sub PartnerDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then ctrl.MoveFocus(req)
        End Sub


        Private Sub InvDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If String.IsNullOrWhiteSpace(raw) Then Return

            ' قبول صيغة بدون فواصل: 01052026 → 01/05/2026
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, New String() {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                ' ✅ تحديث التاريخ الفعلي في الـ ViewModel حتى يُرسَل للـ SP عند الحفظ
                Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentInvoice IsNot Nothing Then
                    vm.CurrentInvoice.InvDate = parsed
                End If
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
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
                    Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(req)
                End If
            End If
        End Sub

        Private Sub dgInvoiceDetails_ArrowNav_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            ' Allow normal DataGrid arrow navigation
        End Sub
    End Class
End Namespace
