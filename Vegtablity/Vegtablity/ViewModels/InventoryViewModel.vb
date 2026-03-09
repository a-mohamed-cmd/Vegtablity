Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports System.Linq
Imports Vegtablity.Models

Namespace ViewModels
    Public Class InventoryViewModel
        Inherits BaseViewModel

        Private ReadOnly _inventoryService As New Services.InventoryService()
        Private ReadOnly _settingsService As New Services.SettingsService()

        ' ===== Products =====
        Private _allProducts As New List(Of Product)()
        Private _products As ObservableCollection(Of Product)
        Private _selectedProduct As Product
        Private _isEditingProduct As Boolean
        Private _searchText As String

        ' ===== Pagination =====
        Private _currentPage As Integer = 1
        Private _pageSize As Integer = 20
        Private _totalPages As Integer = 1

        ' ===== Edit fields =====
        Private _editProductName As String
        Private _editProductNameEn As String
        Private _editBarcode As String
        Private _editCategoryID As Integer
        Private _editUnitID As Integer
        Private _editPurchasePrice As Decimal
        Private _editSalePrice As Decimal
        Private _editAlertQty As Decimal

        ' ===== Lookups =====
        Private _categories As ObservableCollection(Of Category)
        Private _units As ObservableCollection(Of Unit)

        ' ===== Validation =====
        Private _productNameError As String
        Private _purchasePriceError As String
        Private _salePriceError As String

        ' ===== Status =====
        Private _statusMessage As String

        Public Sub New()
            LoadLookups()
            LoadPermissions("Inventory")
            LoadProducts()
        End Sub

#Region "Properties - Products List"
        Public Property Products As ObservableCollection(Of Product)
            Get
                Return _products
            End Get
            Set(value As ObservableCollection(Of Product))
                SetProperty(_products, value)
            End Set
        End Property

        Public Property SelectedProduct As Product
            Get
                Return _selectedProduct
            End Get
            Set(value As Product)
                SetProperty(_selectedProduct, value)
                If value IsNot Nothing Then
                    EditProductName = value.ProductName
                    EditProductNameEn = value.ProductNameEn
                    EditBarcode = value.Barcode
                    EditCategoryID = value.CategoryID
                    EditUnitID = value.UnitID
                    EditPurchasePrice = value.PurchasePrice
                    EditSalePrice = value.SalePrice
                    EditAlertQty = value.AlertQty
                    IsEditingProduct = True
                    ClearErrors()
                End If
            End Set
        End Property

        Public Property IsEditingProduct As Boolean
            Get
                Return _isEditingProduct
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingProduct, value)
            End Set
        End Property

        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                SetProperty(_searchText, value)
                ' البحث التلقائي عند الكتابة
                If String.IsNullOrWhiteSpace(value) Then
                    LoadProducts()
                Else
                    SearchProducts()
                End If
            End Set
        End Property

#End Region

#Region "Properties - Pagination"

        Public Property CurrentPage As Integer
            Get
                Return _currentPage
            End Get
            Set(value As Integer)
                SetProperty(_currentPage, value)
                OnPropertyChanged(NameOf(PageLabel))
                OnPropertyChanged(NameOf(CanGoNext))
                OnPropertyChanged(NameOf(CanGoPrev))
                UpdatePagination()
            End Set
        End Property

        Public Property TotalPages As Integer
            Get
                Return _totalPages
            End Get
            Private Set(value As Integer)
                SetProperty(_totalPages, value)
                OnPropertyChanged(NameOf(PageLabel))
                OnPropertyChanged(NameOf(CanGoNext))
                OnPropertyChanged(NameOf(CanGoPrev))
            End Set
        End Property

        Public ReadOnly Property PageLabel As String
            Get
                Return $"صفحة {CurrentPage} من {TotalPages} ({_allProducts.Count} عنصر)"
            End Get
        End Property

        Public ReadOnly Property CanGoNext As Boolean
            Get
                Return CurrentPage < TotalPages
            End Get
        End Property

        Public ReadOnly Property CanGoPrev As Boolean
            Get
                Return CurrentPage > 1
            End Get
        End Property

#End Region

#Region "Properties - Edit Fields"
        Public Property EditProductName As String
            Get
                Return _editProductName
            End Get
            Set(value As String)
                SetProperty(_editProductName, value)
                If Not String.IsNullOrEmpty(value) Then ProductNameError = Nothing
            End Set
        End Property

        Public Property EditProductNameEn As String
            Get
                Return _editProductNameEn
            End Get
            Set(value As String)
                SetProperty(_editProductNameEn, value)
            End Set
        End Property

        Public Property EditBarcode As String
            Get
                Return _editBarcode
            End Get
            Set(value As String)
                SetProperty(_editBarcode, value)
            End Set
        End Property

        Public Property EditCategoryID As Integer
            Get
                Return _editCategoryID
            End Get
            Set(value As Integer)
                SetProperty(_editCategoryID, value)
            End Set
        End Property

        Public Property EditUnitID As Integer
            Get
                Return _editUnitID
            End Get
            Set(value As Integer)
                SetProperty(_editUnitID, value)
            End Set
        End Property

        Public Property EditPurchasePrice As Decimal
            Get
                Return _editPurchasePrice
            End Get
            Set(value As Decimal)
                SetProperty(_editPurchasePrice, value)
                If value >= 0 Then PurchasePriceError = Nothing
            End Set
        End Property

        Public Property EditSalePrice As Decimal
            Get
                Return _editSalePrice
            End Get
            Set(value As Decimal)
                SetProperty(_editSalePrice, value)
                If value >= 0 Then SalePriceError = Nothing
            End Set
        End Property

        Public Property EditAlertQty As Decimal
            Get
                Return _editAlertQty
            End Get
            Set(value As Decimal)
                SetProperty(_editAlertQty, value)
            End Set
        End Property
#End Region

#Region "Properties - Lookups"
        Public Property Categories As ObservableCollection(Of Category)
            Get
                Return _categories
            End Get
            Set(value As ObservableCollection(Of Category))
                SetProperty(_categories, value)
            End Set
        End Property

        Public Property Units As ObservableCollection(Of Unit)
            Get
                Return _units
            End Get
            Set(value As ObservableCollection(Of Unit))
                SetProperty(_units, value)
            End Set
        End Property
#End Region

#Region "Properties - Validation"
        Public Property ProductNameError As String
            Get
                Return _productNameError
            End Get
            Set(value As String)
                SetProperty(_productNameError, value)
            End Set
        End Property

        Public Property PurchasePriceError As String
            Get
                Return _purchasePriceError
            End Get
            Set(value As String)
                SetProperty(_purchasePriceError, value)
            End Set
        End Property

        Public Property SalePriceError As String
            Get
                Return _salePriceError
            End Get
            Set(value As String)
                SetProperty(_salePriceError, value)
            End Set
        End Property

        Public Property StatusMessage As String
            Get
                Return _statusMessage
            End Get
            Set(value As String)
                SetProperty(_statusMessage, value)
            End Set
        End Property
#End Region

#Region "Commands"
        Public ReadOnly Property SaveProductCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveProduct)
            End Get
        End Property

        Public ReadOnly Property NewProductCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewProduct)
            End Get
        End Property

        Public ReadOnly Property DeleteProductCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteProduct, Function(o) SelectedProduct IsNot Nothing AndAlso CurrentPermissions IsNot Nothing AndAlso CurrentPermissions.CanDelete)
            End Get
        End Property

        Public ReadOnly Property NextPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) CurrentPage += 1, Function(o) CanGoNext)
            End Get
        End Property

        Public ReadOnly Property PrevPageCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) CurrentPage -= 1, Function(o) CanGoPrev)
            End Get
        End Property
#End Region

#Region "Methods"
        Private Sub LoadLookups()
            Try
                Categories = New ObservableCollection(Of Category)(_settingsService.GetAllCategories())
                Units = New ObservableCollection(Of Unit)(_settingsService.GetAllUnits())
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل البيانات المرجعية: " & ex.Message
            End Try
        End Sub

        Private Sub LoadProducts()
            Try
                _allProducts = _inventoryService.GetAllProducts()
                CalculatePagination()
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل الأصناف: " & ex.Message
            End Try
        End Sub

        Private Sub SearchProducts()
            Try
                _allProducts = _inventoryService.SearchProducts(SearchText)
                CalculatePagination()
            Catch ex As Exception
                StatusMessage = "خطأ في البحث: " & ex.Message
            End Try
        End Sub

        Private Sub CalculatePagination()
            TotalPages = Math.Max(1, CInt(Math.Ceiling(_allProducts.Count / _pageSize)))
            _currentPage = 1 ' Use backing field to avoid triggering UpdatePagination twice
            OnPropertyChanged(NameOf(CurrentPage))
            OnPropertyChanged(NameOf(PageLabel))
            OnPropertyChanged(NameOf(CanGoNext))
            OnPropertyChanged(NameOf(CanGoPrev))
            UpdatePagination()
        End Sub

        Private Sub UpdatePagination()
            If _allProducts Is Nothing Then Return

            Dim skip = (CurrentPage - 1) * _pageSize
            Dim pagedData = _allProducts.Skip(skip).Take(_pageSize).ToList()
            Products = New ObservableCollection(Of Product)(pagedData)
        End Sub

        Private Sub ClearErrors()
            ProductNameError = Nothing
            PurchasePriceError = Nothing
            SalePriceError = Nothing
        End Sub

        Private Function ValidateProduct() As Boolean
            Dim isValid = True
            ClearErrors()

            ProductNameError = Helpers.ValidationHelper.IsRequired(EditProductName, "اسم الصنف")
            If ProductNameError IsNot Nothing Then isValid = False

            If EditPurchasePrice < 0 Then
                PurchasePriceError = "سعر الشراء لا يمكن أن يكون سالباً"
                isValid = False
            End If

            If EditSalePrice < 0 Then
                SalePriceError = "سعر البيع لا يمكن أن يكون سالباً"
                isValid = False
            End If

            Return isValid
        End Function

        Private Sub ExecuteNewProduct(obj As Object)
            SelectedProduct = Nothing
            EditProductName = ""
            EditProductNameEn = ""
            EditBarcode = ""
            EditCategoryID = 0
            EditUnitID = 0
            EditPurchasePrice = 0
            EditSalePrice = 0
            EditAlertQty = 0
            IsEditingProduct = False
            ClearErrors()
        End Sub

        Private Sub ExecuteSaveProduct(obj As Object)
            ' Permission Check
            If Not IsEditingProduct AndAlso Not CurrentPermissions.CanAdd Then
                StatusMessage = "ليس لديك صلاحية لإضافة صنف جديد."
                Return
            End If
            If IsEditingProduct AndAlso Not CurrentPermissions.CanEdit Then
                StatusMessage = "ليس لديك صلاحية لتعديل هذا الصنف."
                Return
            End If

            If Not ValidateProduct() Then Return

            Try
                Dim p As New Product With {
                    .ProductID = If(IsEditingProduct AndAlso SelectedProduct IsNot Nothing, SelectedProduct.ProductID, 0),
                    .ProductName = EditProductName,
                    .ProductNameEn = EditProductNameEn,
                    .Barcode = EditBarcode,
                    .CategoryID = EditCategoryID,
                    .UnitID = EditUnitID,
                    .PurchasePrice = EditPurchasePrice,
                    .SalePrice = EditSalePrice,
                    .AlertQty = EditAlertQty
                }
                _inventoryService.SaveProduct(p)
                StatusMessage = If(p.ProductID = 0, "تم إضافة الصنف بنجاح. ✅", "تم تحديث الصنف بنجاح. ✅")
                LoadProducts()
                ExecuteNewProduct(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteProduct(obj As Object)
            If SelectedProduct Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذا الصنف؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _inventoryService.DeleteProduct(SelectedProduct.ProductID)
                    StatusMessage = "تم تعطيل الصنف. ✅"
                    LoadProducts()
                    ExecuteNewProduct(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub
#End Region

    End Class
End Namespace
