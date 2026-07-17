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
                If dgInvoiceDetails IsNot Nothing AndAlso dgInvoiceDetails.Items.Count > 0 Then
                    dgInvoiceDetails.SelectedIndex = dgInvoiceDetails.Items.Count - 1
                    Dim newItem = dgInvoiceDetails.Items(dgInvoiceDetails.Items.Count - 1)
                    
                    ' 1. Focus the cell (index 0 for Barcode column)
                    dgInvoiceDetails.CurrentCell = New DataGridCellInfo(newItem, dgInvoiceDetails.Columns(0))
                    
                    ' 2. Scroll into view and update layout
                    dgInvoiceDetails.ScrollIntoView(newItem, dgInvoiceDetails.Columns(0))
                    dgInvoiceDetails.UpdateLayout()
                    
                    ' 3. Extract the physical row container
                    Dim rowContainer As DataGridRow = TryCast(dgInvoiceDetails.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
                    If rowContainer IsNot Nothing Then
                        Dim presenter As System.Windows.Controls.Primitives.DataGridCellsPresenter = FindVisualChild(Of System.Windows.Controls.Primitives.DataGridCellsPresenter)(rowContainer)
                        If presenter IsNot Nothing Then
                            ' 4. Extract the physical cell container at column 0
                            Dim cell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(0), DataGridCell)
                            If cell IsNot Nothing Then
                                ' 5. Finally, grab the TextBox inside and forcefully focus it
                                Dim tb As TextBox = FindVisualChild(Of TextBox)(cell)
                                If tb IsNot Nothing Then
                                    Keyboard.Focus(tb)
                                Else
                                    cell.Focus()
                                End If
                            End If
                        End If
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        Private Sub NewInvoiceButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub AddItemButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub ProductComboBox_KeyUp(sender As Object, e As KeyEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsEditable Then Return

            ' Ignore navigation and selection keys
            If e.Key = Key.Up OrElse e.Key = Key.Down OrElse e.Key = Key.Enter OrElse e.Key = Key.Escape OrElse e.Key = Key.Tab Then
                Return
            End If

            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm Is Nothing OrElse vm.Products Is Nothing Then Return

            Dim view As System.ComponentModel.ICollectionView = cmb.Items
            If view Is Nothing Then Return

            Dim SearchText As String = tb.Text.Trim().ToLower()

            If String.IsNullOrWhiteSpace(SearchText) Then
                view.Filter = Nothing
                cmb.IsDropDownOpen = False
            Else
                view.Filter = Function(item)
                                  Dim p As Models.Product = TryCast(item, Models.Product)
                                  If p Is Nothing Then Return False
                                  ' Find by name LIKE or barcode exactly
                                  Return (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(SearchText)) OrElse
                                         (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(SearchText))
                              End Function
                
                cmb.IsDropDownOpen = True
                
                ' Keep the cursor at the end of the text
                tb.SelectionStart = tb.Text.Length
            End If
        End Sub

        Private Sub ProductComboBox_DropDownOpened(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing Then
                Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
                If tb IsNot Nothing Then
                     ' Keep focus in textbox when dropdown opens
                     tb.Focus()
                End If
            End If
        End Sub

        Private Sub ProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing Then
                ' Clear the filter immediately
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
            End If
        End Sub

        Private Sub ProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim cmb = TryCast(sender, ComboBox)
                If cmb IsNot Nothing AndAlso cmb.IsEditable Then
                    Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
                    If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                        Dim searchText = tb.Text.Trim().ToLower()
                        Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                        If vm IsNot Nothing Then
                            Dim matchedProduct = vm.Products.FirstOrDefault(Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)))
                            If matchedProduct IsNot Nothing Then
                                cmb.SelectedValue = matchedProduct.ProductID
                                ' Clear filter after selection on this specific combobox
                                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                                If view IsNot Nothing Then view.Filter = Nothing
                                e.Handled = True
                                cmb.IsDropDownOpen = False
                                
                                ' Move Focus to Quantity
                                MoveFocusToNextColumn(cmb, 1)
                            End If
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub Quantity_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                MoveFocusToNextColumn(TryCast(sender, TextBox), 1) ' Move to UnitPrice (next template column)
            End If
        End Sub

        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb As TextBox = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        Private Sub Price_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                ' تحديث قيمة الـ Binding أولاً
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                    If binding IsNot Nothing Then binding.UpdateSource()
                End If

                e.Handled = True

                ' الانتقال لعمود الإجمالي (العمود التالي رقم 4)
                MoveFocusToNextColumn(TryCast(sender, TextBox), 1)
            End If
        End Sub

        Private Sub Total_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True

                ' إضافة صف جديد
                Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                    vm.AddItemCommand.Execute(Nothing)
                End If

                ' الانتقال لخانة كود الصنف (Barcode) في الصف الجديد
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub Barcode_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                    If vm IsNot Nothing Then
                        Dim matchedProduct = vm.Products.FirstOrDefault(Function(p) p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText)
                        If matchedProduct IsNot Nothing Then
                            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                            If cell IsNot Nothing Then
                                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                If row IsNot Nothing Then
                                    Dim detail = TryCast(row.Item, Models.InvoiceDetail)
                                    If detail IsNot Nothing Then
                                        detail.ProductID = matchedProduct.ProductID
                                        detail.Barcode = matchedProduct.Barcode
                                    End If
                                End If
                            End If
                            e.Handled = True
                            
                            ' Move Focus to Quantity column (Skip Product Name ComboBox)
                            MoveFocusToNextColumn(tb, 2)
                        Else
                            tb.SelectAll()
                            e.Handled = True
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub ProductComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing AndAlso cmb.IsEditable Then
                Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
                If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                    If vm IsNot Nothing Then
                        Dim matchedProduct = vm.Products.FirstOrDefault(Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower() = searchText))
                        If matchedProduct IsNot Nothing Then
                            cmb.SelectedValue = matchedProduct.ProductID
                            ' Explicitly restore the display text so it stays visible after focus leaves
                            cmb.Text = matchedProduct.SearchText
                        Else
                            cmb.Text = ""
                        End If
                    End If
                ElseIf tb IsNot Nothing AndAlso String.IsNullOrWhiteSpace(tb.Text) Then
                    ' If text was cleared but a product was already selected, reshow its name
                    If cmb.SelectedItem IsNot Nothing Then
                        Dim selected = TryCast(cmb.SelectedItem, Models.Product)
                        If selected IsNot Nothing Then
                            cmb.Text = selected.SearchText
                        End If
                    End If
                End If
                
                ' Force the binding update since we set UpdateSourceTrigger=Explicit to prevent WPF from coercing the Barcode String to the Integer Property
                Dim binding = cmb.GetBindingExpression(ComboBox.SelectedValueProperty)
                If binding IsNot Nothing Then binding.UpdateSource()
            End If
        End Sub

        Private Sub ProductComboBox_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing AndAlso cmb.IsLoaded AndAlso cmb.SelectedValue IsNot Nothing Then
                If cmb.IsDropDownOpen OrElse cmb.IsFocused Then
                    Dim view As System.ComponentModel.ICollectionView = cmb.Items
                    If view IsNot Nothing Then view.Filter = Nothing
                    
                    Dispatcher.BeginInvoke(New Action(Sub()
                        MoveFocusToNextColumn(cmb, 1)
                    End Sub), System.Windows.Threading.DispatcherPriority.Input)
                End If
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

                    If nextColumnIndex < dg.Columns.Count Then
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
                                            Keyboard.Focus(tb)
                                            Dispatcher.BeginInvoke(New Action(Sub()
                                                tb.SelectAll()
                                            End Sub), System.Windows.Threading.DispatcherPriority.Input)
                                        Else
                                            Dim cmb As ComboBox = FindVisualChild(Of ComboBox)(nextCell)
                                            If cmb IsNot Nothing Then
                                                Keyboard.Focus(cmb)
                                            Else
                                                nextCell.Focus()
                                            End If
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
