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
            If dgDetails Is Nothing Then Return
            Dim fade As New DoubleAnimation() With {
                .From = 0.4,
                .To = 1.0,
                .Duration = New Duration(TimeSpan.FromMilliseconds(250)),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
            }
            dgDetails.BeginAnimation(UIElement.OpacityProperty, fade)
        End Sub

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

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                                                  If dgDetails IsNot Nothing AndAlso dgDetails.Items.Count > 0 Then
                                                      dgDetails.SelectedIndex = dgDetails.Items.Count - 1
                                                      Dim newItem = dgDetails.Items(dgDetails.Items.Count - 1)

                                                      ' 1. Focus the cell (index 0 for Barcode column)
                                                      dgDetails.CurrentCell = New DataGridCellInfo(newItem, dgDetails.Columns(0))

                                                      ' 2. Scroll into view and update layout
                                                      dgDetails.ScrollIntoView(newItem, dgDetails.Columns(0))
                                                      dgDetails.UpdateLayout()

                                                      ' 3. Extract the physical row container
                                                      Dim rowContainer As DataGridRow = TryCast(dgDetails.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
                                                      If rowContainer IsNot Nothing Then
                                                          Dim presenter As System.Windows.Controls.Primitives.DataGridCellsPresenter = FindVisualChild(Of System.Windows.Controls.Primitives.DataGridCellsPresenter)(rowContainer)
                                                          If presenter IsNot Nothing Then
                                                              ' 4. Extract the physical cell container at column 0
                                                              Dim cell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(0), DataGridCell)
                                                              If cell IsNot Nothing Then
                                                                  ' 5. Finally, grab the TextBox inside and forcefully focus it
                                                                  Dim tb As TextBox = FindVisualChild(Of TextBox)(cell)
                                                                  If tb IsNot Nothing Then
                                                                      System.Windows.Input.Keyboard.Focus(tb)
                                                                  Else
                                                                      cell.Focus()
                                                                  End If
                                                              End If
                                                          End If
                                                      End If
                                                  End If
                                              End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        Private Sub Barcode_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
                    If vm IsNot Nothing Then
                        Dim matchedProduct = vm.Products.FirstOrDefault(Function(p) p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText)
                        If matchedProduct IsNot Nothing Then
                            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                            If cell IsNot Nothing Then
                                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                If row IsNot Nothing Then
                                    Dim detail = TryCast(row.Item, PurchaseQuoteDetail)
                                    If detail IsNot Nothing Then
                                        detail.ProductID = matchedProduct.ProductID
                                        detail.Barcode = matchedProduct.Barcode
                                        detail.ProductName = matchedProduct.ProductName
                                        detail.UnitName = matchedProduct.UnitName
                                        detail.UnitPrice = matchedProduct.PurchasePrice
                                    End If
                                End If
                            End If
                            e.Handled = True

                            ' Move Focus to UnitPrice column (Index 3 - skip Name and Unit)
                            MoveFocusToNextColumn(tb, 3)
                        Else
                            tb.SelectAll()
                            e.Handled = True
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub Price_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                ' Force the binding to commit
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                    If binding IsNot Nothing Then binding.UpdateSource()
                End If

                e.Handled = True
                ' Add new row
                Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                    vm.AddItemCommand.Execute(Nothing)
                End If

                ' Focus the barcode cell of the newly added row
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub MoveFocusToNextColumn(currentControl As UIElement, columnOffset As Integer)
            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(currentControl)
            If cell IsNot Nothing Then
                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                Dim dg As DataGrid = FindVisualParent(Of DataGrid)(row)

                If row IsNot Nothing AndAlso dg IsNot Nothing Then
                    Dim currentColumnIndex = dg.Columns.IndexOf(cell.Column)
                    Dim nextColumnIndex = currentColumnIndex + columnOffset

                    If nextColumnIndex < dg.Columns.Count AndAlso row.Item IsNot Nothing Then
                        dg.CurrentCell = New DataGridCellInfo(row.Item, dg.Columns(nextColumnIndex))

                        Dispatcher.BeginInvoke(New Action(Sub()
                                                              dg.UpdateLayout()
                                                              dg.ScrollIntoView(row.Item, dg.Columns(nextColumnIndex))
                                                              Dim rowContainer As DataGridRow = TryCast(dg.ItemContainerGenerator.ContainerFromItem(row.Item), DataGridRow)
                                                              If rowContainer IsNot Nothing Then
                                                                  Dim presenter As System.Windows.Controls.Primitives.DataGridCellsPresenter = FindVisualChild(Of System.Windows.Controls.Primitives.DataGridCellsPresenter)(rowContainer)
                                                                  If presenter IsNot Nothing Then
                                                                      Dim nextCell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(nextColumnIndex), DataGridCell)
                                                                      If nextCell IsNot Nothing Then
                                                                          nextCell.Focus()
                                                                          Dim tb As TextBox = FindVisualChild(Of TextBox)(nextCell)
                                                                          If tb IsNot Nothing Then
                                                                              System.Windows.Input.Keyboard.Focus(tb)
                                                                              Dispatcher.BeginInvoke(New Action(Sub()
                                                                                                                    tb.SelectAll()
                                                                                                                End Sub), System.Windows.Threading.DispatcherPriority.Input)
                                                                          Else
                                                                              nextCell.Focus()
                                                                          End If
                                                                      End If
                                                                  End If
                                                              End If
                                                          End Sub), System.Windows.Threading.DispatcherPriority.Input)
                    End If
                End If
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

        ' ══════════════════════════════════════════════════════
        '  Product ComboBox Logic (DataGrid)
        ' ══════════════════════════════════════════════════════

        Private Sub ProductComboBox_KeyUp(sender As Object, e As KeyEventArgs)
            If _isUpdatingProduct Then Return

            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsEditable Then Return

            ' Skip navigation keys
            If e.Key = Key.Up OrElse e.Key = Key.Down OrElse e.Key = Key.Enter OrElse e.Key = Key.Escape Then Return

            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb Is Nothing Then Return

            Dim searchText = tb.Text.Trim()
            Dim view As System.ComponentModel.ICollectionView = cmb.Items

            If String.IsNullOrWhiteSpace(searchText) Then
                view.Filter = Nothing
                cmb.IsDropDownOpen = False
            Else
                view.Filter = Function(obj)
                                  Dim p = TryCast(obj, Product)
                                  If p Is Nothing Then Return False
                                  Return (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText.ToLower())) OrElse
                                         (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(searchText.ToLower()))
                              End Function
                cmb.IsDropDownOpen = True
                tb.Text = searchText
                tb.SelectionStart = searchText.Length
            End If
        End Sub

        Private Sub ProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim cmb = TryCast(sender, ComboBox)
                If cmb IsNot Nothing AndAlso cmb.IsEditable Then
                    Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
                    If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                        Dim searchText = tb.Text.Trim().ToLower()
                        Dim vm = TryCast(Me.DataContext, PurchaseQuoteViewModel)
                        If vm IsNot Nothing AndAlso vm.Products IsNot Nothing Then
                            Dim matchedProduct = vm.Products.FirstOrDefault(Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)))

                            If matchedProduct IsNot Nothing Then
                                cmb.SelectedValue = matchedProduct.ProductID
                                ' Clear filter
                                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                                If view IsNot Nothing Then view.Filter = Nothing

                                e.Handled = True
                                cmb.IsDropDownOpen = False

                                ' Update the model directly
                                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                                If cell IsNot Nothing Then
                                    Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                    If row IsNot Nothing Then
                                        Dim detail = TryCast(row.Item, PurchaseQuoteDetail)
                                        If detail IsNot Nothing Then
                                            detail.ProductID = matchedProduct.ProductID
                                            detail.Barcode = matchedProduct.Barcode
                                            detail.ProductName = matchedProduct.ProductName
                                            detail.UnitName = matchedProduct.UnitName
                                            detail.UnitPrice = matchedProduct.PurchasePrice
                                        End If
                                    End If
                                End If

                                ' Move Focus to Price (Index 3 - skip Unit)
                                MoveFocusToNextColumn(cmb, 2)
                            End If
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub ProductComboBox_DropDownOpened(sender As Object, e As EventArgs)
            ' Clear filter when opening to show all
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing Then
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
            End If
        End Sub

        Private Sub ProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing AndAlso cmb.SelectedItem IsNot Nothing Then
                _isUpdatingProduct = True
                Dim selected = TryCast(cmb.SelectedItem, Product)
                If selected IsNot Nothing Then
                    Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                    If cell IsNot Nothing Then
                        Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                        If row IsNot Nothing Then
                            Dim detail = TryCast(row.Item, PurchaseQuoteDetail)
                            If detail IsNot Nothing Then
                                detail.ProductID = selected.ProductID
                                detail.Barcode = selected.Barcode
                                detail.ProductName = selected.ProductName
                                detail.UnitName = selected.UnitName
                                detail.UnitPrice = selected.PurchasePrice
                            End If
                        End If
                    End If
                End If
                _isUpdatingProduct = False

                ' Give priority to the view update, then jump to UnitPrice column (Index 3)
                Dispatcher.BeginInvoke(New Action(Sub()
                                                       MoveFocusToNextColumn(cmb, 2)
                                                   End Sub), System.Windows.Threading.DispatcherPriority.Input)
            End If
        End Sub

        Private Sub ProductComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            ' Clear filter to avoid showing partial list next time
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing Then
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
            End If
        End Sub

        Private Sub dgInvoiceDetails_ArrowNav_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            ' ... Implementation from plan (if needed) or keep existing
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
