Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace ViewModels
    Public Class SalesDiscountsViewModel
        Inherits BaseViewModel

        Private ReadOnly _discountService As New ProductDiscountService()

        Private _discounts As ObservableCollection(Of ProductDiscount)
        Private _selectedDiscount As ProductDiscount
        Private _allProducts As List(Of ProductDiscountItemBinding)
        Private _filteredProducts As ObservableCollection(Of ProductDiscountItemBinding)
        Private _searchProductText As String

        ' Editor Fields
        Private _editDiscountID As Integer
        Private _editDiscountName As String
        Private _editDiscountType As Byte = 1
        Private _editDiscountValue As Decimal
        Private _editMinQuantity As Decimal = 1.0D
        Private _editIsActive As Boolean = True
        Private _isEditing As Boolean = False
        Private _statusMessage As String

        Public Sub New()
            Discounts = New ObservableCollection(Of ProductDiscount)()
            AllProducts = New List(Of ProductDiscountItemBinding)()
            FilteredProducts = New ObservableCollection(Of ProductDiscountItemBinding)()
            
            LoadData()
        End Sub

#Region "Properties - Collections & Selection"
        Public Property Discounts As ObservableCollection(Of ProductDiscount)
            Get
                Return _discounts
            End Get
            Set(value As ObservableCollection(Of ProductDiscount))
                SetProperty(_discounts, value)
            End Set
        End Property

        Public Property SelectedDiscount As ProductDiscount
            Get
                Return _selectedDiscount
            End Get
            Set(value As ProductDiscount)
                SetProperty(_selectedDiscount, value)
                If value IsNot Nothing Then
                    LoadDiscountForEdit(value)
                End If
            End Set
        End Property

        Public Property AllProducts As List(Of ProductDiscountItemBinding)
            Get
                Return _allProducts
            End Get
            Set(value As List(Of ProductDiscountItemBinding))
                SetProperty(_allProducts, value)
            End Set
        End Property

        Public Property FilteredProducts As ObservableCollection(Of ProductDiscountItemBinding)
            Get
                Return _filteredProducts
            End Get
            Set(value As ObservableCollection(Of ProductDiscountItemBinding))
                SetProperty(_filteredProducts, value)
            End Set
        End Property

        Public Property SearchProductText As String
            Get
                Return _searchProductText
            End Get
            Set(value As String)
                SetProperty(_searchProductText, value)
                FilterProducts()
            End Set
        End Property
#End Region

#Region "Properties - Editor"
        Public Property EditDiscountID As Integer
            Get
                Return _editDiscountID
            End Get
            Set(value As Integer)
                SetProperty(_editDiscountID, value)
            End Set
        End Property

        Public Property EditDiscountName As String
            Get
                Return _editDiscountName
            End Get
            Set(value As String)
                SetProperty(_editDiscountName, value)
            End Set
        End Property

        Public Property EditDiscountType As Byte
            Get
                Return _editDiscountType
            End Get
            Set(value As Byte)
                SetProperty(_editDiscountType, value)
                OnPropertyChanged(NameOf(EditDiscountTypeIndex))
            End Set
        End Property

        Public Property EditDiscountTypeIndex As Integer
            Get
                Return Math.Max(0, CInt(_editDiscountType) - 1)
            End Get
            Set(value As Integer)
                If value >= 0 Then
                    EditDiscountType = CByte(value + 1)
                End If
            End Set
        End Property

        Public Property EditDiscountValue As Decimal
            Get
                Return _editDiscountValue
            End Get
            Set(value As Decimal)
                SetProperty(_editDiscountValue, value)
            End Set
        End Property

        Public Property EditMinQuantity As Decimal
            Get
                Return _editMinQuantity
            End Get
            Set(value As Decimal)
                SetProperty(_editMinQuantity, value)
            End Set
        End Property

        Public Property EditIsActive As Boolean
            Get
                Return _editIsActive
            End Get
            Set(value As Boolean)
                SetProperty(_editIsActive, value)
            End Set
        End Property

        Public Property IsEditing As Boolean
            Get
                Return _isEditing
            End Get
            Set(value As Boolean)
                SetProperty(_isEditing, value)
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
        Public ReadOnly Property NewCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNew)
            End Get
        End Property

        Public ReadOnly Property SaveCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSave)
            End Get
        End Property

        Public ReadOnly Property DeleteCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDelete)
            End Get
        End Property

        Public ReadOnly Property ToggleSelectAllCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteToggleSelectAll)
            End Get
        End Property
#End Region

#Region "Methods"
        Private Sub LoadData()
            Try
                Dim discList = _discountService.GetAllDiscounts()
                Discounts = New ObservableCollection(Of ProductDiscount)(discList)

                Dim prodList = _discountService.GetProductsForDiscounts().ToList()
                AllProducts = prodList
                FilterProducts()

                ExecuteNew(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ أثناء تحميل البيانات: " & ex.Message
            End Try
        End Sub

        Private Sub FilterProducts()
            If AllProducts Is Nothing Then
                Exit Sub
            End If

            Dim query = AllProducts.AsEnumerable()
            If Not String.IsNullOrWhiteSpace(SearchProductText) Then
                Dim term = SearchProductText.Trim().ToLower()
                query = query.Where(Function(p) (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(term)) OrElse
                                                (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(term)))
            End If

            FilteredProducts = New ObservableCollection(Of ProductDiscountItemBinding)(query)
        End Sub

        Private Sub LoadDiscountForEdit(disc As ProductDiscount)
            If disc Is Nothing Then
                Exit Sub
            End If

            EditDiscountID = disc.DiscountID
            EditDiscountName = disc.DiscountName
            EditDiscountType = disc.DiscountType
            EditDiscountValue = disc.DiscountValue
            EditMinQuantity = disc.MinQuantity
            EditIsActive = disc.IsActive
            IsEditing = True

            Try
                Dim attachedIDs = _discountService.GetAttachedProductIDs(disc.DiscountID).ToHashSet()
                For Each p In AllProducts
                    p.IsSelected = attachedIDs.Contains(p.ProductID)
                Next
                FilterProducts()
            Catch ex As Exception
                StatusMessage = "خطأ أثناء قراءة أصناف الخصم: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteNew(obj As Object)
            SelectedDiscount = Nothing
            EditDiscountID = 0
            EditDiscountName = ""
            EditDiscountType = 1
            EditDiscountValue = 0.0D
            EditMinQuantity = 1.0D
            EditIsActive = True
            IsEditing = False

            If AllProducts IsNot Nothing Then
                For Each p In AllProducts
                    p.IsSelected = False
                Next
                FilterProducts()
            End If
            StatusMessage = ""
        End Sub

        Private Sub ExecuteSave(obj As Object)
            If String.IsNullOrWhiteSpace(EditDiscountName) Then
                MessageBox.Show("يرجى إدخال اسم الخصم / الباقة.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Exit Sub
            End If

            If EditDiscountValue <= 0 Then
                MessageBox.Show("يرجى إدخال قيمة خصم أكبر من الصفر.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                Exit Sub
            End If

            Try
                Dim minQ As Decimal = 1.0D
                If EditMinQuantity > 0 Then minQ = EditMinQuantity

                Dim disc As New ProductDiscount With {
                    .DiscountID = EditDiscountID,
                    .DiscountName = EditDiscountName.Trim(),
                    .DiscountType = EditDiscountType,
                    .DiscountValue = EditDiscountValue,
                    .MinQuantity = minQ,
                    .IsActive = EditIsActive
                }

                Dim selectedIDs = AllProducts.Where(Function(p) p.IsSelected).Select(Function(p) p.ProductID).ToList()

                Dim savedID = _discountService.SaveDiscount(disc, selectedIDs)
                StatusMessage = "تم حفظ الخصم والباقة بنجاح! 💾"

                LoadData()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الخصم: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteDelete(obj As Object)
            If EditDiscountID <= 0 Then
                Exit Sub
            End If

            If MessageBox.Show("هل أنت تأكد من حذف هذا الخصم / الباقة نهائياً؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    _discountService.DeleteDiscount(EditDiscountID)
                    StatusMessage = "تم حذف الخصم بنجاح."
                    LoadData()
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء الحذف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Sub ExecuteToggleSelectAll(obj As Object)
            If FilteredProducts Is Nothing OrElse FilteredProducts.Count = 0 Then
                Exit Sub
            End If

            Dim allSelected = FilteredProducts.All(Function(p) p.IsSelected)
            For Each p In FilteredProducts
                p.IsSelected = Not allSelected
            Next
            ' Force refresh collection
            FilterProducts()
        End Sub
#End Region
    End Class
End Namespace
