Imports System.Windows.Input
Imports System.Windows.Controls
Imports System.Linq
Imports Vegtablity.ViewModels

Namespace Views
    Public Class SalesInvoicePage
        Public Sub New()
            InitializeComponent()
            ' Subscribe to ViewModel's Snackbar event
            Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
            End If
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
            If cmb IsNot Nothing AndAlso cmb.SelectedValue IsNot Nothing Then
                ' A valid selection was made (often by mouse click)
                ' Clear the filter immediately
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
                
                ' Give priority to the view update, then jump to Quantity column
                Dispatcher.BeginInvoke(New Action(Sub()
                     MoveFocusToNextColumn(cmb, 1)
                End Sub), System.Windows.Threading.DispatcherPriority.Input)
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
                e.Handled = True
                
                ' Add new row and focus on its product combobox
                Dim vm = TryCast(Me.DataContext, SalesInvoiceViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                    ' Trigger Add Item Command
                    vm.AddItemCommand.Execute(Nothing)
                End If
                
                ' Since a new row is added at the end, moving focus needs dispatcher to allow UI to render first
                Dispatcher.BeginInvoke(New Action(Sub()
                    Dim dg As DataGrid = FindVisualParent(Of DataGrid)(TryCast(sender, UIElement))
                    If dg IsNot Nothing AndAlso dg.Items.Count > 0 Then
                        dg.SelectedIndex = dg.Items.Count - 1
                        Dim newItem = dg.Items(dg.Items.Count - 1)
                        
                        ' 1. Focus the cell (index 0 for Barcode column)
                        dg.CurrentCell = New DataGridCellInfo(newItem, dg.Columns(0))
                        
                        ' 2. Scroll into view and update layout
                        dg.ScrollIntoView(newItem, dg.Columns(0))
                        dg.UpdateLayout()
                        
                        ' 3. Extract the physical row container
                        Dim rowContainer As DataGridRow = TryCast(dg.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
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
    End Class
End Namespace
