Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media.Animation
Imports System.Text.RegularExpressions
Imports Vegtablity.Models


Namespace Views
    Partial Public Class InventoryPage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            ' Animate filters grid
            Dim slideAnimation As New DoubleAnimation With {
                .From = 20,
                .To = 0,
                .Duration = TimeSpan.FromSeconds(0.4),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
            }
            Dim fadeAnimation As New DoubleAnimation With {
                .From = 0,
                .To = 1,
                .Duration = TimeSpan.FromSeconds(0.4)
            }
            
            FiltersGrid.RenderTransform.BeginAnimation(TranslateTransform.YProperty, slideAnimation)
            FiltersGrid.BeginAnimation(OpacityProperty, fadeAnimation)
        End Sub

        ' --- Staggered DataGrid Row Animation ---
        Private Sub DgProducts_LoadingRow(sender As Object, e As DataGridRowEventArgs)
            e.Row.Opacity = 0
            e.Row.RenderTransform = New TranslateTransform(0, 20)

            Dim fadeAnim As New DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(400))
            Dim slideAnim As New DoubleAnimation(20, 0, TimeSpan.FromMilliseconds(400)) With {
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
            }

            ' Staggered delay based on visible index
            Dim delay As Integer = e.Row.GetIndex() * 40
            fadeAnim.BeginTime = TimeSpan.FromMilliseconds(delay)
            slideAnim.BeginTime = TimeSpan.FromMilliseconds(delay)

            e.Row.BeginAnimation(OpacityProperty, fadeAnim)
            e.Row.RenderTransform.BeginAnimation(TranslateTransform.YProperty, slideAnim)
        End Sub

        ' --- Popup / Flyout Logic ---
        Private Sub NewProductBtn_Click(sender As Object, e As RoutedEventArgs)
            ' Trigger the ViewModels New command to clear fields
            If DataContext IsNot Nothing AndAlso TypeOf DataContext Is ViewModels.InventoryViewModel Then
                Dim vm = CType(DataContext, ViewModels.InventoryViewModel)
                If vm.NewProductCommand.CanExecute(Nothing) Then
                    vm.NewProductCommand.Execute(Nothing)
                End If
            End If
            ShowPopup()
        End Sub

        Private Sub EditBtn_Click(sender As Object, e As RoutedEventArgs)
            ' DataGrid SelectedItem is already bound to ViewModel, just show popup
            ShowPopup()
        End Sub

        Private Sub ShowPopup()
            OverlayGrid.Visibility = Visibility.Visible
            Dim sb = TryCast(FindResource("SlideInRight"), Storyboard)
            If sb IsNot Nothing Then
                sb.Begin()
            End If
        End Sub

        Private Sub ClosePopup_Click(sender As Object, e As RoutedEventArgs)
            ClosePopup()
        End Sub

        Private Sub Overlay_MouseDown(sender As Object, e As MouseButtonEventArgs)
            ClosePopup()
        End Sub

        Private Sub ClosePopup()
            ' Slide out animation before collapsing
            Dim slideOutAnim As New DoubleAnimation With {
                .From = 0,
                .To = 500,
                .Duration = TimeSpan.FromSeconds(0.3),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseIn}
            }

            AddHandler slideOutAnim.Completed, Sub(s, a)
                                                   OverlayGrid.Visibility = Visibility.Collapsed
                                               End Sub

            EditPanel.RenderTransform.BeginAnimation(TranslateTransform.XProperty, slideOutAnim)
        End Sub


        ' --- Product Card ---
        Private Sub ProductCardBtn_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing OrElse btn.DataContext Is Nothing Then Return

            Dim selectedProd = TryCast(btn.DataContext, Models.Product)
            If selectedProd Is Nothing Then Return

            ' Create new instance of the Control
            Dim cardControl As New ProductCardControl()
            
            ' Setup ViewModel
            Dim cardVM As New ViewModels.ProductCardViewModel()
            cardVM.ProductID = selectedProd.ProductID
            cardVM.ProductName = selectedProd.ProductName
            cardVM.Barcode = If(selectedProd.Barcode, "")
            
            ' Wire navigation action — فتح الفاتورة الأصلية
            cardVM.RequestNavigateToInvoiceAction = Sub(invID, invTypeCode)
                                                        ' 1. إغلاق البطاقة أولاً
                                                        ProductCardOverlay.Visibility = Visibility.Collapsed
                                                        ProductCardContainer.Child = Nothing

                                                        ' 2. الانتقال لصفحة الفاتورة — مع حفظ الصفحة الحالية في الـ stack
                                                        Dim parent = TryCast(Window.GetWindow(Me), DashboardWindow)
                                                        If parent Is Nothing Then Return

                                                        If invTypeCode = 1 Then  ' Sales
                                                            Dim page = New SalesInvoicePage()
                                                            Dim vm = TryCast(page.DataContext, ViewModels.SalesInvoiceViewModel)
                                                            vm?.LoadInvoice(invID)
                                                            parent.NavigateTo(page, keepCurrentInStack:=True)
                                                        ElseIf invTypeCode = 2 Then                     ' Purchase
                                                            Dim page = New PurchaseInvoicePage()
                                                            Dim vm = TryCast(page.DataContext, ViewModels.PurchaseInvoiceViewModel)
                                                            vm?.LoadInvoice(invID)
                                                            parent.NavigateTo(page, keepCurrentInStack:=True)
                                                        ElseIf invTypeCode = 3 Then                     ' Wastage
                                                            Dim page = New WastagePage()
                                                            Dim vm = TryCast(page.DataContext, ViewModels.WastageViewModel)
                                                            If vm IsNot Nothing Then
                                                                vm.SelectedWastage = New WastageHeader() With {.WastageID = invID}
                                                            End If
                                                            parent.NavigateTo(page, keepCurrentInStack:=True)
                                                        ElseIf invTypeCode = 4 Then                     ' StockTake
                                                            Dim page = New StockTakePage()
                                                            Dim vm = TryCast(page.DataContext, ViewModels.StockTakeViewModel)
                                                            If vm IsNot Nothing Then
                                                                vm.SelectedStockTake = New StockTakeHeader() With {.StockTakeID = invID}
                                                            End If
                                                            parent.NavigateTo(page, keepCurrentInStack:=True)
                                                        End If
                                                    End Sub

            cardControl.DataContext = cardVM
            
            ' Listen to close event
            AddHandler cardControl.OnCloseRequested, Sub(s, args)
                                                         ProductCardOverlay.Visibility = Visibility.Collapsed
                                                         ProductCardContainer.Child = Nothing ' Clear to free memory
                                                     End Sub

            ' Show Overlay
            ProductCardContainer.Child = cardControl
            ProductCardOverlay.Visibility = Visibility.Visible
        End Sub

        ' --- Decimal Input Validation ---
        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim textBox = TryCast(sender, TextBox)
            If textBox Is Nothing Then Return

            ' السماح بالأرقام والنقاط والفواصل فقط
            If Not System.Text.RegularExpressions.Regex.IsMatch(e.Text, "^[0-9\.\,]+$") Then
                e.Handled = True
                Return
            End If

            ' منع إدخال أكثر من علامة عشرية واحدة
            Dim isDecimalChar = (e.Text = "." OrElse e.Text = ",")
            If isDecimalChar AndAlso (textBox.Text.Contains(".") OrElse textBox.Text.Contains(",")) Then
                e.Handled = True
            End If
        End Sub

        Private Sub DecimalBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            ' منع المسافة
            If e.Key = Key.Space Then
                e.Handled = True
            End If
        End Sub

        Private Sub DecimalBox_Pasting(sender As Object, e As DataObjectPastingEventArgs)
            If e.DataObject.GetDataPresent(GetType(String)) Then
                Dim text As String = CStr(e.DataObject.GetData(GetType(String)))
                If Not System.Text.RegularExpressions.Regex.IsMatch(text, "^[0-9]+[\.\,]?[0-9]*$") Then
                    e.CancelCommand()
                End If
            Else
                e.CancelCommand()
            End If
        End Sub

    End Class
End Namespace
