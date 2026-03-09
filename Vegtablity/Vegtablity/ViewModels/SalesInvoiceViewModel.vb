Imports System.Collections.ObjectModel
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports System.Windows.Input
Imports System.Linq
Imports System.ComponentModel
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class SalesInvoiceViewModel
        Inherits BaseViewModel

        Private ReadOnly _invoiceService As InvoiceService
        Private ReadOnly _partnerService As PartnerService
        Private ReadOnly _productService As ProductService
        Private ReadOnly _warehouseService As WarehouseService
        Private ReadOnly _inventoryService As InventoryService
        Private ReadOnly _accountingService As AccountingService

        ' --- Collections for UI Dropdowns ---
        Public Property Customers As ObservableCollection(Of Partner)
        Public Property Warehouses As ObservableCollection(Of Warehouse)
        Public Property Products As ObservableCollection(Of Product)
        Public Property CashAccounts As ObservableCollection(Of Account)  ' حسابات النقدية (11xx)

        ' Event raised to ask the View to show a Snackbar notification
        Public Event RequestSnackbar As Action(Of String)

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
                ' Notify all derived UI state properties when invoice is replaced (e.g. New Invoice)
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
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

        Public ReadOnly Property IsPaymentAccountEnabled As Boolean
            Get
                Return IsEditAllowed AndAlso CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PaidAmount > 0
            End Get
        End Property

        ' --- Commands ---
        Public Property SaveCommand As ICommand
        Public Property PostCommand As ICommand
        Public Property NewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property RemoveItemCommand As ICommand
        Public Property PrintCommand As ICommand

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then
                Customers = New ObservableCollection(Of Partner)()
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
            _inventoryService = New InventoryService()
            _accountingService = New AccountingService()

            Customers = New ObservableCollection(Of Partner)()
            Warehouses = New ObservableCollection(Of Warehouse)()
            Products = New ObservableCollection(Of Product)()
            CashAccounts = New ObservableCollection(Of Account)()

            SaveCommand = New RelayCommand(AddressOf ExecuteSave, AddressOf CanExecuteSave)
            PostCommand = New RelayCommand(AddressOf ExecutePost, AddressOf CanExecutePost)
            NewCommand = New RelayCommand(AddressOf ExecuteNew)
            AddItemCommand = New RelayCommand(AddressOf ExecuteAddItem, AddressOf CanExecuteAddItem)
            RemoveItemCommand = New RelayCommand(AddressOf ExecuteRemoveItem, AddressOf CanExecuteRemoveItem)
            PrintCommand = New RelayCommand(AddressOf ExecutePrint, AddressOf CanExecutePrint)

            LoadLookups()
            LoadPermissions("Sales")
            ExecuteNew(Nothing)
        End Sub

        Private Sub LoadLookups()
            Dim customerList = _partnerService.GetAllPartners("Customer")
            Customers.Clear()
            For Each c In customerList
                Customers.Add(c)
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

            Dim cashList = _accountingService.GetCashAccounts()
            CashAccounts.Clear()
            For Each a In cashList
                CashAccounts.Add(a)
            Next
        End Sub

        Private Sub OnInvoicePropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = NameOf(InvoiceHeader.IsPosted) Then
                OnPropertyChanged(NameOf(IsInvoicePosted))
                OnPropertyChanged(NameOf(IsEditAllowed))
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
            End If
            If e.PropertyName = NameOf(InvoiceHeader.PaidAmount) Then
                OnPropertyChanged(NameOf(IsPaymentAccountEnabled))
                ' Clear payment account if amount becomes 0
                If CurrentInvoice IsNot Nothing AndAlso CurrentInvoice.PaidAmount = 0 Then
                    CurrentInvoice.PaymentAccountID = Nothing
                End If
            End If
            If e.PropertyName = NameOf(InvoiceHeader.WarehouseID) Then
                ' Revalidate stock for all items if warehouse changes
                ValidateStockForAllItems()
            End If
            ' Command re-evaluations
            System.Windows.Input.CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub ExecuteNew(parameter As Object)
            CurrentInvoice = New InvoiceHeader() With {
                .InvType = "Sales",
                .InvDate = DateTime.Now,
                .CreatedAt = DateTime.Now,
                .ReferenceNo = Nothing,
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

        ''' <summary>Load an existing invoice by ID (called from Invoice Dashboard)</summary>
        Public Sub LoadInvoice(invID As Integer)
            Dim loaded = _invoiceService.LoadInvoiceForEdit(invID)
            If loaded IsNot Nothing Then
                CurrentInvoice = loaded
                If Not CurrentInvoice.IsPosted AndAlso CurrentInvoice.Details.Count = 0 Then
                    ExecuteAddItem(Nothing)
                End If
            End If
        End Sub

        Private Function CanExecuteSave(parameter As Object) As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            ' Permission Check
            If CurrentInvoice.InvID = 0 AndAlso Not CurrentPermissions.CanAdd Then Return False
            If CurrentInvoice.InvID > 0 AndAlso Not CurrentPermissions.CanEdit Then Return False

            If Not CurrentInvoice.PartnerID.HasValue Then Return False
            If Not CurrentInvoice.WarehouseID.HasValue Then Return False
            If CurrentInvoice.Details Is Nothing OrElse CurrentInvoice.Details.Count = 0 Then Return False
            ' إذا أدخل مبلغاً مدفوعاً يجب اختيار طريقة الدفع
            If CurrentInvoice.PaidAmount > 0 AndAlso Not CurrentInvoice.PaymentAccountID.HasValue Then Return False

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

                ' Validate Stock before saving (Soft check to warn user)
                If Not ValidateStockForAllItems() Then
                    Dim answer = System.Windows.MessageBox.Show("بعض الأصناف تتجاوز المخزون المتاح، هل تريد الحفظ كمسودة على أية حال؟ لا يمكنك الترحيل بهذا الشكل.", "تحذير المخزون", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
                    If answer = System.Windows.MessageBoxResult.No Then Return
                End If

                ' Attach the current user to the invoice header
                If Services.Session.CurrentUser IsNot Nothing Then
                    CurrentInvoice.UserID = Services.Session.CurrentUser.UserID
                End If

                Dim invId = _invoiceService.SaveInvoice(CurrentInvoice)

                If CurrentInvoice.InvID = 0 Then
                    CurrentInvoice.InvID = invId
                    
                    ' Fetch generated sequence and creation date
                    Dim freshInvoice = _invoiceService.GetInvoiceByID(invId)
                    If freshInvoice IsNot Nothing Then
                        CurrentInvoice.ReferenceNo = freshInvoice.ReferenceNo
                        CurrentInvoice.CreatedAt = freshInvoice.CreatedAt
                    End If
                End If
                RaiseEvent RequestSnackbar("✅ تم حفظ الفاتورة بنجاح")
            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanExecutePost(parameter As Object) As Boolean
            If Not CurrentPermissions.CanEdit Then Return False
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.IsPosted Then Return False
            If CurrentInvoice.InvID = 0 Then Return False ' Must be saved first
            Return True
        End Function

        Private Sub ExecutePost(parameter As Object)
            ' Hard Validation: Prevent Posting if Stock is Insufficient
            If Not ValidateStockForAllItems() Then
                System.Windows.MessageBox.Show("لا يمكن ترحيل الفاتورة! توجد أصناف تتجاوز المخزون المتاح في المستودع المختار. يرجى تعديل الكميات.", "خطأ", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error)
                Return
            End If

            Dim result = System.Windows.MessageBox.Show("هل أنت متأكد من ترحيل فاتورة المبيعات؟ سيتم خصم المخزون وتوليد القيود بشكل نهائي.", "تأكيد الترحيل", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
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

        Private Function CanExecutePrint(parameter As Object) As Boolean
            If Not CurrentPermissions.CanPrint Then Return False
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.InvID = 0 Then Return False
            Return True
        End Function

        Private Sub ExecutePrint(parameter As Object)
            Dim customerName As String = ""
            If CurrentInvoice.PartnerID.HasValue Then
                Dim partner = Customers.FirstOrDefault(Function(p) p.PartnerID = CurrentInvoice.PartnerID.Value)
                If partner IsNot Nothing Then
                    customerName = partner.PartnerName
                End If
            End If

            Dim printer As New InvoicePrinter()
            printer.PrintSalesInvoice(CurrentInvoice, customerName)
        End Sub

        Private Function ValidateStockForAllItems() As Boolean
            If CurrentInvoice Is Nothing OrElse CurrentInvoice.Details Is Nothing Then Return True
            If Not CurrentInvoice.WarehouseID.HasValue Then Return True
            
            Dim isAllValid As Boolean = True
            For Each detail In CurrentInvoice.Details
                If detail.ProductID > 0 Then
                    Dim availableQty = _inventoryService.GetStockByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                    If detail.Quantity > availableQty Then
                        isAllValid = False
                        ' Here we could inject a notification property to the detail model itself
                    End If
                End If
            Next
            Return isAllValid
        End Function

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
            Dim detail = CType(sender, InvoiceDetail)
            
            If e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                ' Auto-fill Price and reset Quantity based on Product Select for Sales (SalePrice)
                Dim prod = Products.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod IsNot Nothing Then
                    detail.Quantity = 1
                    detail.UnitPrice = prod.SalePrice
                    ' Use weighted average cost from ProductStock for this warehouse;
                    ' fallback to static PurchasePrice if no stock record exists yet.
                    If CurrentInvoice.WarehouseID.HasValue AndAlso CurrentInvoice.WarehouseID.Value > 0 Then
                        Dim avgCost = _inventoryService.GetAvgCostByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                        detail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                    Else
                        detail.CostPrice = prod.PurchasePrice ' fallback: no warehouse selected yet
                    End If
                    detail.Barcode = prod.Barcode ' Sync Barcode
                End If
            End If

            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse e.PropertyName = NameOf(InvoiceDetail.UnitPrice) OrElse e.PropertyName = NameOf(InvoiceDetail.TotalPrice) Then
                RecalculateTotals()
            End If
            
            If e.PropertyName = NameOf(InvoiceDetail.Quantity) OrElse e.PropertyName = NameOf(InvoiceDetail.ProductID) Then
                If CurrentInvoice.WarehouseID.HasValue AndAlso detail.ProductID > 0 Then
                     Dim available = _inventoryService.GetStockByProduct(detail.ProductID, CurrentInvoice.WarehouseID.Value)
                     If detail.Quantity > available Then
                          ' Warning logic here (Could add a property to InvoiceDetail like "IsStockWarning")
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
