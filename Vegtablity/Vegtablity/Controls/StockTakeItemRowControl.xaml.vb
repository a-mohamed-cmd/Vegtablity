Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Linq
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace Controls
    Public Class StockTakeItemRowControl
        Inherits UserControl

        Private ReadOnly _inventoryService As New InventoryService()

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly ProductsListProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(ProductsList), GetType(IEnumerable(Of Product)),
                GetType(StockTakeItemRowControl),
                New PropertyMetadata(Nothing, AddressOf OnProductsListChanged))

        Public Property ProductsList As IEnumerable(Of Product)
            Get
                Return CType(GetValue(ProductsListProperty), IEnumerable(Of Product))
            End Get
            Set(value As IEnumerable(Of Product))
                SetValue(ProductsListProperty, value)
            End Set
        End Property

        Public Shared ReadOnly WarehouseIDProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(WarehouseID), GetType(Integer),
                GetType(StockTakeItemRowControl),
                New PropertyMetadata(1, AddressOf OnWarehouseIDChanged))

        Public Property WarehouseID As Integer
            Get
                Return CInt(GetValue(WarehouseIDProperty))
            End Get
            Set(value As Integer)
                SetValue(WarehouseIDProperty, value)
            End Set
        End Property

        Public Shared ReadOnly IsLockedProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(IsLocked), GetType(Boolean),
                GetType(StockTakeItemRowControl),
                New PropertyMetadata(False))

        Public Property IsLocked As Boolean
            Get
                Return CBool(GetValue(IsLockedProperty))
            End Get
            Set(value As Boolean)
                SetValue(IsLockedProperty, value)
            End Set
        End Property

        ' ══════════════════════════════════════════════════════
        '  Events
        ' ══════════════════════════════════════════════════════

        Public Event RequestAddNewRow As EventHandler
        Public Event RequestDeleteRow As EventHandler
        Public Event AmountChanged As EventHandler

        ' ══════════════════════════════════════════════════════
        '  Initialization & DataContext Sync
        ' ══════════════════════════════════════════════════════

        Public Sub New()
            InitializeComponent()
            AddHandler DataContextChanged, AddressOf OnDataContextChangedHandler
            AddHandler Loaded, AddressOf OnLoadedHandler
        End Sub

        Private Sub OnLoadedHandler(sender As Object, e As RoutedEventArgs)
            If ProductDropdown.ItemsSource Is Nothing AndAlso ProductsList IsNot Nothing Then
                ProductDropdown.ItemsSource = ProductsList
            End If
            SyncProductFromDataContext()
        End Sub

        Private Shared Sub OnProductsListChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, StockTakeItemRowControl)
            If ctrl Is Nothing Then Return
            Dim list = TryCast(e.NewValue, IEnumerable(Of Product))
            ctrl.ProductDropdown.ItemsSource = list
            ctrl.SyncProductFromDataContext()
        End Sub

        Private Shared Sub OnWarehouseIDChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, StockTakeItemRowControl)
            If ctrl Is Nothing Then Return
            ctrl.RefreshSystemStock()
        End Sub

        Private Sub OnDataContextChangedHandler(sender As Object, e As DependencyPropertyChangedEventArgs)
            SyncProductFromDataContext()
        End Sub

        Private Sub SyncProductFromDataContext()
            Dim detail = TryCast(Me.DataContext, StockTakeDetails)
            If detail Is Nothing Then
                ProductDropdown.ClearSelection()
                Return
            End If

            If detail.ProductID > 0 Then
                If ProductsList IsNot Nothing Then
                    Dim matched = ProductsList.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                    If matched IsNot Nothing Then
                        ProductDropdown.SelectedItem = matched
                        Return
                    End If
                End If

                Dim txt = If(Not String.IsNullOrEmpty(detail.ProductName), detail.ProductName, detail.ProductCode)
                ProductDropdown.SetDisplayText(txt)
            Else
                ProductDropdown.ClearSelection()
            End If
        End Sub

        Public Sub RefreshSystemStock()
            Dim detail = TryCast(Me.DataContext, StockTakeDetails)
            If detail IsNot Nothing AndAlso detail.ProductID > 0 Then
                Try
                    detail.SystemQuantity = _inventoryService.GetStockByProduct(detail.ProductID, WarehouseID)
                Catch
                    detail.SystemQuantity = 0
                End Try

                Try
                    Dim avgCost = _inventoryService.GetAvgCostByProduct(detail.ProductID, WarehouseID)
                    If avgCost > 0 Then
                        detail.CostPrice = avgCost
                    ElseIf detail.CostPrice <= 0 AndAlso ProductsList IsNot Nothing Then
                        Dim prod = ProductsList.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                        If prod IsNot Nothing Then detail.CostPrice = prod.PurchasePrice
                    End If
                Catch
                End Try

                RaiseEvent AmountChanged(Me, EventArgs.Empty)
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Product SearchableDropdown Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub ProductDropdown_SearchChanged(sender As Object, searchText As String)
            If ProductsList Is Nothing Then Return
            If String.IsNullOrWhiteSpace(searchText) Then
                ProductDropdown.ItemsSource = ProductsList
            Else
                Dim lower = searchText.Trim().ToLower()
                Dim filtered = ProductsList.Where(Function(p) (p.ProductName IsNot Nothing AndAlso p.ProductName.ToLower().Contains(lower)) OrElse
                                                              (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower().Contains(lower))).ToList()
                ProductDropdown.ItemsSource = filtered
            End If
        End Sub

        Private Sub ProductDropdown_ItemSelected(sender As Object, item As Object)
            Dim prod = TryCast(item, Product)
            Dim detail = TryCast(Me.DataContext, StockTakeDetails)
            If prod IsNot Nothing AndAlso detail IsNot Nothing Then
                detail.ProductID = prod.ProductID
                detail.ProductCode = If(Not String.IsNullOrEmpty(prod.Barcode), prod.Barcode, prod.ProductID.ToString())
                detail.ProductName = prod.ProductName

                Try
                    detail.SystemQuantity = _inventoryService.GetStockByProduct(prod.ProductID, WarehouseID)
                Catch
                    detail.SystemQuantity = 0
                End Try

                Try
                    Dim avgCost = _inventoryService.GetAvgCostByProduct(prod.ProductID, WarehouseID)
                    detail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                Catch
                    detail.CostPrice = prod.PurchasePrice
                End Try

                If detail.ActualQuantity = 0 Then
                    detail.ActualQuantity = detail.SystemQuantity
                End If

                RaiseEvent AmountChanged(Me, EventArgs.Empty)
            End If
        End Sub

        Private Sub ProductDropdown_ConfirmedAndMoveNext(sender As Object, e As EventArgs)
            FocusActualQty()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Barcode / Code Search & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub ProductCodeBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim code = ProductCodeBox.Text.Trim()
                If Not String.IsNullOrEmpty(code) AndAlso ProductsList IsNot Nothing Then
                    Dim lower = code.ToLower()
                    Dim matched = ProductsList.FirstOrDefault(Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = lower) OrElse
                                                                          p.ProductID.ToString() = lower)
                    If matched IsNot Nothing Then
                        Dim detail = TryCast(Me.DataContext, StockTakeDetails)
                        If detail IsNot Nothing Then
                            detail.ProductID = matched.ProductID
                            detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                            detail.ProductName = matched.ProductName

                            Try
                                detail.SystemQuantity = _inventoryService.GetStockByProduct(matched.ProductID, WarehouseID)
                            Catch
                                detail.SystemQuantity = 0
                            End Try

                            Try
                                Dim avgCost = _inventoryService.GetAvgCostByProduct(matched.ProductID, WarehouseID)
                                detail.CostPrice = If(avgCost > 0, avgCost, matched.PurchasePrice)
                            Catch
                                detail.CostPrice = matched.PurchasePrice
                            End Try

                            If detail.ActualQuantity = 0 Then
                                detail.ActualQuantity = detail.SystemQuantity
                            End If

                            RaiseEvent AmountChanged(Me, EventArgs.Empty)
                        End If
                        ProductDropdown.SelectedItem = matched
                        e.Handled = True
                        FocusActualQty()
                        Return
                    End If
                End If

                ' إذا لم يُعثر على الصنف بالكود، انتقل لخانة البحث عن الصنف
                e.Handled = True
                FocusProduct()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Quantity & Cost Handling & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub RefreshStockBtn_Click(sender As Object, e As RoutedEventArgs)
            RefreshSystemStock()
        End Sub

        Private Sub ActualQtyBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, StockTakeDetails)
                If detail IsNot Nothing Then
                    detail.ActualQuantity = val
                End If
            End If
            RaiseEvent AmountChanged(Me, EventArgs.Empty)
        End Sub

        Private Sub ActualQtyBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                ActualQtyBox_LostFocus(ActualQtyBox, New RoutedEventArgs())
                FocusCostPrice()
            End If
        End Sub

        Private Sub CostPriceBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, StockTakeDetails)
                If detail IsNot Nothing Then
                    detail.CostPrice = val
                End If
            End If
            RaiseEvent AmountChanged(Me, EventArgs.Empty)
        End Sub

        Private Sub CostPriceBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                CostPriceBox_LostFocus(CostPriceBox, New RoutedEventArgs())
                DiffValueBox.Focus()
            End If
        End Sub

        Private Sub DiffValueBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                RaiseEvent RequestAddNewRow(Me, EventArgs.Empty)
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Amount Formatting, Clear on Focus & Validation
        ' ══════════════════════════════════════════════════════

        Private Sub AmountBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            tb.SelectAll()
        End Sub

        Private Sub AmountBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim text = e.Text
            If text = "." OrElse text = "," Then
                If tb.Text.Contains(".") OrElse tb.Text.Contains(",") Then
                    e.Handled = True
                    Return
                End If
                Return
            End If

            For Each ch In text
                If Not Char.IsDigit(ch) AndAlso ch <> "-"c Then
                    e.Handled = True
                    Exit Sub
                End If
            Next
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Delete Action
        ' ══════════════════════════════════════════════════════

        Private Sub DeleteButton_Click(sender As Object, e As RoutedEventArgs)
            RaiseEvent RequestDeleteRow(Me, EventArgs.Empty)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Focus Helpers
        ' ══════════════════════════════════════════════════════

        Public Sub FocusBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                ProductCodeBox.Focus()
                ProductCodeBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusProduct()
            Dispatcher.BeginInvoke(New Action(Sub()
                ProductDropdown.FocusSearchBox()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusActualQty()
            Dispatcher.BeginInvoke(New Action(Sub()
                ActualQtyBox.Focus()
                ActualQtyBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusCostPrice()
            Dispatcher.BeginInvoke(New Action(Sub()
                CostPriceBox.Focus()
                CostPriceBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

    End Class
End Namespace
