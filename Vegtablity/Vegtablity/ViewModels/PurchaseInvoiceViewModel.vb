Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports System.Linq
Imports System.ComponentModel
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class PurchaseInvoiceViewModel
        Inherits BaseViewModel

        Private ReadOnly _invoiceService As InvoiceService
        Private ReadOnly _partnerService As PartnerService
        Private ReadOnly _productService As ProductService
        Private ReadOnly _warehouseService As WarehouseService

        ' --- Collections for UI Dropdowns ---
        Public Property Vendors As ObservableCollection(Of Partner)
        Public Property Warehouses As ObservableCollection(Of Warehouse)

        ' Event raised to ask the View to show a Snackbar notification
        Public Event RequestSnackbar As Action(Of String)
        Public Property Products As ObservableCollection(Of Product)

        ' --- Current Invoice Data ---
        Private _currentInvoice As InvoiceHeader
        Public Property CurrentInvoice As InvoiceHeader
            Get
                Return _currentInvoice
            End Get
            Set(value As InvoiceHeader)
                If _currentInvoice IsNot Nothing Then
                    RemoveHandler _currentInvoice.PropertyChanged, AddressOf OnInvoicePropertyChanged
                End If
                SetProperty(_currentInvoice, value)
                If _currentInvoice IsNot Nothing Then
                    AddHandler _currentInvoice.PropertyChanged, AddressOf OnInvoicePropertyChanged
                End If
            End Set
        End Property

        Public ReadOnly Property IsInvoicePosted As Boolean
            Get
                If CurrentInvoice IsNot Nothing Then Return CurrentInvoice.IsPosted
                Return False
            End Get
        End Property

        Public ReadOnly Property IsEditAllowed As Boolean
            Get
                Return Not IsInvoicePosted
            End Get
        End Property

        ' --- Commands ---
        Public Property SaveCommand As ICommand
        Public Property PostCommand As ICommand
        Public Property NewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property RemoveItemCommand As ICommand

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                Vendors = New ObservableCollection(Of Partner)()
                Warehouses = New ObservableCollection(Of Warehouse)()
                Products = New ObservableCollection(Of Product)()
                CurrentInvoice = New InvoiceHeader() With {
                    .InvDate = DateTime.Now,
                    .Details = New ObservableCollection(Of InvoiceDetail)() 
                }
                Return
            End If

            _invoiceService = New InvoiceService()
            _partnerService = New PartnerService()
            _productService = New ProductService()
            _warehouseService = New WarehouseService()

            Vendors = New ObservableCollection(Of Partner)()
            Warehouses = New ObservableCollection(Of Warehouse)()
            Products = New ObservableCollection(Of Product)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            PostCommand = New RelayCommand(AddressOf ExecutePost, AddressOf CanExecutePost)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem, AddressOf CanExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)

            LoadLookups()
            ExecuteNew(Nothing)
        End Sub

        Private Sub LoadLookups()
            Dim vendorsList = _partnerService.GetAllPartners("Supplier")
            Vendors.Clear()
            For Each v In vendorsList
                Vendors.Add(v)
            Next

            Dim warehouseList = _warehouseService.GetAllWarehouses()
            Warehouses.Clear()
            For Each w In warehouseList
                Warehouses.Add(w)
            Next

            Dim productList = _productService.GetAllProducts()
            Products.Clear()
            For Each p In productList
                Products.Add(p)
            Next
        End Sub

        Private Sub OnInvoicePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(InvoiceHeader.IsPosted) Then
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
            End If
            ' Command re-evaluations
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub ExecuteNew(parameter As Object)
            CurrentInvoice = New InvoiceHeader() With {
                .InvType = "Purchase",
                .InvDate = DateTime.Now,
                .CreatedAt = DateTime.Now,
                .ReferenceNo = "",
                .Discount = 0,
                .PaidAmount = 0,
                .Details = New ObservableCollection(Of InvoiceDetail)()
            }
            If Warehouses.Any() Then
                CurrentInvoice.WarehouseID = Warehouses.First().WarehouseID
            End If
            
            ' Automatically add an empty row for the new invoice
            ExecuteAddItem(Nothing)
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            If Not CurrentInvoice.PartnerID.HasValue Then Return False
            If Not CurrentInvoice.WarehouseID.HasValue Then Return False
            If CurrentInvoice.Details Is Nothing OrElse CurrentInvoice.Details.Count = 0 Then Return False

            Return True
        End Function

        Private Sub ExecuteSave(parameter As Object)
            Try
                RecalculateTotals()

                ' Remove empty rows (no ProductID selected or zero quantity)
                Dim emptyRows = CurrentInvoice.Details.Where(Function(d) d.ProductID = 0 OrElse d.Quantity = 0).ToList()
                For Each row In emptyRows
                    CurrentInvoice.Details.Remove(row)
                Next

                If CurrentInvoice.Details.Count = 0 Then
                    System.Windows.MessageBox.Show("يجب إضافة صنف واحد على الأقل لحفظ الفاتورة.", "تحذير", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning)
                    Return
                End If

                ' Attach the current user to the invoice header
                If Services.Session.CurrentUser IsNot Nothing Then
                    CurrentInvoice.UserID = Services.Session.CurrentUser.UserID
                End If

                Dim invId = _invoiceService.SaveInvoice(CurrentInvoice)
                If CurrentInvoice.InvID = 0 Then
                    CurrentInvoice.InvID = invId
                End If
                RaiseEvent RequestSnackbar("✅ تم حفظ الفاتورة بنجاح")
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanExecutePost(parameter As Object) As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            If CurrentInvoice.InvID = 0 Then Return False ' Must be saved first
            Return True
        End Function

        Private Sub ExecutePost(parameter As Object)
            Dim result = System.Windows.MessageBox.Show("هل أنت متأكد من ترحيل الفاتورة؟ لن يمكنك التعديل عليها أو حذفها بعد الترحيل، وسيتم تحديث المخزون وتوليد القيود المحاسبية الآلية.", "تأكيد الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            If result = System.Windows.MessageBoxResult.Yes Then
                Try
                    CurrentInvoice.IsPosted = True
                    _invoiceService.SaveInvoice(CurrentInvoice)
                    RaiseEvent RequestSnackbar("✅ تم ترحيل الفاتورة بنجاح")
                Catch ex As Exception
                    CurrentInvoice.IsPosted = False ' Revert on failure
                    System.Windows.MessageBox.Show("خطأ أثناء الترحيل: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Function CanExecuteAddItem(parameter As Object) As Boolean
            Return IsEditAllowed
        End Function

        Private Sub ExecuteAddItem(parameter As Object)
            Dim newItem = New InvoiceDetail() With {.Quantity = 1, .UnitPrice = 0}
            AddHandler newItem.PropertyChanged, AddressOf OnDetailPropertyChanged
            CurrentInvoice.Details.Add(newItem)
            RecalculateTotals()
        End Sub

        Private Function CanExecuteRemoveItem(parameter As Object) As Boolean
            Dim item = TryCast(parameter, InvoiceDetail)
            Return IsEditAllowed AndAlso item IsNot Nothing
        End Function

        Private Sub ExecuteRemoveItem(parameter As Object)
            Dim item = TryCast(parameter, InvoiceDetail)
            If item IsNot Nothing Then
                RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                CurrentInvoice.Details.Remove(item)
                RecalculateTotals()
            End If
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                ' Auto-fill Price based on Product Selection
                Dim detail = CType(sender, InvoiceDetail)
                Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod IsNot Nothing AndAlso detail.UnitPrice = 0 Then
                    detail.UnitPrice = prod.PurchasePrice ' Assuming PurchaseInvoice
                End If
            End If

            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse e.PropertyName = NameOf(InvoiceDetail.UnitPrice) OrElse e.PropertyName = NameOf(InvoiceDetail.TotalPrice) Then
                RecalculateTotals()
            ElseIf e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                Dim detail = TryCast(sender, InvoiceDetail)
                If detail IsNot Nothing AndAlso detail.ProductID > 0 Then
                    Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                    If prod IsNot Nothing Then
                        detail.Quantity = 1
                        detail.UnitPrice = prod.PurchasePrice ' Use PurchasePrice for Purchases
                        detail.Barcode = prod.Barcode ' Sync Barcode
                    End If
                End If
            End If

            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub RecalculateTotals()
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.Details Is Nothing Then Return
            
            Dim total As Decimal = 0
            For Each item In CurrentInvoice.Details
                total += item.TotalPrice
            Next
            CurrentInvoice.TotalAmount = total
        End Sub

    End Class
End Namespace
