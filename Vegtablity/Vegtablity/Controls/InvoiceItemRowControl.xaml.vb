Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Linq
Imports Vegtablity.Models

Namespace Controls
    Public Class InvoiceItemRowControl
        Inherits UserControl

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly ProductsListProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(ProductsList), GetType(IEnumerable(Of Product)),
                GetType(InvoiceItemRowControl),
                New PropertyMetadata(Nothing, AddressOf OnProductsListChanged))

        Public Property ProductsList As IEnumerable(Of Product)
            Get
                Return CType(GetValue(ProductsListProperty), IEnumerable(Of Product))
            End Get
            Set(value As IEnumerable(Of Product))
                SetValue(ProductsListProperty, value)
            End Set
        End Property

        Public Shared ReadOnly IsLockedProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(IsLocked), GetType(Boolean),
                GetType(InvoiceItemRowControl),
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
            Dim ctrl = TryCast(d, InvoiceItemRowControl)
            If ctrl Is Nothing Then Return
            Dim list = TryCast(e.NewValue, IEnumerable(Of Product))
            ctrl.ProductDropdown.ItemsSource = list
            ctrl.SyncProductFromDataContext()
        End Sub

        Private Sub OnDataContextChangedHandler(sender As Object, e As DependencyPropertyChangedEventArgs)
            SyncProductFromDataContext()
        End Sub

        Private Sub SyncProductFromDataContext()
            Dim detail = TryCast(Me.DataContext, InvoiceDetail)
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

                Dim txt = If(Not String.IsNullOrEmpty(detail.ProductName), detail.ProductName, detail.Barcode)
                ProductDropdown.SetDisplayText(txt)
            Else
                ProductDropdown.ClearSelection()
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
            Dim detail = TryCast(Me.DataContext, InvoiceDetail)
            If prod IsNot Nothing AndAlso detail IsNot Nothing Then
                detail.ProductID = prod.ProductID
                detail.Barcode = prod.Barcode
                detail.ProductName = prod.ProductName
                detail.ProductNameEn = prod.ProductNameEn
                detail.UnitName = prod.UnitName
            End If
        End Sub

        Private Sub ProductDropdown_ConfirmedAndMoveNext(sender As Object, e As EventArgs)
            FocusQuantity()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Barcode Search & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub BarcodeBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim code = BarcodeBox.Text.Trim()
                If Not String.IsNullOrEmpty(code) AndAlso ProductsList IsNot Nothing Then
                    Dim lower = code.ToLower()
                    Dim matched = ProductsList.FirstOrDefault(Function(p) p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = lower)
                    If matched IsNot Nothing Then
                        Dim detail = TryCast(Me.DataContext, InvoiceDetail)
                        If detail IsNot Nothing Then
                            detail.ProductID = matched.ProductID
                            detail.Barcode = matched.Barcode
                            detail.ProductName = matched.ProductName
                            detail.ProductNameEn = matched.ProductNameEn
                            detail.UnitName = matched.UnitName
                        End If
                        ProductDropdown.SelectedItem = matched
                        e.Handled = True
                        FocusQuantity()
                        Return
                    End If
                End If

                ' إذا لم يُعثر على الصنف بالباركود، انتقل لخانة البحث عن الصنف
                e.Handled = True
                FocusProduct()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Quantity & Price Handling & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub QuantityBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, InvoiceDetail)
                If detail IsNot Nothing AndAlso detail.Quantity <> val Then
                    detail.Quantity = val
                    RaiseEvent AmountChanged(Me, EventArgs.Empty)
                End If
            End If
        End Sub

        Private Sub QuantityBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim val As Decimal = 0
                Dim txt = QuantityBox.Text.Trim().Replace(",", ".")
                If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                    Dim detail = TryCast(Me.DataContext, InvoiceDetail)
                    If detail IsNot Nothing AndAlso detail.Quantity <> val Then
                        detail.Quantity = val
                        RaiseEvent AmountChanged(Me, EventArgs.Empty)
                    End If
                End If
                FocusUnitPrice()
            End If
        End Sub

        Private Sub UnitPriceBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, InvoiceDetail)
                If detail IsNot Nothing AndAlso detail.UnitPrice <> val Then
                    detail.UnitPrice = val
                    RaiseEvent AmountChanged(Me, EventArgs.Empty)
                End If
            End If
        End Sub

        Private Sub UnitPriceBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim val As Decimal = 0
                Dim txt = UnitPriceBox.Text.Trim().Replace(",", ".")
                If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                    Dim detail = TryCast(Me.DataContext, InvoiceDetail)
                    If detail IsNot Nothing AndAlso detail.UnitPrice <> val Then
                        detail.UnitPrice = val
                        RaiseEvent AmountChanged(Me, EventArgs.Empty)
                    End If
                End If
                TotalPriceBox.Focus()
            End If
        End Sub

        Private Sub TotalPriceBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
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
                If Not Char.IsDigit(ch) Then
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
                BarcodeBox.Focus()
                BarcodeBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusProduct()
            Dispatcher.BeginInvoke(New Action(Sub()
                ProductDropdown.FocusSearchBox()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusQuantity()
            Dispatcher.BeginInvoke(New Action(Sub()
                QuantityBox.Focus()
                QuantityBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusUnitPrice()
            Dispatcher.BeginInvoke(New Action(Sub()
                UnitPriceBox.Focus()
                UnitPriceBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

    End Class
End Namespace
