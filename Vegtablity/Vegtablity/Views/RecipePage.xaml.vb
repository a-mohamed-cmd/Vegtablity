Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media.Animation
Imports Vegtablity.ViewModels
Imports Vegtablity.Models
Imports Vegtablity.Controls

Namespace Views
    Public Class RecipePage
        Inherits UserControl

        Private _isSidebarVisible As Boolean = True

        Public Sub New()
            InitializeComponent()
            ' Subscribe to ViewModel events after DataContext is set
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm Is Nothing Then Return
            AddHandler vm.RecipeLoaded, AddressOf OnRecipeLoaded
            AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
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

        ''' <summary>Sync SearchableDropdown text when a recipe is loaded from sidebar</summary>
        Private Sub OnRecipeLoaded(sender As Object, e As (productID As Integer, productName As String))
            Dispatcher.BeginInvoke(New Action(Sub()
                If Not String.IsNullOrEmpty(e.productName) Then
                    ProductTargetDropdown.SetDisplayText(e.productName)
                Else
                    ProductTargetDropdown.ClearSelection()
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

        ' ── 📄 Export PDF & 📊 Export Excel ──────────────────────────────────
        Private Sub BtnExportPdf_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm Is Nothing OrElse vm.SelectedTargetProduct Is Nothing Then
                MessageBox.Show("يرجى اختيار صنف لعرض وصفته قبل التصدير", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                Dim recipeSvc As New Services.RecipeService()
                ' استدعاء نفس sp (sp_Recipe_GetByProduct) لجلب البيانات الكاملة للصنف ومكوناته
                Dim recipeData = recipeSvc.GetRecipeByProduct(vm.SelectedTargetProduct.ProductID, vm.SelectedWarehouseID)

                If recipeData Is Nothing OrElse recipeData.Details Is Nothing OrElse recipeData.Details.Count = 0 Then
                    ' إن كانت الوصفة قيد الإدخال قبل الحفظ أو لم تُرَجّع تفاصيل
                    recipeData = New Recipe With {
                        .ProductID = vm.SelectedTargetProduct.ProductID,
                        .ProductName = vm.SelectedTargetProduct.ProductName,
                        .Notes = vm.Notes,
                        .TotalCost = vm.TotalRecipeCost,
                        .Details = vm.CurrentRecipeDetails.ToList()
                    }
                End If

                ' استكمال أسماء المواد والباركودات من قائمة RawMaterialProducts إن وُجدت أي خلية فارغة
                If recipeData.Details IsNot Nothing Then
                    For Each d In recipeData.Details
                        If String.IsNullOrWhiteSpace(d.IngredientName) OrElse String.IsNullOrWhiteSpace(d.IngredientBarcode) Then
                            Dim p = vm.RawMaterialProducts.FirstOrDefault(Function(item) item.ProductID = d.IngredientProductID)
                            If p IsNot Nothing Then
                                If String.IsNullOrWhiteSpace(d.IngredientName) Then d.IngredientName = p.ProductName
                                If String.IsNullOrWhiteSpace(d.IngredientBarcode) Then d.IngredientBarcode = p.Barcode
                                If String.IsNullOrWhiteSpace(d.UnitName) Then d.UnitName = p.UnitName
                            End If
                        End If
                    Next
                End If

                Dim whName As String = ""
                If vm.SelectedWarehouseID.HasValue AndAlso vm.Warehouses IsNot Nothing Then
                    Dim wh = vm.Warehouses.FirstOrDefault(Function(w) w.WarehouseID = vm.SelectedWarehouseID.Value)
                    If wh IsNot Nothing Then whName = wh.WarehouseName
                End If

                Helpers.ReportExporter.ExportRecipeToPdf(recipeData, whName)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير الوصفة إلى PDF: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub BtnExportExcel_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm Is Nothing OrElse vm.SelectedTargetProduct Is Nothing Then
                MessageBox.Show("يرجى اختيار صنف لعرض وصفته قبل التصدير", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                Dim recipeSvc As New Services.RecipeService()
                Dim recipeData = recipeSvc.GetRecipeByProduct(vm.SelectedTargetProduct.ProductID, vm.SelectedWarehouseID)

                If recipeData Is Nothing OrElse recipeData.Details Is Nothing OrElse recipeData.Details.Count = 0 Then
                    recipeData = New Recipe With {
                        .ProductID = vm.SelectedTargetProduct.ProductID,
                        .ProductName = vm.SelectedTargetProduct.ProductName,
                        .Notes = vm.Notes,
                        .TotalCost = vm.TotalRecipeCost,
                        .Details = vm.CurrentRecipeDetails.ToList()
                    }
                End If

                If recipeData.Details IsNot Nothing Then
                    For Each d In recipeData.Details
                        If String.IsNullOrWhiteSpace(d.IngredientName) OrElse String.IsNullOrWhiteSpace(d.IngredientBarcode) Then
                            Dim p = vm.RawMaterialProducts.FirstOrDefault(Function(item) item.ProductID = d.IngredientProductID)
                            If p IsNot Nothing Then
                                If String.IsNullOrWhiteSpace(d.IngredientName) Then d.IngredientName = p.ProductName
                                If String.IsNullOrWhiteSpace(d.IngredientBarcode) Then d.IngredientBarcode = p.Barcode
                                If String.IsNullOrWhiteSpace(d.UnitName) Then d.UnitName = p.UnitName
                            End If
                        End If
                    Next
                End If

                Dim whName As String = ""
                If vm.SelectedWarehouseID.HasValue AndAlso vm.Warehouses IsNot Nothing Then
                    Dim wh = vm.Warehouses.FirstOrDefault(Function(w) w.WarehouseID = vm.SelectedWarehouseID.Value)
                    If wh IsNot Nothing Then whName = wh.WarehouseName
                End If

                Helpers.ReportExporter.ExportRecipeToCsv(recipeData, whName)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير الوصفة إلى Excel: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ── ☰ Hamburger: toggle recipe list sidebar ───────────────────────────
        Private Sub BtnToggleSidebar_Click(sender As Object, e As RoutedEventArgs)
            _isSidebarVisible = Not _isSidebarVisible

            Dim targetWidth As Double = If(_isSidebarVisible, 340, 0)
            Dim anim As New DoubleAnimation() With {
                .To = targetWidth,
                .Duration = New Duration(TimeSpan.FromMilliseconds(250)),
                .EasingFunction = New CubicEase() With {.EasingMode = If(_isSidebarVisible, EasingMode.EaseOut, EasingMode.EaseIn)}
            }
            SidebarBorder.BeginAnimation(Border.MaxWidthProperty, anim)

            ' Update tooltip
            BtnToggleSidebar.ToolTip = If(_isSidebarVisible, "إخفاء قائمة الوصفات", "إظهار قائمة الوصفات")
        End Sub

        ' ── SearchableDropdown: Target Product search & selection ─────────────
        Private Sub ProductTargetDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing Then
                vm.ApplyManufacturedFilter(e)
                ProductTargetDropdown.OpenDropdown()
            End If
        End Sub

        Private Sub ProductTargetDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Product)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing Then
                vm.SelectedTargetProduct = selected
            End If
        End Sub

        ' ── Helper: Focus col 0 (Barcode) of last row ───────────────────────
        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If dgRecipeDetails IsNot Nothing AndAlso dgRecipeDetails.Items.Count > 0 Then
                    Dim lastItem = dgRecipeDetails.Items(dgRecipeDetails.Items.Count - 1)
                    dgRecipeDetails.SelectedIndex = dgRecipeDetails.Items.Count - 1
                    dgRecipeDetails.CurrentCell = New DataGridCellInfo(lastItem, dgRecipeDetails.Columns(0))
                    dgRecipeDetails.ScrollIntoView(lastItem, dgRecipeDetails.Columns(0))
                    dgRecipeDetails.UpdateLayout()

                    Dim rowContainer As DataGridRow = TryCast(dgRecipeDetails.ItemContainerGenerator.ContainerFromItem(lastItem), DataGridRow)
                    If rowContainer IsNot Nothing Then
                        Dim presenter As System.Windows.Controls.Primitives.DataGridCellsPresenter =
                            FindVisualChild(Of System.Windows.Controls.Primitives.DataGridCellsPresenter)(rowContainer)
                        If presenter IsNot Nothing Then
                            Dim cell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(0), DataGridCell)
                            If cell IsNot Nothing Then
                                Dim tb As TextBox = FindVisualChild(Of TextBox)(cell)
                                If tb IsNot Nothing Then Keyboard.Focus(tb) Else cell.Focus()
                            End If
                        End If
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        ' ── Col 0: Barcode TextBox — Enter searches by exact barcode & moves to Qty ──
        Private Sub RecipeBarcode_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key <> Key.Enter Then Return
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            If Not String.IsNullOrWhiteSpace(tb.Text) Then
                Dim searchText = tb.Text.Trim().ToLower()
                Dim vm = TryCast(Me.DataContext, RecipeViewModel)
                If vm IsNot Nothing Then
                    Dim matched = vm.RawMaterialProducts.FirstOrDefault(
                        Function(p) p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText)

                    If matched IsNot Nothing Then
                        Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                        If cell IsNot Nothing Then
                            Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                            If row IsNot Nothing Then
                                Dim detail = TryCast(row.Item, RecipeDetail)
                                If detail IsNot Nothing Then
                                    detail.IngredientProductID = matched.ProductID
                                    detail.IngredientBarcode = matched.Barcode
                                    detail.IngredientName = matched.ProductName
                                    detail.UnitName = matched.UnitName
                                    detail.UnitCost = matched.PurchasePrice
                                    detail.LineCost = detail.UnitCost * detail.Qty
                                    vm.CalculateTotalCost()
                                End If
                            End If
                        End If
                        e.Handled = True
                        MoveFocusToNextColumn(tb, 3) ' Col 0 (Barcode) → Col 3 (Qty)
                        Return
                    End If
                End If
            End If

            ' الصنف غير موجود أو الباركود غير صحيح → إلغاء الانتقال وتحديد النص لتصحيحه
            tb.SelectAll()
            e.Handled = True
        End Sub

        ' ── Col 1: ComboBox — KeyUp live search filter ───────────────────────
        Private Sub RecipeProductComboBox_KeyUp(sender As Object, e As KeyEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsEditable Then Return
            If e.Key = Key.Up OrElse e.Key = Key.Down OrElse e.Key = Key.Enter OrElse
               e.Key = Key.Escape OrElse e.Key = Key.Tab Then Return

            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb Is Nothing Then Return

            Dim view As System.ComponentModel.ICollectionView = cmb.Items
            If view Is Nothing Then Return

            Dim searchText As String = tb.Text.Trim().ToLower()
            If String.IsNullOrWhiteSpace(searchText) Then
                view.Filter = Nothing
                cmb.IsDropDownOpen = False
            Else
                view.Filter = Function(item)
                    Dim p As Product = TryCast(item, Product)
                    If p Is Nothing Then Return False
                    Return (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)) OrElse
                           (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(searchText))
                End Function
                cmb.IsDropDownOpen = True
                tb.SelectionStart = tb.Text.Length
            End If
        End Sub

        ' ── Col 1: ComboBox — DropDownOpened: keep focus in textbox ─────────
        Private Sub RecipeProductComboBox_DropDownOpened(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing Then Return
            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb IsNot Nothing Then tb.Focus()
        End Sub

        ' ── Col 1: ComboBox — DropDownClosed: clear filter ──────────────────
        Private Sub RecipeProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing Then Return
            Dim view As System.ComponentModel.ICollectionView = cmb.Items
            If view IsNot Nothing Then view.Filter = Nothing
        End Sub

        ' ── Col 1: ComboBox — Enter: match and move to Qty ──────────────────
        Private Sub RecipeProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key <> Key.Enter Then Return
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsEditable Then Return

            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb Is Nothing OrElse String.IsNullOrWhiteSpace(tb.Text) Then Return

            Dim searchText = tb.Text.Trim().ToLower()
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm Is Nothing Then Return

            Dim matched = vm.RawMaterialProducts.FirstOrDefault(
                Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                            (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(searchText)))
            If matched IsNot Nothing Then
                cmb.SelectedValue = matched.ProductID
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
                e.Handled = True
                cmb.IsDropDownOpen = False
                vm.CalculateTotalCost()
                MoveFocusToNextColumn(cmb, 2) ' ComboBox col 1 → Qty col 3
            End If
        End Sub

        ' ── Col 1: ComboBox — LostFocus: restore or clear display text ───────
        Private Sub RecipeProductComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsEditable Then Return

            Dim tb As TextBox = TryCast(cmb.Template.FindName("PART_EditableTextBox", cmb), TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm Is Nothing Then Return

            If Not String.IsNullOrWhiteSpace(tb.Text) Then
                Dim searchText = tb.Text.Trim().ToLower()
                Dim matched = vm.RawMaterialProducts.FirstOrDefault(
                    Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                                (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower() = searchText))
                If matched IsNot Nothing Then
                    cmb.SelectedValue = matched.ProductID
                    cmb.Text = matched.ProductName
                Else
                    cmb.Text = ""
                End If
            ElseIf cmb.SelectedItem IsNot Nothing Then
                Dim sel = TryCast(cmb.SelectedItem, Product)
                If sel IsNot Nothing Then cmb.Text = sel.ProductName
            End If

            Dim binding = cmb.GetBindingExpression(ComboBox.SelectedValueProperty)
            If binding IsNot Nothing Then binding.UpdateSource()
        End Sub

        ' ── Col 1: ComboBox — SelectionChanged: update detail + move to Qty ─
        Private Sub RecipeProductComboBox_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing OrElse Not cmb.IsLoaded OrElse cmb.SelectedValue Is Nothing Then Return

            ' Update the bound RecipeDetail row
            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
            If cell IsNot Nothing Then
                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                If row IsNot Nothing Then
                    Dim detail = TryCast(row.Item, RecipeDetail)
                    Dim sel = TryCast(cmb.SelectedItem, Product)
                    If detail IsNot Nothing AndAlso sel IsNot Nothing Then
                        detail.IngredientProductID = sel.ProductID
                        detail.IngredientBarcode = sel.Barcode
                        detail.IngredientName = sel.ProductName
                        detail.UnitName = sel.UnitName
                        detail.UnitCost = sel.PurchasePrice
                        detail.LineCost = detail.UnitCost * detail.Qty
                        Dim vm = TryCast(Me.DataContext, RecipeViewModel)
                        If vm IsNot Nothing Then vm.CalculateTotalCost()
                    End If
                End If
            End If

            If cmb.IsDropDownOpen OrElse cmb.IsFocused Then
                Dim view As System.ComponentModel.ICollectionView = cmb.Items
                If view IsNot Nothing Then view.Filter = Nothing
                Dispatcher.BeginInvoke(New Action(Sub()
                    MoveFocusToNextColumn(cmb, 2) ' col 1 → col 3 (Qty)
                End Sub), System.Windows.Threading.DispatcherPriority.Input)
            End If
        End Sub

        ' ── Col 3: Qty TextBox — Enter: commit and add new row ───────────────
        Private Sub RecipeQty_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key <> Key.Enter Then Return
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()
            End If
            e.Handled = True
            ' Notify VM to recalculate totals then add a new empty row
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing AndAlso vm.AddIngredientCommand.CanExecute(Nothing) Then
                vm.AddIngredientCommand.Execute(Nothing)
            End If
            FocusLastRowBarcode()
        End Sub

        ' ── Shared: SelectAll on focus ────────────────────────────────────────
        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb As TextBox = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        ' ── MoveFocusToNextColumn (same as PurchaseInvoicePage) ──────────────
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
                If rowContainer Is Nothing Then Return
                Dim presenter As System.Windows.Controls.Primitives.DataGridCellsPresenter =
                    FindVisualChild(Of System.Windows.Controls.Primitives.DataGridCellsPresenter)(rowContainer)
                If presenter Is Nothing Then Return
                Dim nextCell As DataGridCell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(nextColumnIndex), DataGridCell)
                If nextCell Is Nothing Then Return
                nextCell.Focus()
                Dim tb As TextBox = FindVisualChild(Of TextBox)(nextCell)
                If tb IsNot Nothing Then
                    Keyboard.Focus(tb)
                    Dispatcher.BeginInvoke(New Action(Sub() tb.SelectAll()),
                        System.Windows.Threading.DispatcherPriority.Input)
                Else
                    Dim cmb As ComboBox = FindVisualChild(Of ComboBox)(nextCell)
                    If cmb IsNot Nothing Then Keyboard.Focus(cmb) Else nextCell.Focus()
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        ' ── Visual Tree helpers ───────────────────────────────────────────────
        Private Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            For i As Integer = 0 To System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i)
                If child IsNot Nothing AndAlso TypeOf child Is T Then Return DirectCast(child, T)
                Dim childOfChild As T = FindVisualChild(Of T)(child)
                If childOfChild IsNot Nothing Then Return childOfChild
            Next
            Return Nothing
        End Function

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then Return parent
            Return FindVisualParent(Of T)(parentObject)
        End Function

    End Class
End Namespace
