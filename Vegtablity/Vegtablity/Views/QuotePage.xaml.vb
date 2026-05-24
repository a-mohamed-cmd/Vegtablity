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
            ' يُستدعى مرة واحدة بعد اكتمال تحميل الصفحة — يضبط التاريخ للفاتورة الجديدة
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing Then Return
            TxtQuoteDate.Text = vm.QuoteDateText
            TxtExpiryDate.Text = vm.ExpiryDateText
            PartnerDropdown.ClearSelection()  ' عرض سعر جديد — بدون شريك
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As System.ComponentModel.PropertyChangedEventArgs)
            If e.PropertyName = "HistoryPage" Then
                AnimateGrid(dgHistory)
            ElseIf e.PropertyName = "DetailsPage" Then
                AnimateGrid(dgQuoteDetails)
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

        Private _isUpdatingProduct As Boolean = False

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
                        Dim vm = TryCast(Me.DataContext, QuoteViewModel)
                        If vm IsNot Nothing AndAlso vm.Products IsNot Nothing Then
                            Dim matchedProduct = vm.Products.FirstOrDefault(
                                Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                                            (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)))

                            If matchedProduct IsNot Nothing Then
                                cmb.SelectedValue = matchedProduct.ProductID
                                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                                If view IsNot Nothing Then view.Filter = Nothing

                                e.Handled = True
                                cmb.IsDropDownOpen = False

                                ' تحديث الموديل مباشرة
                                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                                If cell IsNot Nothing Then
                                    Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                    If row IsNot Nothing Then
                                        Dim detail = TryCast(row.Item, QuoteDetail)
                                        If detail IsNot Nothing Then
                                            detail.ProductID = matchedProduct.ProductID
                                            detail.Barcode = matchedProduct.Barcode
                                            detail.ProductName = matchedProduct.ProductName
                                            detail.UnitName = matchedProduct.UnitName
                                            detail.QuotedPrice = matchedProduct.SalePrice
                                        End If
                                    End If
                                End If

                                ' الانتقال لعمود السعر (Index 3)
                                MoveFocusToNextColumn(cmb, 2)
                            End If
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub ProductComboBox_DropDownOpened(sender As Object, e As EventArgs)
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
                            Dim detail = TryCast(row.Item, QuoteDetail)
                            If detail IsNot Nothing Then
                                detail.ProductID = selected.ProductID
                                detail.Barcode = selected.Barcode
                                detail.ProductName = selected.ProductName
                                detail.UnitName = selected.UnitName
                                detail.QuotedPrice = selected.SalePrice
                            End If
                        End If
                    End If
                End If
                _isUpdatingProduct = False

                ' الانتقال لعمود السعر (Index 3)
                Dispatcher.BeginInvoke(New Action(Sub()
                                                       MoveFocusToNextColumn(cmb, 2)
                                                   End Sub), System.Windows.Threading.DispatcherPriority.Input)
            End If
        End Sub

        Private Sub ProductComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing Then
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
            End If
        End Sub

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                                                  If dgQuoteDetails IsNot Nothing AndAlso dgQuoteDetails.Items.Count > 0 Then
                                                      dgQuoteDetails.SelectedIndex = dgQuoteDetails.Items.Count - 1
                                                      Dim newItem = dgQuoteDetails.Items(dgQuoteDetails.Items.Count - 1)

                                                      ' 1. Focus the cell (index 0 for Barcode column)
                                                      dgQuoteDetails.CurrentCell = New DataGridCellInfo(newItem, dgQuoteDetails.Columns(0))

                                                      ' 2. Scroll into view and update layout
                                                      dgQuoteDetails.ScrollIntoView(newItem, dgQuoteDetails.Columns(0))
                                                      dgQuoteDetails.UpdateLayout()

                                                      ' 3. Extract the physical row container
                                                      Dim rowContainer As DataGridRow = TryCast(dgQuoteDetails.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
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
                                                                      tb.SelectAll()
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
            If e.Key <> Key.Enter Then Return

            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing OrElse String.IsNullOrWhiteSpace(tb.Text) Then Return

            Dim searchText = tb.Text.Trim().ToLower()
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing Then Return

            ' البحث بالباركود أو اسم الصنف (جزئي)
            Dim matchedProduct = vm.Products.FirstOrDefault(
                Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                            (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)))

            If matchedProduct IsNot Nothing Then
                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                If cell IsNot Nothing Then
                    Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                    If row IsNot Nothing Then
                        Dim detail = TryCast(row.Item, QuoteDetail)
                        If detail IsNot Nothing Then
                            detail.ProductID = matchedProduct.ProductID
                            detail.Barcode = matchedProduct.Barcode
                            detail.ProductName = matchedProduct.ProductName
                            detail.UnitName = matchedProduct.UnitName
                            detail.QuotedPrice = matchedProduct.SalePrice

                            ' تحديث مصدر الـ Binding يدوياً (UpdateSourceTrigger=Explicit)
                            Dim barcodeBinding = tb.GetBindingExpression(TextBox.TextProperty)
                            If barcodeBinding IsNot Nothing Then barcodeBinding.UpdateSource()
                        End If
                    End If
                End If
                e.Handled = True
                ' الانتقال مباشرة لعمود السعر (index 3)
                MoveFocusToNextColumn(tb, 3)
            Else
                ' الصنف غير موجود: تمييز النص باللون الأحمر كتنبيه
                tb.Foreground = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Colors.Red)
                tb.SelectAll()
                e.Handled = True
                ' إعادة اللون الافتراضي بعد ثانية
                Dim timer As New DispatcherTimer With {.Interval = TimeSpan.FromSeconds(1)}
                AddHandler timer.Tick, Sub(s, ev)
                                           tb.Foreground = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(&H1E, &H29, &H3B))
                                           timer.Stop()
                                       End Sub
                timer.Start()
            End If
        End Sub

        Private Sub Price_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                ' Force the binding to commit
                Dim tb = TryCast(sender, TextBox)
                if tb IsNot Nothing Then
                    Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                    If binding IsNot Nothing Then binding.UpdateSource()
                End If

                e.Handled = True
                ' Add new row
                Dim vm = TryCast(Me.DataContext, QuoteViewModel)
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
                If capturedID.HasValue AndAlso Not String.IsNullOrEmpty(capturedName) Then
                    PartnerDropdown.SetDisplayText(capturedName)
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
