Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Threading
Imports System.Windows.Controls.Primitives

Namespace Views
    Public Class WastagePage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        ' =====================================================
        ' Snackbar
        ' =====================================================
        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = System.Windows.Visibility.Visible
            Dim timer As New DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(s, e)
                                       SnackbarBorder.Visibility = System.Windows.Visibility.Collapsed
                                       DirectCast(s, DispatcherTimer).Stop()
                                   End Sub
            timer.Start()
        End Sub

        Private Sub btnToggleHistory_Click(sender As Object, e As RoutedEventArgs)
            If HistoryCard.Visibility = Visibility.Visible Then
                HistoryCard.Visibility = Visibility.Collapsed
            Else
                HistoryCard.Visibility = Visibility.Visible
            End If
        End Sub

        ' =====================================================
        ' TextBox Helpers
        ' =====================================================
        Private Sub TextBox_Loaded(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.Focus()
                tb.SelectAll()
            End If
        End Sub

        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        ' =====================================================
        ' Focus Last Row Barcode  (same as SalesInvoicePage)
        ' =====================================================
        Private Sub FocusLastRowBarcode()
            ' المرحلة الأولى: انتظر DataBind (بعد إضافة الصف للـ Collection)
            Dispatcher.BeginInvoke(New Action(Sub()
                ' المرحلة الثانية: انتظر Render (بعد رسم الصف في الجدول)
                Dispatcher.BeginInvoke(New Action(Sub()
                    If dgDetails Is Nothing OrElse dgDetails.Items.Count = 0 Then Return

                    Dim lastIdx = dgDetails.Items.Count - 1
                    Dim newItem = dgDetails.Items(lastIdx)

                    dgDetails.SelectedIndex = lastIdx
                    dgDetails.CurrentCell = New DataGridCellInfo(newItem, dgDetails.Columns(0))
                    dgDetails.ScrollIntoView(newItem, dgDetails.Columns(0))
                    dgDetails.UpdateLayout()

                    Dim rowContainer As DataGridRow = TryCast(dgDetails.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
                    If rowContainer IsNot Nothing Then
                        Dim presenter As DataGridCellsPresenter = FindVisualChild(Of DataGridCellsPresenter)(rowContainer)
                        If presenter IsNot Nothing Then
                            Dim cell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(0), DataGridCell)
                            If cell IsNot Nothing Then
                                cell.Focus()
                                dgDetails.BeginEdit()
                                Dim tb As TextBox = FindVisualChild(Of TextBox)(cell)
                                If tb IsNot Nothing Then
                                    Keyboard.Focus(tb)
                                    tb.SelectAll()
                                End If
                            End If
                        End If
                    End If
                End Sub), DispatcherPriority.Input)
            End Sub), DispatcherPriority.DataBind)
        End Sub



        Private Sub BtnAddItem_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If vm IsNot Nothing Then
                vm.AddItem()
            End If
            FocusLastRowBarcode()
        End Sub

        ' =====================================================
        ' Barcode / ProductCode Column
        ' =====================================================
        Private Sub Barcode_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb Is Nothing Then Return
                e.Handled = True

                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()

                If Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
                    If vm IsNot Nothing AndAlso vm.AvailableProducts IsNot Nothing Then
                        Dim matched = vm.AvailableProducts.FirstOrDefault(
                            Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                                        p.ProductID.ToString() = searchText)
                        If matched IsNot Nothing Then
                            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                            If cell IsNot Nothing Then
                                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                If row IsNot Nothing Then
                                    Dim detail = TryCast(row.Item, Models.WastageDetails)
                                    If detail IsNot Nothing Then
                                        vm.AttachDetailHandler(detail)
                                        detail.ProductID = matched.ProductID
                                        detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                                    End If
                                End If
                            End If
                            MoveFocusToNextColumn(tb, 2) ' Skip ComboBox → Jump to Quantity
                            Return
                        End If
                    End If
                End If

                ' Empty or not found → stay in barcode cell (do nothing / optionally move to ComboBox)
                ' MoveFocusToNextColumn(tb, 1)  ' uncomment to jump to ComboBox on not-found
            End If
        End Sub

        ' =====================================================
        ' Product ComboBox Column
        ' =====================================================
        Private Sub ProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim cmb = TryCast(sender, ComboBox)
                If cmb IsNot Nothing AndAlso cmb.SelectedValue IsNot Nothing Then
                    MoveFocusToNextColumn(cmb, 1) ' Jump to Quantity
                End If
            End If
        End Sub

        Private Sub ProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse cmb.SelectedValue Is Nothing Then Return

            ' تحميل كود الصنف في خانة "كود الصنف" للصف نفسه
            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If vm IsNot Nothing AndAlso vm.AvailableProducts IsNot Nothing Then
                Dim selectedID = CInt(cmb.SelectedValue)
                Dim matchedProduct = vm.AvailableProducts.FirstOrDefault(Function(p) p.ProductID = selectedID)
                If matchedProduct IsNot Nothing Then
                    Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                    If cell IsNot Nothing Then
                        Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                        If row IsNot Nothing Then
                            Dim detail = TryCast(row.Item, Models.WastageDetails)
                            If detail IsNot Nothing Then
                                vm.AttachDetailHandler(detail)
                                detail.ProductCode = If(Not String.IsNullOrEmpty(matchedProduct.Barcode),
                                                        matchedProduct.Barcode,
                                                        matchedProduct.ProductID.ToString())
                            End If
                        End If
                    End If
                End If
            End If

            ' الانتقال إلى خانة الكمية
            Dispatcher.BeginInvoke(New Action(Sub()
                MoveFocusToNextColumn(cmb, 1)
            End Sub), DispatcherPriority.Input)
        End Sub

        ' =====================================================
        ' Quantity Column — Enter → add new row and focus barcode
        ' =====================================================
        Private Sub Quantity_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb Is Nothing Then Return
                e.Handled = True

                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()

                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                If cell Is Nothing Then Return
                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                Dim dg As DataGrid = FindVisualParent(Of DataGrid)(row)
                If row Is Nothing OrElse dg Is Nothing Then Return

                dg.CommitEdit(DataGridEditingUnit.Row, True)

                ' Add new row via ViewModel then focus its barcode
                Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
                If vm IsNot Nothing Then
                    vm.AddItem()
                End If
                FocusLastRowBarcode()
            End If
        End Sub

        ' =====================================================
        ' Delete Row Button
        ' =====================================================
        Private Sub BtnDeleteRow_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If vm Is Nothing OrElse vm.CurrentWastage Is Nothing OrElse vm.CurrentWastage.Details Is Nothing Then Return

            ' Try DataContext → Tag → Visual Tree
            Dim item = TryCast(btn.DataContext, Models.WastageDetails)
            If item Is Nothing Then item = TryCast(btn.Tag, Models.WastageDetails)
            If item Is Nothing Then
                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(btn)
                If row IsNot Nothing Then item = TryCast(row.Item, Models.WastageDetails)
            End If

            If item IsNot Nothing Then
                vm.CurrentWastage.Details.Remove(item)
                vm.CurrentWastage.TotalValue = vm.CurrentWastage.Details.Sum(Function(d) d.TotalCost)
            End If
        End Sub

        ' =====================================================
        ' DataGrid Events
        ' =====================================================
        Private Sub dgDetails_InitializingNewItem(sender As Object, e As InitializingNewItemEventArgs)
            Dim item = TryCast(e.NewItem, Models.WastageDetails)
            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.AttachDetailHandler(item)
            End If
        End Sub

        ' =====================================================
        ' Selected Wastage Grid Handlers
        ' =====================================================

        Private Sub BtnAddItemSelected_Click(sender As Object, e As RoutedEventArgs)
            ' النموذج موحّد - استخدام نفس دالة الإضافة الرئيسية
            BtnAddItem_Click(sender, e)
        End Sub

        Private Sub BtnDeleteSelectedRow_Click(sender As Object, e As RoutedEventArgs)
            ' النموذج موحّد - استخدام نفس دالة الحذف الرئيسية
            BtnDeleteRow_Click(sender, e)
        End Sub

        Private Sub BarcodeSelected_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb Is Nothing Then Return
                e.Handled = True
                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()

                If Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
                    If vm IsNot Nothing AndAlso vm.AvailableProducts IsNot Nothing Then
                        Dim matched = vm.AvailableProducts.FirstOrDefault(
                            Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                                        p.ProductID.ToString() = searchText)
                        If matched IsNot Nothing Then
                            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                            If cell IsNot Nothing Then
                                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                If row IsNot Nothing Then
                                    Dim detail = TryCast(row.Item, Models.WastageDetails)
                                    If detail IsNot Nothing Then
                                        vm.AttachDetailHandler(detail)
                                        detail.ProductID = matched.ProductID
                                        detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                                    End If
                                End If
                            End If
                            MoveFocusToNextColumn(tb, 2)
                            Return
                        End If
                    End If
                End If
            End If
        End Sub

        Private Sub ProductComboBoxSelected_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim cmb = TryCast(sender, ComboBox)
                If cmb IsNot Nothing AndAlso cmb.SelectedValue IsNot Nothing Then
                    MoveFocusToNextColumn(cmb, 1)
                End If
            End If
        End Sub

        Private Sub ProductComboBoxSelected_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse cmb.SelectedValue Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.WastageViewModel)
            If vm IsNot Nothing AndAlso vm.AvailableProducts IsNot Nothing Then
                Dim selectedID = CInt(cmb.SelectedValue)
                Dim matched = vm.AvailableProducts.FirstOrDefault(Function(p) p.ProductID = selectedID)
                If matched IsNot Nothing Then
                    Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                    If cell IsNot Nothing Then
                        Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                        If row IsNot Nothing Then
                            Dim detail = TryCast(row.Item, Models.WastageDetails)
                            If detail IsNot Nothing Then
                                vm.AttachDetailHandler(detail)
                                detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                            End If
                        End If
                    End If
                End If
            End If
            Dispatcher.BeginInvoke(New Action(Sub()
                MoveFocusToNextColumn(cmb, 1)
            End Sub), DispatcherPriority.Input)
        End Sub

        Private Sub QuantitySelected_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb Is Nothing Then Return
                e.Handled = True
                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()
                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                If cell Is Nothing Then Return
                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                Dim dg As DataGrid = FindVisualParent(Of DataGrid)(row)
                If row Is Nothing OrElse dg Is Nothing Then Return
                dg.CommitEdit(DataGridEditingUnit.Row, True)
                ' أضف صفاً جديداً
                BtnAddItemSelected_Click(Nothing, Nothing)
            End If
        End Sub

        ' =====================================================
        ' Navigation Helpers
        ' =====================================================
        Private Sub MoveFocusToNextColumn(currentControl As UIElement, columnOffset As Integer)
            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(currentControl)
            If cell Is Nothing Then Return
            Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
            Dim dg As DataGrid = FindVisualParent(Of DataGrid)(row)
            If row Is Nothing OrElse dg Is Nothing Then Return

            Dim currentColumnIndex = dg.Columns.IndexOf(cell.Column)
            Dim nextColumnIndex = currentColumnIndex + columnOffset
            If nextColumnIndex >= dg.Columns.Count Then Return

            dg.CurrentCell = New DataGridCellInfo(row.Item, dg.Columns(nextColumnIndex))

            Dispatcher.BeginInvoke(New Action(Sub()
                dg.UpdateLayout()
                dg.ScrollIntoView(row.Item, dg.Columns(nextColumnIndex))
                Dim rowContainer As DataGridRow = TryCast(dg.ItemContainerGenerator.ContainerFromItem(row.Item), DataGridRow)
                If rowContainer IsNot Nothing Then
                    Dim presenter As DataGridCellsPresenter = FindVisualChild(Of DataGridCellsPresenter)(rowContainer)
                    If presenter IsNot Nothing Then
                        Dim nextCell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(nextColumnIndex), DataGridCell)
                        If nextCell IsNot Nothing Then
                            nextCell.Focus()
                            dg.BeginEdit()
                        End If
                    End If
                End If
            End Sub), DispatcherPriority.Input)
        End Sub

        Private Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            For i As Integer = 0 To System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i)
                If child IsNot Nothing AndAlso TypeOf child Is T Then
                    Return DirectCast(child, T)
                Else
                    Dim childOfChild As T = FindVisualChild(Of T)(child)
                    If childOfChild IsNot Nothing Then Return childOfChild
                End If
            Next
            Return Nothing
        End Function

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = System.Windows.Media.VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then Return parent
            Return FindVisualParent(Of T)(parentObject)
        End Function

    End Class
End Namespace
