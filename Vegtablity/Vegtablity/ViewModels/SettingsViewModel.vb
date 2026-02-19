Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models

Namespace ViewModels
    Public Class SettingsViewModel
        Inherits BaseViewModel

        Private ReadOnly _settingsService As New Services.SettingsService()

        ' ===== Units =====
        Private _units As ObservableCollection(Of Unit)
        Private _selectedUnit As Unit
        Private _editUnitName As String
        Private _isEditingUnit As Boolean
        Private _unitNameError As String

        ' ===== Categories =====
        Private _categories As ObservableCollection(Of Category)
        Private _selectedCategory As Category
        Private _editCatName As String
        Private _isEditingCategory As Boolean
        Private _catNameError As String

        ' ===== Warehouses =====
        Private _warehouses As ObservableCollection(Of Warehouse)
        Private _selectedWarehouse As Warehouse
        Private _editWarehouseName As String
        Private _editWarehouseAddress As String
        Private _editWarehouseKeeper As String
        Private _isEditingWarehouse As Boolean
        Private _warehouseNameError As String

        ' ===== Status =====
        Private _statusMessage As String

        Public Sub New()
            LoadData()
        End Sub

#Region "Properties - Units"
        Public Property Units As ObservableCollection(Of Unit)
            Get
                Return _units
            End Get
            Set(value As ObservableCollection(Of Unit))
                SetProperty(_units, value)
            End Set
        End Property

        Public Property SelectedUnit As Unit
            Get
                Return _selectedUnit
            End Get
            Set(value As Unit)
                SetProperty(_selectedUnit, value)
                If value IsNot Nothing Then
                    EditUnitName = value.UnitName
                    IsEditingUnit = True
                    UnitNameError = Nothing
                End If
            End Set
        End Property

        Public Property EditUnitName As String
            Get
                Return _editUnitName
            End Get
            Set(value As String)
                SetProperty(_editUnitName, value)
                If Not String.IsNullOrEmpty(value) Then UnitNameError = Nothing
            End Set
        End Property

        Public Property IsEditingUnit As Boolean
            Get
                Return _isEditingUnit
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingUnit, value)
            End Set
        End Property

        Public Property UnitNameError As String
            Get
                Return _unitNameError
            End Get
            Set(value As String)
                SetProperty(_unitNameError, value)
            End Set
        End Property
#End Region

#Region "Properties - Categories"
        Public Property Categories As ObservableCollection(Of Category)
            Get
                Return _categories
            End Get
            Set(value As ObservableCollection(Of Category))
                SetProperty(_categories, value)
            End Set
        End Property

        Public Property SelectedCategory As Category
            Get
                Return _selectedCategory
            End Get
            Set(value As Category)
                SetProperty(_selectedCategory, value)
                If value IsNot Nothing Then
                    EditCatName = value.CatName
                    IsEditingCategory = True
                    CatNameError = Nothing
                End If
            End Set
        End Property

        Public Property EditCatName As String
            Get
                Return _editCatName
            End Get
            Set(value As String)
                SetProperty(_editCatName, value)
                If Not String.IsNullOrEmpty(value) Then CatNameError = Nothing
            End Set
        End Property

        Public Property IsEditingCategory As Boolean
            Get
                Return _isEditingCategory
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingCategory, value)
            End Set
        End Property

        Public Property CatNameError As String
            Get
                Return _catNameError
            End Get
            Set(value As String)
                SetProperty(_catNameError, value)
            End Set
        End Property
#End Region

#Region "Properties - Warehouses"
        Public Property Warehouses As ObservableCollection(Of Warehouse)
            Get
                Return _warehouses
            End Get
            Set(value As ObservableCollection(Of Warehouse))
                SetProperty(_warehouses, value)
            End Set
        End Property

        Public Property SelectedWarehouse As Warehouse
            Get
                Return _selectedWarehouse
            End Get
            Set(value As Warehouse)
                SetProperty(_selectedWarehouse, value)
                If value IsNot Nothing Then
                    EditWarehouseName = value.WarehouseName
                    EditWarehouseAddress = value.Address
                    EditWarehouseKeeper = value.KeeperName
                    IsEditingWarehouse = True
                    WarehouseNameError = Nothing
                End If
            End Set
        End Property

        Public Property EditWarehouseName As String
            Get
                Return _editWarehouseName
            End Get
            Set(value As String)
                SetProperty(_editWarehouseName, value)
                If Not String.IsNullOrEmpty(value) Then WarehouseNameError = Nothing
            End Set
        End Property

        Public Property EditWarehouseAddress As String
            Get
                Return _editWarehouseAddress
            End Get
            Set(value As String)
                SetProperty(_editWarehouseAddress, value)
            End Set
        End Property

        Public Property EditWarehouseKeeper As String
            Get
                Return _editWarehouseKeeper
            End Get
            Set(value As String)
                SetProperty(_editWarehouseKeeper, value)
            End Set
        End Property

        Public Property IsEditingWarehouse As Boolean
            Get
                Return _isEditingWarehouse
            End Get
            Set(value As Boolean)
                SetProperty(_isEditingWarehouse, value)
            End Set
        End Property

        Public Property WarehouseNameError As String
            Get
                Return _warehouseNameError
            End Get
            Set(value As String)
                SetProperty(_warehouseNameError, value)
            End Set
        End Property
#End Region

#Region "Properties - Status"
        Public Property StatusMessage As String
            Get
                Return _statusMessage
            End Get
            Set(value As String)
                SetProperty(_statusMessage, value)
            End Set
        End Property
#End Region

#Region "Commands - Units"
        Public ReadOnly Property SaveUnitCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveUnit)
            End Get
        End Property

        Public ReadOnly Property NewUnitCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewUnit)
            End Get
        End Property

        Public ReadOnly Property DeleteUnitCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteUnit, Function(o) SelectedUnit IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Commands - Categories"
        Public ReadOnly Property SaveCategoryCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveCategory)
            End Get
        End Property

        Public ReadOnly Property NewCategoryCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewCategory)
            End Get
        End Property

        Public ReadOnly Property DeleteCategoryCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteCategory, Function(o) SelectedCategory IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Commands - Warehouses"
        Public ReadOnly Property SaveWarehouseCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteSaveWarehouse)
            End Get
        End Property

        Public ReadOnly Property NewWarehouseCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteNewWarehouse)
            End Get
        End Property

        Public ReadOnly Property DeleteWarehouseCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteDeleteWarehouse, Function(o) SelectedWarehouse IsNot Nothing)
            End Get
        End Property
#End Region

#Region "Methods"
        Private Sub LoadData()
            Try
                Units = New ObservableCollection(Of Unit)(_settingsService.GetAllUnits())
                Categories = New ObservableCollection(Of Category)(_settingsService.GetAllCategories())
                Warehouses = New ObservableCollection(Of Warehouse)(_settingsService.GetAllWarehouses())
            Catch ex As Exception
                StatusMessage = "خطأ في تحميل البيانات: " & ex.Message
            End Try
        End Sub

        ' --- Units ---
        Private Sub ExecuteNewUnit(obj As Object)
            SelectedUnit = Nothing
            EditUnitName = ""
            IsEditingUnit = False
            UnitNameError = Nothing
        End Sub

        Private Sub ExecuteSaveUnit(obj As Object)
            UnitNameError = Helpers.ValidationHelper.IsRequired(EditUnitName, "اسم الوحدة")
            If UnitNameError IsNot Nothing Then Return

            Try
                Dim u As New Unit With {
                    .UnitID = If(IsEditingUnit AndAlso SelectedUnit IsNot Nothing, SelectedUnit.UnitID, 0),
                    .UnitName = EditUnitName
                }
                _settingsService.SaveUnit(u)
                StatusMessage = If(u.UnitID = 0, "تم إضافة الوحدة. ✅", "تم تحديث الوحدة. ✅")
                LoadData()
                ExecuteNewUnit(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteUnit(obj As Object)
            If SelectedUnit Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذه الوحدة؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _settingsService.DeleteUnit(SelectedUnit.UnitID)
                    StatusMessage = "تم تعطيل الوحدة. ✅"
                    LoadData()
                    ExecuteNewUnit(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub

        ' --- Categories ---
        Private Sub ExecuteNewCategory(obj As Object)
            SelectedCategory = Nothing
            EditCatName = ""
            IsEditingCategory = False
            CatNameError = Nothing
        End Sub

        Private Sub ExecuteSaveCategory(obj As Object)
            CatNameError = Helpers.ValidationHelper.IsRequired(EditCatName, "اسم التصنيف")
            If CatNameError IsNot Nothing Then Return

            Try
                Dim c As New Category With {
                    .CatID = If(IsEditingCategory AndAlso SelectedCategory IsNot Nothing, SelectedCategory.CatID, 0),
                    .CatName = EditCatName
                }
                _settingsService.SaveCategory(c)
                StatusMessage = If(c.CatID = 0, "تم إضافة التصنيف. ✅", "تم تحديث التصنيف. ✅")
                LoadData()
                ExecuteNewCategory(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteCategory(obj As Object)
            If SelectedCategory Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذا التصنيف؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _settingsService.DeleteCategory(SelectedCategory.CatID)
                    StatusMessage = "تم تعطيل التصنيف. ✅"
                    LoadData()
                    ExecuteNewCategory(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub

        ' --- Warehouses ---
        Private Sub ExecuteNewWarehouse(obj As Object)
            SelectedWarehouse = Nothing
            EditWarehouseName = ""
            EditWarehouseAddress = ""
            EditWarehouseKeeper = ""
            IsEditingWarehouse = False
            WarehouseNameError = Nothing
        End Sub

        Private Sub ExecuteSaveWarehouse(obj As Object)
            WarehouseNameError = Helpers.ValidationHelper.IsRequired(EditWarehouseName, "اسم المخزن")
            If WarehouseNameError IsNot Nothing Then Return

            Try
                Dim w As New Warehouse With {
                    .WarehouseID = If(IsEditingWarehouse AndAlso SelectedWarehouse IsNot Nothing, SelectedWarehouse.WarehouseID, 0),
                    .WarehouseName = EditWarehouseName,
                    .Address = EditWarehouseAddress,
                    .KeeperName = EditWarehouseKeeper
                }
                _settingsService.SaveWarehouse(w)
                StatusMessage = If(w.WarehouseID = 0, "تم إضافة المخزن. ✅", "تم تحديث المخزن. ✅")
                LoadData()
                ExecuteNewWarehouse(Nothing)
            Catch ex As Exception
                StatusMessage = "خطأ: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteDeleteWarehouse(obj As Object)
            If SelectedWarehouse Is Nothing Then Return
            If MessageBox.Show("هل أنت متأكد من تعطيل هذا المخزن؟", "تأكيد التعطيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _settingsService.DeleteWarehouse(SelectedWarehouse.WarehouseID)
                    StatusMessage = "تم تعطيل المخزن. ✅"
                    LoadData()
                    ExecuteNewWarehouse(Nothing)
                Catch ex As Exception
                    StatusMessage = "خطأ: " & ex.Message
                End Try
            End If
        End Sub
#End Region

    End Class
End Namespace
