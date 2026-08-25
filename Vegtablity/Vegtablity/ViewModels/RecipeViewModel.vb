Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace ViewModels
    Public Class RecipeViewModel
        Inherits BaseViewModel

        Private ReadOnly _recipeService As RecipeService
        Private ReadOnly _productService As ProductService
        Private ReadOnly _warehouseService As Services.WarehouseService

        Private _suppressTargetFilter As Boolean = False
        Private _suppressIngredientFilter As Boolean = False

        Public Property Warehouses As ObservableCollection(Of Warehouse)

        Private _selectedWarehouseID As Integer?
        Public Property SelectedWarehouseID As Integer?
            Get
                Return _selectedWarehouseID
            End Get
            Set(value As Integer?)
                If SetProperty(_selectedWarehouseID, value) Then
                    LoadRawMaterialProductsForSelectedWarehouse()
                    If SelectedTargetProduct IsNot Nothing Then
                        LoadRecipeDetails(SelectedTargetProduct.ProductID)
                    End If
                End If
            End Set
        End Property

        Public Property Recipes As ObservableCollection(Of Recipe)
        Public Property FilteredRecipes As ObservableCollection(Of Recipe)
        Public Property ManufacturedProducts As ObservableCollection(Of Product)
        Public Property RawMaterialProducts As ObservableCollection(Of Product)
        Public Property FilteredManufacturedProducts As ObservableCollection(Of Product)
        Public Property FilteredRawMaterialProducts As ObservableCollection(Of Product)
        Public Property CurrentRecipeDetails As ObservableCollection(Of RecipeDetail)

        Private _recipeSearchBarcode As String = ""
        Public Property RecipeSearchBarcode As String
            Get
                Return _recipeSearchBarcode
            End Get
            Set(value As String)
                If SetProperty(_recipeSearchBarcode, value) Then
                    FilterRecipes()
                End If
            End Set
        End Property

        Private _recipeSearchName As String = ""
        Public Property RecipeSearchName As String
            Get
                Return _recipeSearchName
            End Get
            Set(value As String)
                If SetProperty(_recipeSearchName, value) Then
                    FilterRecipes()
                End If
            End Set
        End Property

        Private _targetSearchText As String = ""
        Public Property TargetSearchText As String
            Get
                Return _targetSearchText
            End Get
            Set(value As String)
                If SetProperty(_targetSearchText, value) AndAlso Not _suppressTargetFilter Then
                    FilterManufacturedProducts()
                End If
            End Set
        End Property

        Private _ingredientSearchText As String = ""
        Public Property IngredientSearchText As String
            Get
                Return _ingredientSearchText
            End Get
            Set(value As String)
                If SetProperty(_ingredientSearchText, value) AndAlso Not _suppressIngredientFilter Then
                    FilterRawMaterialProducts()
                End If
            End Set
        End Property

        Private _selectedRecipe As Recipe
        Public Property SelectedRecipe As Recipe
            Get
                Return _selectedRecipe
            End Get
            Set(value As Recipe)
                If SetProperty(_selectedRecipe, value) AndAlso value IsNot Nothing Then
                    LoadRecipeDetails(value.ProductID)
                End If
            End Set
        End Property

        Private _selectedTargetProduct As Product
        Public Property SelectedTargetProduct As Product
            Get
                Return _selectedTargetProduct
            End Get
            Set(value As Product)
                If SetProperty(_selectedTargetProduct, value) Then
                    If value IsNot Nothing Then
                        ' Block filter re-run when WPF writes display name back into Text
                        _suppressTargetFilter = True
                        _targetSearchText = value.ProductName
                        OnPropertyChanged(NameOf(TargetSearchText))
                        _suppressTargetFilter = False
                        LoadRecipeDetails(value.ProductID)
                    End If
                End If
            End Set
        End Property

        Private _selectedIngredientToAdd As Product
        Public Property SelectedIngredientToAdd As Product
            Get
                Return _selectedIngredientToAdd
            End Get
            Set(value As Product)
                If SetProperty(_selectedIngredientToAdd, value) Then
                    If value IsNot Nothing Then
                        ' Block filter re-run when WPF writes display name back into Text
                        _suppressIngredientFilter = True
                        _ingredientSearchText = value.ProductName
                        OnPropertyChanged(NameOf(IngredientSearchText))
                        _suppressIngredientFilter = False
                    End If
                End If
            End Set
        End Property

        Private _ingredientQtyToAdd As Decimal = 1.0
        Public Property IngredientQtyToAdd As Decimal
            Get
                Return _ingredientQtyToAdd
            End Get
            Set(value As Decimal)
                SetProperty(_ingredientQtyToAdd, value)
            End Set
        End Property

        Private _notes As String
        Public Property Notes As String
            Get
                Return _notes
            End Get
            Set(value As String)
                SetProperty(_notes, value)
            End Set
        End Property

        Private _totalRecipeCost As Decimal
        Public Property TotalRecipeCost As Decimal
            Get
                Return _totalRecipeCost
            End Get
            Set(value As Decimal)
                SetProperty(_totalRecipeCost, value)
            End Set
        End Property

        Private _currencySymbol As String = "د.أ"
        Public Property CurrencySymbol As String
            Get
                Return _currencySymbol
            End Get
            Set(value As String)
                SetProperty(_currencySymbol, value)
            End Set
        End Property

        ' Pagination (10 records per page)
        Private _currentPage As Integer = 1
        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                SetProperty(_currentPage, value)
            End Set
        End Property

        Public Const PageSize As Integer = 10

        Private _totalRecords As Integer = 0
        Public Property TotalRecords As Integer
            Get
                Return _totalRecords
            End Get
            Set(value As Integer)
                SetProperty(_totalRecords, value)
            End Set
        End Property

        Public ReadOnly Property TotalPages As Integer
            Get
                Return Math.Max(1, CInt(Math.Ceiling(TotalRecords / CDbl(PageSize))))
            End Get
        End Property

        Public ReadOnly Property HasPreviousPage As Boolean
            Get
                Return CurrentPage > 1
            End Get
        End Property

        Public ReadOnly Property HasNextPage As Boolean
            Get
                Return CurrentPage < TotalPages
            End Get
        End Property

        Public ReadOnly Property PageInfo As String
            Get
                Return $"صفحة {CurrentPage} من {TotalPages} (إجمالي: {TotalRecords})"
            End Get
        End Property

        Public Property AddIngredientCommand As ICommand
        Public Property RemoveIngredientCommand As ICommand
        Public Property SaveRecipeCommand As ICommand
        Public Property DeleteRecipeCommand As ICommand
        Public Property NewRecipeCommand As ICommand
        Public Property ClearRecipeFilterCommand As ICommand
        Public Property NextPageCommand As ICommand
        Public Property PreviousPageCommand As ICommand
        Public Property FirstPageCommand As ICommand
        Public Property LastPageCommand As ICommand

        ''' <summary>Fired to display a Snackbar notification</summary>
        Public Event RequestSnackbar As Action(Of String)

        ''' <summary>Fired after a recipe is loaded — carries (productID, productName)</summary>
        Public Event RecipeLoaded As EventHandler(Of (productID As Integer, productName As String))

        Public Sub New()
            _recipeService = New RecipeService()
            _productService = New ProductService()
            _warehouseService = New Services.WarehouseService()

            Warehouses = New ObservableCollection(Of Warehouse)()
            Recipes = New ObservableCollection(Of Recipe)()
            FilteredRecipes = New ObservableCollection(Of Recipe)()
            ManufacturedProducts = New ObservableCollection(Of Product)()
            RawMaterialProducts = New ObservableCollection(Of Product)()
            FilteredManufacturedProducts = New ObservableCollection(Of Product)()
            FilteredRawMaterialProducts = New ObservableCollection(Of Product)()
            CurrentRecipeDetails = New ObservableCollection(Of RecipeDetail)()

            AddIngredientCommand = New RelayCommand(AddressOf AddIngredient)
            RemoveIngredientCommand = New RelayCommand(AddressOf RemoveIngredient)
            SaveRecipeCommand = New RelayCommand(AddressOf SaveRecipe)
            DeleteRecipeCommand = New RelayCommand(AddressOf DeleteRecipe)
            NewRecipeCommand = New RelayCommand(AddressOf ResetForm)
            ClearRecipeFilterCommand = New RelayCommand(AddressOf ClearRecipeFilter)
            NextPageCommand = New RelayCommand(AddressOf GoToNextPage, Function() HasNextPage)
            PreviousPageCommand = New RelayCommand(AddressOf GoToPreviousPage, Function() HasPreviousPage)
            FirstPageCommand = New RelayCommand(AddressOf GoToFirstPage, Function() HasPreviousPage)
            LastPageCommand = New RelayCommand(AddressOf GoToLastPage, Function() HasNextPage)

            LoadPermissions("Recipes")
            LoadInitialData()
        End Sub

        Private Sub LoadInitialData()
            Try
                ' Load Currency Symbol from Company Settings
                Try
                    Dim settingsSvc As New Services.SettingsService()
                    Dim companyInfo = settingsSvc.GetCompanyInfo()
                    If companyInfo IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(companyInfo.CurrencySymbol) Then
                        If companyInfo.CurrencySymbol.Contains("/") Then
                            CurrencySymbol = companyInfo.CurrencySymbol.Split("/"c)(0).Trim()
                        Else
                            CurrencySymbol = companyInfo.CurrencySymbol.Trim()
                        End If
                    End If
                Catch
                End Try

                ' Load Warehouses
                Try
                    Dim wList = _warehouseService.GetAllWarehouses()
                    Warehouses.Clear()
                    For Each w In wList
                        Warehouses.Add(w)
                    Next
                    If Warehouses.Any() AndAlso Not SelectedWarehouseID.HasValue Then
                        SelectedWarehouseID = Warehouses.First().WarehouseID
                    End If
                Catch
                End Try

                ' Load all products
                Dim allProducts = _productService.GetAllProducts()

                ManufacturedProducts.Clear()
                RawMaterialProducts.Clear()

                ' Target Products: Manufactured (2) or Semi-Finished (3) loaded via sp_Product_GetForRecipeTarget for selected warehouse
                Dim mProducts = _productService.GetProductsForRecipeTarget(SelectedWarehouseID)

                ' Ingredient Products: Raw Material (0), Semi-Finished (3), or Standard (1) loaded via sp_Product_GetForRecipeIngredients for selected warehouse
                LoadRawMaterialProductsForSelectedWarehouse()

                For Each p In mProducts
                    ManufacturedProducts.Add(p)
                Next

                FilterManufacturedProducts()

                LoadAllRecipes()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تحميل بيانات الأصناف والوصفات: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub LoadRawMaterialProductsForSelectedWarehouse()
            Try
                RawMaterialProducts.Clear()
                Dim rProducts = _productService.GetProductsForRecipeIngredients(SelectedWarehouseID)
                For Each p In rProducts
                    RawMaterialProducts.Add(p)
                Next
                FilterRawMaterialProducts()
            Catch ex As Exception
            End Try
        End Sub

        Private Sub FilterManufacturedProducts()
            ApplyManufacturedFilter(TargetSearchText)
        End Sub

        ''' <summary>Called by SearchableDropdown.SearchChanged event to filter ManufacturedProducts</summary>
        Public Sub ApplyManufacturedFilter(query As String)
            FilteredManufacturedProducts.Clear()
            Dim q = If(query, "").Trim().ToLower()

            For Each p In ManufacturedProducts
                If String.IsNullOrWhiteSpace(q) OrElse
                   (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(q)) OrElse
                   (p.ProductNameEn IsNot Nothing AndAlso p.ProductNameEn.ToLower().Contains(q)) OrElse
                   (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(q)) Then
                    FilteredManufacturedProducts.Add(p)
                End If
            Next
        End Sub

        Private Sub FilterRawMaterialProducts()
            FilteredRawMaterialProducts.Clear()
            Dim query = IngredientSearchText.Trim().ToLower()

            For Each p In RawMaterialProducts
                If String.IsNullOrWhiteSpace(query) OrElse
                   (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(query)) OrElse
                   (p.ProductNameEn IsNot Nothing AndAlso p.ProductNameEn.ToLower().Contains(query)) OrElse
                   (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(query)) Then
                    FilteredRawMaterialProducts.Add(p)
                End If
            Next
        End Sub

        Private Sub LoadAllRecipes()
            Try
                Dim result = _recipeService.GetRecipesPaged(_currentPage, PageSize)
                Recipes.Clear()
                For Each r In result.Data
                    Recipes.Add(r)
                Next
                _totalRecords = result.TotalCount
                NotifyPaginationChanged()
                FilterRecipes()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب الوصفات: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub NotifyPaginationChanged()
            OnPropertyChanged(NameOf(CurrentPage))
            OnPropertyChanged(NameOf(TotalRecords))
            OnPropertyChanged(NameOf(TotalPages))
            OnPropertyChanged(NameOf(HasPreviousPage))
            OnPropertyChanged(NameOf(HasNextPage))
            OnPropertyChanged(NameOf(PageInfo))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        Public Sub GoToNextPage()
            If HasNextPage Then
                CurrentPage += 1
                LoadAllRecipes()
            End If
        End Sub

        Public Sub GoToPreviousPage()
            If HasPreviousPage Then
                CurrentPage -= 1
                LoadAllRecipes()
            End If
        End Sub

        Public Sub GoToFirstPage()
            If CurrentPage <> 1 Then
                CurrentPage = 1
                LoadAllRecipes()
            End If
        End Sub

        Public Sub GoToLastPage()
            If CurrentPage <> TotalPages Then
                CurrentPage = TotalPages
                LoadAllRecipes()
            End If
        End Sub

        Public Sub FilterRecipes()
            FilteredRecipes.Clear()
            Dim bCode = If(RecipeSearchBarcode, "").Trim().ToLower()
            Dim pName = If(RecipeSearchName, "").Trim().ToLower()

            For Each r In Recipes
                Dim matchBarcode = String.IsNullOrWhiteSpace(bCode) OrElse (r.Barcode IsNot Nothing AndAlso r.Barcode.ToLower().Contains(bCode))
                Dim matchName = String.IsNullOrWhiteSpace(pName) OrElse (r.ProductName IsNot Nothing AndAlso r.ProductName.ToLower().Contains(pName))
                If matchBarcode AndAlso matchName Then
                    FilteredRecipes.Add(r)
                End If
            Next
        End Sub

        Public Sub ClearRecipeFilter(parameter As Object)
            _recipeSearchBarcode = ""
            _recipeSearchName = ""
            OnPropertyChanged(NameOf(RecipeSearchBarcode))
            OnPropertyChanged(NameOf(RecipeSearchName))
            FilterRecipes()
        End Sub

        Private Sub LoadRecipeDetails(productID As Integer)
            Try
                Dim r = _recipeService.GetRecipeByProduct(productID, SelectedWarehouseID)
                CurrentRecipeDetails.Clear()

                If r IsNot Nothing Then
                    Notes = r.Notes
                    If r.Details IsNot Nothing Then
                        For Each d In r.Details
                            CurrentRecipeDetails.Add(d)
                        Next
                    End If
                Else
                    Notes = String.Empty
                End If

                ' Match SelectedTargetProduct dropdown
                SelectedTargetProduct = ManufacturedProducts.FirstOrDefault(Function(p) p.ProductID = productID)
                CalculateTotalCost()

                ' Notify view to sync SearchableDropdown display text
                Dim name = If(SelectedTargetProduct?.ProductName, String.Empty)
                RaiseEvent RecipeLoaded(Me, (productID, name))
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب تفاصيل الوصفة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub AddIngredient(parameter As Object)
            ' Add an empty row directly to the grid for inline editing
            Dim newDetail As New RecipeDetail With {
                .IngredientProductID = 0,
                .IngredientName = String.Empty,
                .IngredientBarcode = String.Empty,
                .UnitName = String.Empty,
                .Qty = 1,
                .UnitCost = 0,
                .LineCost = 0
            }
            CurrentRecipeDetails.Add(newDetail)
            CalculateTotalCost()
        End Sub

        Private Sub RemoveIngredient(parameter As Object)
            Dim detail = TryCast(parameter, RecipeDetail)
            If detail IsNot Nothing Then
                CurrentRecipeDetails.Remove(detail)
                CalculateTotalCost()
            End If
        End Sub

        Public Sub CalculateTotalCost()
            Dim sum As Decimal = 0
            For Each d In CurrentRecipeDetails
                d.LineCost = d.Qty * d.UnitCost
                sum += d.LineCost
            Next
            TotalRecipeCost = sum
        End Sub

        Private Sub SaveRecipe(parameter As Object)
            If SelectedTargetProduct Is Nothing Then
                MessageBox.Show("يرجى اختيار المنتج المصنع المراد حفظ وصفته", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            ' تلقائياً: حذف الصفوف الفارغة أو غير المكتملة (بدون صنف أو بكمية أقل من أو تساوي 0)
            Dim emptyRows = CurrentRecipeDetails.Where(
                Function(d) d.IngredientProductID <= 0 OrElse d.Qty <= 0 OrElse
                            (String.IsNullOrWhiteSpace(d.IngredientBarcode) AndAlso String.IsNullOrWhiteSpace(d.IngredientName))
            ).ToList()

            For Each row In emptyRows
                CurrentRecipeDetails.Remove(row)
            Next

            CalculateTotalCost()

            If CurrentRecipeDetails.Count = 0 Then
                MessageBox.Show("يرجى إضافة مادة خام واحدة على الأقل في الوصفة", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            Try
                Dim recipeID = _recipeService.SaveRecipe(SelectedTargetProduct.ProductID, Notes, CurrentRecipeDetails.ToList(), SelectedWarehouseID)
                RaiseEvent RequestSnackbar("✅ تم حفظ الوصفة وتحديث أسعار تكلفة المخزون بنجاح 👌")

                LoadAllRecipes()
                SelectedRecipe = Recipes.FirstOrDefault(Function(r) r.RecipeID = recipeID)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الوصفة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub DeleteRecipe(parameter As Object)
            If SelectedRecipe Is Nothing Then
                MessageBox.Show("يرجى اختيار وصفة لحذفها", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            If MessageBox.Show("هل أنت تأكد من حذف هذه الوصفة؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    _recipeService.DeleteRecipe(SelectedRecipe.RecipeID)
                    MessageBox.Show("تم حذف الوصفة بنجاح", "تم", MessageBoxButton.OK, MessageBoxImage.Information)
                    ResetForm(Nothing)
                    LoadAllRecipes()
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء حذف الوصفة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Sub ResetForm(parameter As Object)
            SelectedRecipe = Nothing
            SelectedTargetProduct = Nothing
            SelectedIngredientToAdd = Nothing
            IngredientQtyToAdd = 1.0
            Notes = String.Empty
            CurrentRecipeDetails.Clear()
            TotalRecipeCost = 0
        End Sub
    End Class
End Namespace
