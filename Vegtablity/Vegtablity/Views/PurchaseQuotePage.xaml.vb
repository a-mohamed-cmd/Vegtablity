Imports System.Linq
Imports System.Windows.Controls
Imports System.Windows.Media.Animation
Imports Vegtablity.ViewModels
Imports Vegtablity.Models

Namespace Views
    Public Class PurchaseQuotePage
        Inherits UserControl

        Private _vm As PurchaseQuoteViewModel

        Public Sub New()
            InitializeComponent()
            ' Subscribe to ViewModel's events
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm IsNot Nothing Then
                _vm = vm
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.InvoiceLoaded, AddressOf OnInvoiceLoaded
                AddHandler vm.DetailsRefreshed, AddressOf AnimateDetailsRefresh
            End If
            ' نضبط الواجهة بعد اكتمال تحميل كل عناصر الـ UI
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm Is Nothing Then Return
            _vm = vm
            ' Wire up events in case DataContext wasn't ready in constructor
            AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
            AddHandler vm.InvoiceLoaded, AddressOf OnInvoiceLoaded
            AddHandler vm.DetailsRefreshed, AddressOf AnimateDetailsRefresh
            TxtQuoteDate.Text = vm.QuoteDateText
            TxtExpiryDate.Text = vm.ExpiryDateText
            PartnerDropdown.ClearSelection()
        End Sub

        ''' <summary>تشغيل Animation خفيف (FadeIn) على جدول الأصناف عند تحديث الصفحة</summary>
        Private Sub AnimateDetailsRefresh()
            If DetailsItemsControl Is Nothing Then Return
            Dim fade As New DoubleAnimation() With {
                .From = 0.4,
                .To = 1.0,
                .Duration = New Duration(TimeSpan.FromMilliseconds(250)),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
            }
            DetailsItemsControl.BeginAnimation(UIElement.OpacityProperty, fade)
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

        Private Sub OnInvoiceLoaded(partnerID As Integer?, partnerName As String)
            If _vm Is Nothing Then Return
            TxtQuoteDate.Text = _vm.QuoteDateText
            TxtExpiryDate.Text = _vm.ExpiryDateText

            ' Update Supplier Dropdown using dispatcher to ensure UI is ready
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

        Private _isUpdatingProduct As Boolean = False

        Private Sub PartnerDropdown_SearchChanged(sender As Object, searchText As String)
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm IsNot Nothing Then vm.ApplyPartnerFilter(searchText)
        End Sub

        Private Sub PartnerDropdown_ItemSelected(sender As Object, item As Object)
            Dim selected = TryCast(item, Partner)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm IsNot Nothing AndAlso vm.CurrentQuote IsNot Nothing Then
                vm.CurrentQuote.PartnerID = selected.PartnerID
                vm.CurrentQuote.PartnerName = selected.PartnerName
            End If
        End Sub

        Private Sub PartnerDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim req As New TraversalRequest(FocusNavigationDirection.Next)
            PartnerDropdown.MoveFocus(req)
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
                        End If
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Background)
        End Sub

        ' ══════════════════════════════════════════════════
        '  QuoteItemRowControl Event Handlers
        ' ══════════════════════════════════════════════════

        Private Sub QuoteItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                vm.AddItemCommand.Execute(Nothing)
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub QuoteItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.QuoteItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.PurchaseQuoteDetail)
            Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing Then
                vm.RemoveItemCommand.Execute(detail)
            End If
        End Sub

        Private Sub BarcodeSearch_KeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemByBarcodeCommand IsNot Nothing Then
                    vm.AddItemByBarcodeCommand.Execute(Nothing)
                End If
            End If
        End Sub

        Private Sub HistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Visible
        End Sub

        Private Sub CloseHistory_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        Private Sub HistoryEdit_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub Date_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                    tb.MoveFocus(req)
                End If
            End If
        End Sub

        Private Sub QuoteDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If String.IsNullOrWhiteSpace(raw) Then Return

            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, New String() {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                If _vm IsNot Nothing AndAlso _vm.CurrentQuote IsNot Nothing Then
                    _vm.CurrentQuote.QuoteDate = parsed
                    _vm.QuoteDateText = parsed.ToString("dd/MM/yyyy")
                End If
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
            End If
        End Sub

        Private Sub ExpiryDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If String.IsNullOrWhiteSpace(raw) Then
                If _vm IsNot Nothing AndAlso _vm.CurrentQuote IsNot Nothing Then
                    _vm.CurrentQuote.ExpiryDate = Nothing
                    _vm.ExpiryDateText = ""
                End If
                Return
            End If

            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, New String() {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                If _vm IsNot Nothing AndAlso _vm.CurrentQuote IsNot Nothing Then
                    _vm.CurrentQuote.ExpiryDate = parsed
                    _vm.ExpiryDateText = parsed.ToString("dd/MM/yyyy")
                End If
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
            End If
        End Sub

        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible

            Dim anim As New DoubleAnimation(0, 1, TimeSpan.FromSeconds(0.3))
            SnackbarBorder.BeginAnimation(OpacityProperty, anim)

            ' Hide after 3 seconds
            Dim timer As New System.Windows.Threading.DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(s, ev)
                                       timer.Stop()
                                       Dim hideAnim As New DoubleAnimation(1, 0, TimeSpan.FromSeconds(0.5))
                                       AddHandler hideAnim.Completed, Sub() SnackbarBorder.Visibility = Visibility.Collapsed
                                       SnackbarBorder.BeginAnimation(OpacityProperty, hideAnim)
                                   End Sub
            timer.Start()
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
