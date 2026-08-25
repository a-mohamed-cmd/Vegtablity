Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Linq
Imports Vegtablity.Models

Namespace Controls
    Public Class QuoteItemRowControl
        Inherits UserControl

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly ProductsListProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(ProductsList), GetType(IEnumerable(Of Product)),
                GetType(QuoteItemRowControl),
                New PropertyMetadata(Nothing, AddressOf OnProductsListChanged))

        Public Property ProductsList As IEnumerable(Of Product)
            Get
                Return CType(GetValue(ProductsListProperty), IEnumerable(Of Product))
            End Get
            Set(value As IEnumerable(Of Product))
                SetValue(ProductsListProperty, value)
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
            Dim ctrl = TryCast(d, QuoteItemRowControl)
            If ctrl Is Nothing Then Return
            Dim list = TryCast(e.NewValue, IEnumerable(Of Product))
            ctrl.ProductDropdown.ItemsSource = list
            ctrl.SyncProductFromDataContext()
        End Sub

        Private Sub OnDataContextChangedHandler(sender As Object, e As DependencyPropertyChangedEventArgs)
            SyncProductFromDataContext()
        End Sub

        Private Sub SyncProductFromDataContext()
            Dim qDetail = TryCast(Me.DataContext, QuoteDetail)
            Dim pqDetail = TryCast(Me.DataContext, PurchaseQuoteDetail)

            Dim prodId = 0
            Dim prodName = ""
            Dim barcode = ""

            If qDetail IsNot Nothing Then
                prodId = qDetail.ProductID
                prodName = qDetail.ProductName
                barcode = qDetail.Barcode
            ElseIf pqDetail IsNot Nothing Then
                prodId = pqDetail.ProductID
                prodName = pqDetail.ProductName
                barcode = pqDetail.Barcode
            Else
                ProductDropdown.ClearSelection()
                Return
            End If

            If prodId > 0 Then
                If ProductsList IsNot Nothing Then
                    Dim matched = ProductsList.FirstOrDefault(Function(p) p.ProductID = prodId)
                    If matched IsNot Nothing Then
                        ProductDropdown.SelectedItem = matched
                        Return
                    End If
                End If

                Dim txt = If(Not String.IsNullOrEmpty(prodName), prodName, barcode)
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
            If prod Is Nothing Then Return
            SetProductOnDetail(prod)
        End Sub

        Private Sub SetProductOnDetail(prod As Product)
            Dim qDetail = TryCast(Me.DataContext, QuoteDetail)
            If qDetail IsNot Nothing Then
                qDetail.ProductID = prod.ProductID
                qDetail.Barcode = prod.Barcode
                qDetail.ProductName = prod.ProductName
                qDetail.UnitName = prod.UnitName
                If qDetail.QuotedPrice = 0 Then
                    qDetail.QuotedPrice = prod.SalePrice
                End If
                Return
            End If

            Dim pqDetail = TryCast(Me.DataContext, PurchaseQuoteDetail)
            If pqDetail IsNot Nothing Then
                pqDetail.ProductID = prod.ProductID
                pqDetail.Barcode = prod.Barcode
                pqDetail.ProductName = prod.ProductName
                pqDetail.UnitName = prod.UnitName
                If pqDetail.UnitPrice = 0 Then
                    pqDetail.UnitPrice = prod.PurchasePrice
                End If
                Return
            End If
        End Sub

        Private Sub ProductDropdown_ConfirmedAndMoveNext(sender As Object, e As EventArgs)
            FocusQuotedPrice()
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
                        SetProductOnDetail(matched)
                        ProductDropdown.SelectedItem = matched
                        e.Handled = True
                        FocusQuotedPrice()
                        Return
                    End If
                End If

                ' إذا لم يُعثر على الصنف بالباركود، انتقل لخانة البحث عن الصنف
                e.Handled = True
                FocusProduct()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Quoted Price Handling & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub QuotedPriceBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim qDetail = TryCast(Me.DataContext, QuoteDetail)
                If qDetail IsNot Nothing Then
                    qDetail.QuotedPrice = val
                End If
                Dim pqDetail = TryCast(Me.DataContext, PurchaseQuoteDetail)
                If pqDetail IsNot Nothing Then
                    pqDetail.UnitPrice = val
                End If
            End If
            RaiseEvent AmountChanged(Me, EventArgs.Empty)
        End Sub

        Private Sub QuotedPriceBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                QuotedPriceBox_LostFocus(QuotedPriceBox, New RoutedEventArgs())
                RaiseEvent RequestAddNewRow(Me, EventArgs.Empty)
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Amount Formatting & Validation
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

        Public Sub FocusQuotedPrice()
            Dispatcher.BeginInvoke(New Action(Sub()
                QuotedPriceBox.Focus()
                QuotedPriceBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

    End Class
End Namespace
