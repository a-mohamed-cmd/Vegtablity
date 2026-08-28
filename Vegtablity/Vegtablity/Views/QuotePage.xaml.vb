Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports System.Windows.Threading
Imports Vegtablity.ViewModels
Imports Vegtablity.Models

Namespace Views
    Public Class QuotePage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.PropertyChanged, AddressOf OnViewModelPropertyChanged
                AddHandler vm.InvoiceLoaded, AddressOf OnInvoiceLoaded
            End If
            ' نضبط الواجهة بعد اكتمال تحميل كل عناصر الـ UI
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            ' يُستدعى مرة واحدة بعد اكتمال تحميل الصفحة — يضبط التاريخ والعميل
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing Then Return
            TxtQuoteDate.Text = vm.QuoteDateText
            TxtExpiryDate.Text = vm.ExpiryDateText

            If vm.CurrentQuote IsNot Nothing AndAlso vm.CurrentQuote.PartnerID > 0 Then
                Dim name = vm.CurrentQuote.PartnerName
                If String.IsNullOrEmpty(name) Then
                    Dim p = vm.AllPartners.FirstOrDefault(Function(x) x.PartnerID = vm.CurrentQuote.PartnerID)
                    If p IsNot Nothing Then name = p.PartnerName
                End If
                If Not String.IsNullOrEmpty(name) Then
                    PartnerDropdown.SetDisplayText(name)
                Else
                    PartnerDropdown.ClearSelection()
                End If
            Else
                PartnerDropdown.ClearSelection()
            End If
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As System.ComponentModel.PropertyChangedEventArgs)
            If e.PropertyName = "HistoryPage" Then
                AnimateGrid(dgHistory)
            ElseIf e.PropertyName = "DetailsPage" Then
                AnimateGrid(DetailsItemsControl)
            End If
        End Sub

        Private Sub AnimateGrid(grid As UIElement)
            If grid Is Nothing Then Return
            Dim fadeOut As New Media.Animation.DoubleAnimation(1, 0, New Duration(TimeSpan.FromMilliseconds(100)))
            Dim fadeIn As New Media.Animation.DoubleAnimation(0, 1, New Duration(TimeSpan.FromMilliseconds(200)))
            
            AddHandler fadeOut.Completed, Sub()
                                              grid.BeginAnimation(UIElement.OpacityProperty, fadeIn)
                                          End Sub
            grid.BeginAnimation(UIElement.OpacityProperty, fadeOut)
        End Sub

        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible

            Dim timer As New DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(sender, e)
                                       SnackbarBorder.Visibility = Visibility.Collapsed
                                       timer.Stop()
                                   End Sub
            timer.Start()
        End Sub

        Private Sub HistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Visible
        End Sub

        Private Sub CloseHistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        Private Sub EditFromHistory_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        ' --- Grid Interactions (Simulating SalesInvoicePage UX) ---
        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        Private Sub AddItemButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                    Dim lastIndex = DetailsItemsControl.Items.Count - 1
                    Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                    If container IsNot Nothing Then
                        Dim rowCtrl = FindVisualChild(Of Controls.QuoteItemRowControl)(container)
                        If rowCtrl IsNot Nothing Then
                            rowCtrl.FocusBarcode()
                            Return
                        End If
                    End If
                    DetailsItemsControl.Dispatcher.BeginInvoke(New Action(Sub()
                        Dim retryContainer = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                        If retryContainer IsNot Nothing Then
                            Dim retryCtrl = FindVisualChild(Of Controls.QuoteItemRowControl)(retryContainer)
                            If retryCtrl IsNot Nothing Then retryCtrl.FocusBarcode()
                        End If
                    End Sub), System.Windows.Threading.DispatcherPriority.Loaded)
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        ' ══════════════════════════════════════════════════
        '  QuoteItemRowControl Event Handlers
        ' ══════════════════════════════════════════════════

        Private Sub QuoteItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                vm.AddItemCommand.Execute(Nothing)
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub QuoteItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.QuoteItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.QuoteDetail)
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing Then
                vm.RemoveItemCommand.Execute(detail)
            End If
        End Sub

        Private Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            If parent Is Nothing Then Return Nothing
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

        Private Sub BarcodeSearchBox_KeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim vm = TryCast(DataContext, QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemByBarcodeCommand.CanExecute(Nothing) Then
                    vm.AddItemByBarcodeCommand.Execute(Nothing)
                End If
                e.Handled = True
            End If
        End Sub

        ' ══════════════════════════════════════════════════

        ' ══════════════════════════════════════════════════════
        '  Partner SearchableDropdown — عروض الأسعار
        ' ══════════════════════════════════════════════════════

        Private Sub PartnerDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing Then vm.ApplyPartnerFilter(e)
        End Sub

        Private Sub PartnerDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Partner)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing AndAlso vm.CurrentQuote IsNot Nothing Then
                vm.CurrentQuote.PartnerID = selected.PartnerID
                vm.CurrentQuote.PartnerName = selected.PartnerName
            End If
        End Sub

        Private Sub PartnerDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then ctrl.MoveFocus(req)
        End Sub

        ''' <summary>
        ''' يُستدعى تلقائياً بعد تحميل عرض سعر موجود أو إنشاء جديد.
        ''' يضبط حقل التاريخ واسم الشريك في الأداة.
        ''' </summary>
        Private Sub OnInvoiceLoaded(partnerID As Integer?, partnerName As String)
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing Then Return

            ' تحديث حقول التاريخ
            TxtQuoteDate.Text = vm.QuoteDateText
            TxtQuoteDate.Foreground = System.Windows.Media.Brushes.Black
            TxtExpiryDate.Text = vm.ExpiryDateText
            TxtExpiryDate.Foreground = System.Windows.Media.Brushes.Black

            ' تحديث اسم الشريك بعد اكتمال كل تحديثات الـ UI
            Dim capturedName = partnerName
            Dim capturedID = partnerID
            Dispatcher.BeginInvoke(New Action(Sub()
                If capturedID.HasValue AndAlso capturedID.Value > 0 Then
                    If String.IsNullOrEmpty(capturedName) AndAlso vm IsNot Nothing Then
                        Dim p = vm.AllPartners.FirstOrDefault(Function(x) x.PartnerID = capturedID.Value)
                        If p IsNot Nothing Then capturedName = p.PartnerName
                    End If
                    If Not String.IsNullOrEmpty(capturedName) Then
                        PartnerDropdown.SetDisplayText(capturedName)
                    Else
                        PartnerDropdown.ClearSelection()
                    End If
                Else
                    PartnerDropdown.ClearSelection()
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Loaded)
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
            If e.Key = System.Windows.Input.Key.Down OrElse e.Key = System.Windows.Input.Key.Up Then Return
            If e.Key = System.Windows.Input.Key.Tab Then Return
        End Sub

        Private Sub QuoteDate_LostFocus(sender As Object, e As RoutedEventArgs)
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
                Dim vm = TryCast(Me.DataContext, ViewModels.QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentQuote IsNot Nothing Then
                    vm.CurrentQuote.QuoteDate = parsed
                    vm.QuoteDateText = parsed.ToString("dd/MM/yyyy")
                End If
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub ExpiryDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            ' السماح بتفريغ تاريخ الانتهاء
            If String.IsNullOrWhiteSpace(raw) Then
                Dim vm0 = TryCast(Me.DataContext, ViewModels.QuoteViewModel)
                If vm0 IsNot Nothing AndAlso vm0.CurrentQuote IsNot Nothing Then
                    vm0.CurrentQuote.ExpiryDate = Nothing
                    vm0.ExpiryDateText = ""
                End If
                Return
            End If
            ' قبول صيغة بدون فواصل: 01062026 → 01/06/2026
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, New String() {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                Dim vm = TryCast(Me.DataContext, ViewModels.QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentQuote IsNot Nothing Then
                    vm.CurrentQuote.ExpiryDate = parsed
                    vm.ExpiryDateText = parsed.ToString("dd/MM/yyyy")
                End If
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

    Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
        If child Is Nothing Then Return Nothing
        Dim parentObject As DependencyObject = System.Windows.Media.VisualTreeHelper.GetParent(child)
        If parentObject Is Nothing Then Return Nothing
        Dim parent As T = TryCast(parentObject, T)
        If parent IsNot Nothing Then
            Return parent
        Else
            Return FindVisualParent(Of T)(parentObject)
        End If
    End Function
End Class
End Namespace
