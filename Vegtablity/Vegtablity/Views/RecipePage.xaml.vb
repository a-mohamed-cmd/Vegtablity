Imports System.Windows
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
        Private _isFilterVisible As Boolean = True

        Public Sub New()
            InitializeComponent()
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

        ' ── ☰ Hamburger: toggle recipe list sidebar with smooth animation ─────
        Private Sub BtnToggleSidebar_Click(sender As Object, e As RoutedEventArgs)
            _isSidebarVisible = Not _isSidebarVisible

            Dim targetWidth As Double = If(_isSidebarVisible, 350, 0)
            Dim widthAnim As New DoubleAnimation() With {
                .To = targetWidth,
                .Duration = New Duration(TimeSpan.FromMilliseconds(300)),
                .EasingFunction = New CubicEase() With {.EasingMode = If(_isSidebarVisible, EasingMode.EaseOut, EasingMode.EaseIn)}
            }
            SidebarBorder.BeginAnimation(Border.MaxWidthProperty, widthAnim)

            Dim opacityAnim As New DoubleAnimation() With {
                .To = If(_isSidebarVisible, 1.0, 0.0),
                .Duration = New Duration(TimeSpan.FromMilliseconds(250)),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseInOut}
            }
            SidebarBorder.BeginAnimation(UIElement.OpacityProperty, opacityAnim)

            BtnToggleSidebar.ToolTip = If(_isSidebarVisible, "إخفاء قائمة الوصفات", "إظهار قائمة الوصفات")
        End Sub

        ' ── 🔍 Toggle collapsible filter box in sidebar with animation ───────
        Private Sub BtnToggleFilter_Click(sender As Object, e As RoutedEventArgs)
            _isFilterVisible = Not _isFilterVisible

            If _isFilterVisible Then
                FilterCardBorder.Visibility = Visibility.Visible
                Dim fadeIn As New DoubleAnimation() With {
                    .From = 0.0,
                    .To = 1.0,
                    .Duration = New Duration(TimeSpan.FromMilliseconds(200)),
                    .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
                }
                FilterCardBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)
                BtnToggleFilter.Content = "🔍 تصفية ▼"
            Else
                Dim fadeOut As New DoubleAnimation() With {
                    .From = 1.0,
                    .To = 0.0,
                    .Duration = New Duration(TimeSpan.FromMilliseconds(150)),
                    .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseIn}
                }
                AddHandler fadeOut.Completed, Sub(s, ev)
                                                  FilterCardBorder.Visibility = Visibility.Collapsed
                                              End Sub
                FilterCardBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
                BtnToggleFilter.Content = "🔍 تصفية ◀"
            End If
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

        ' ── Add Row & Focus Handlers ──────────────────────────────────────────
        Private Sub AddRowButton_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                    Dim lastIndex = DetailsItemsControl.Items.Count - 1
                    Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                    If container IsNot Nothing Then
                        Dim rowCtrl = FindVisualChild(Of Controls.RecipeItemRowControl)(container)
                        If rowCtrl IsNot Nothing Then
                            rowCtrl.FocusBarcode()
                        End If
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Background)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  RecipeItemRowControl Event Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub RecipeItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing AndAlso vm.AddIngredientCommand.CanExecute(Nothing) Then
                vm.AddIngredientCommand.Execute(Nothing)
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub RecipeItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.RecipeItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.RecipeDetail)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing Then
                vm.RemoveIngredientCommand.Execute(detail)
            End If
        End Sub

        Private Sub RecipeItemRow_AmountChanged(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, RecipeViewModel)
            If vm IsNot Nothing Then
                vm.CalculateTotalCost()
            End If
        End Sub

        ' ── Visual Tree helpers ───────────────────────────────────────────────
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

    End Class
End Namespace
