Imports System
Imports System.Text.RegularExpressions
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports System.Windows.Media.Animation
Imports Vegtablity.Models
Imports Vegtablity.ViewModels.Integrations

Namespace Views
    Partial Public Class PaymentGatewayInvoicesPage

        Private _isFilterCardExpanded As Boolean = False
        Private _snackbarTimer As System.Windows.Threading.DispatcherTimer

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnPageLoaded
        End Sub

        Private Sub OnPageLoaded(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.CustomerSelectionSynced, AddressOf OnCustomerSelectionSynced
                AddHandler vm.CustomerSelectionSynced, AddressOf OnCustomerSelectionSynced

                RemoveHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar

                RemoveHandler vm.CreateDialogStateChanged, AddressOf OnCreateDialogStateChanged
                AddHandler vm.CreateDialogStateChanged, AddressOf OnCreateDialogStateChanged

                vm.RefreshCurrentUserPermission()
            End If
        End Sub

        Private Sub OnCreateDialogStateChanged(isOpen As Boolean)
            Dispatcher.BeginInvoke(New Action(Sub()
                If isOpen Then
                    If CreateLinkModalCard IsNot Nothing Then
                        Dim fadeIn As New DoubleAnimation(0, 1, New Duration(TimeSpan.FromMilliseconds(200))) With {
                            .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
                        }
                        CreateLinkModalCard.BeginAnimation(UIElement.OpacityProperty, fadeIn)
                    End If
                    If TxtNewInvId IsNot Nothing Then
                        TxtNewInvId.Focus()
                        TxtNewInvId.SelectAll()
                    End If
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Input)
        End Sub

        Private Sub CreateLinkOverlay_MouseLeftButtonDown(sender As Object, e As MouseButtonEventArgs)
            If e.OriginalSource Is CreateLinkOverlayBorder Then
                Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
                If vm IsNot Nothing AndAlso vm.CloseCreateLinkDialogCommand IsNot Nothing Then
                    vm.CloseCreateLinkDialogCommand.Execute(Nothing)
                End If
            End If
        End Sub

        Private Sub CreateLinkOverlay_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Escape Then
                Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
                If vm IsNot Nothing AndAlso vm.CloseCreateLinkDialogCommand IsNot Nothing Then
                    vm.CloseCreateLinkDialogCommand.Execute(Nothing)
                    e.Handled = True
                End If
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  إشعار أسفل الشاشة (SnapMessage / Snackbar) للإرشاد وعرض رسائل التريجر
        ' ══════════════════════════════════════════════════════

        Public Sub ShowSnackbar(message As String, isError As Boolean)
            Dispatcher.BeginInvoke(New Action(Sub()
                If SnackbarBorder Is Nothing OrElse SnackbarText Is Nothing Then Return

                SnackbarText.Text = message
                Dim bc As New BrushConverter()
                If isError Then
                    SnackbarBorder.Background = DirectCast(bc.ConvertFromString("#991B1B"), Brush)
                    SnackbarBorder.BorderBrush = DirectCast(bc.ConvertFromString("#F87171"), Brush)
                Else
                    SnackbarBorder.Background = DirectCast(bc.ConvertFromString("#065F46"), Brush)
                    SnackbarBorder.BorderBrush = DirectCast(bc.ConvertFromString("#34D399"), Brush)
                End If

                SnackbarBorder.Visibility = Visibility.Visible

                Dim dur As New Duration(TimeSpan.FromMilliseconds(220))
                Dim ease As New CubicEase() With {.EasingMode = EasingMode.EaseOut}

                Dim fadeIn As New DoubleAnimation(0, 1, dur) With {.EasingFunction = ease}
                SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)

                If SnackbarTranslate IsNot Nothing Then
                    Dim slideUp As New DoubleAnimation(20, 0, dur) With {.EasingFunction = ease}
                    SnackbarTranslate.BeginAnimation(TranslateTransform.YProperty, slideUp)
                End If

                If _snackbarTimer Is Nothing Then
                    _snackbarTimer = New System.Windows.Threading.DispatcherTimer()
                    AddHandler _snackbarTimer.Tick, Sub(s, args)
                                                        _snackbarTimer.Stop()
                                                        HideSnackbar()
                                                    End Sub
                End If
                _snackbarTimer.Stop()
                _snackbarTimer.Interval = TimeSpan.FromSeconds(If(isError, 7.0, 4.0))
                _snackbarTimer.Start()
            End Sub))
        End Sub

        Private Sub HideSnackbar()
            If SnackbarBorder Is Nothing Then Return
            Dim dur As New Duration(TimeSpan.FromMilliseconds(200))
            Dim fadeOut As New DoubleAnimation(SnackbarBorder.Opacity, 0, dur)
            AddHandler fadeOut.Completed, Sub(s, args)
                                              SnackbarBorder.Visibility = Visibility.Collapsed
                                          End Sub
            SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
        End Sub

        Private Sub BtnCloseSnackbar_Click(sender As Object, e As RoutedEventArgs)
            If _snackbarTimer IsNot Nothing Then _snackbarTimer.Stop()
            HideSnackbar()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  حركات الفتح والإغلاق السلسة (Smooth Collapse/Expand Animations)
        ' ══════════════════════════════════════════════════════

        Private Sub BtnToggleFilterCard_Click(sender As Object, e As RoutedEventArgs)
            _isFilterCardExpanded = Not _isFilterCardExpanded
            AnimateCardToggle(FilterCardBorder, FilterChevronRotate, BtnToggleFilterCard, _isFilterCardExpanded, 10, "#F0FDF4", "#86EFAC")
        End Sub

        Private Sub AnimateCardToggle(card As Border, chevronRotate As RotateTransform, headerPillBtn As Button, expand As Boolean, bottomMargin As Double, activeBgHex As String, activeBorderHex As String)
            If card Is Nothing Then Return

            Dim duration As New Duration(TimeSpan.FromMilliseconds(240))
            Dim ease As New CubicEase() With {.EasingMode = EasingMode.EaseInOut}

            ' 1. تحريك أيقونة السهم (Chevron Rotation)
            If chevronRotate IsNot Nothing Then
                Dim angleAnim As New DoubleAnimation() With {
                    .To = If(expand, 0, 180),
                    .Duration = duration,
                    .EasingFunction = ease
                }
                chevronRotate.BeginAnimation(RotateTransform.AngleProperty, angleAnim)
            End If

            ' 2. تحديث مظهر زر الهيدر
            If headerPillBtn IsNot Nothing Then
                Dim bc As New BrushConverter()
                If expand Then
                    headerPillBtn.Background = DirectCast(bc.ConvertFromString(activeBgHex), Brush)
                    headerPillBtn.BorderBrush = DirectCast(bc.ConvertFromString(activeBorderHex), Brush)
                Else
                    headerPillBtn.Background = DirectCast(bc.ConvertFromString("#F8FAFC"), Brush)
                    headerPillBtn.BorderBrush = DirectCast(bc.ConvertFromString("#CBD5E1"), Brush)
                End If
            End If

            ' 3. تحريك الارتفاع والشفافية والهامش (Height + Opacity + Margin Animation)
            If expand Then
                card.Visibility = Visibility.Visible
                card.Margin = New Thickness(0, 0, 0, bottomMargin)
                card.BeginAnimation(FrameworkElement.HeightProperty, Nothing)
                card.Height = Double.NaN
                card.Measure(New Size(If(card.ActualWidth > 0, card.ActualWidth, 1100), Double.PositiveInfinity))
                Dim targetHeight As Double = Math.Max(60, card.DesiredSize.Height)

                Dim heightAnim As New DoubleAnimation() With {
                    .From = 0,
                    .To = targetHeight,
                    .Duration = duration,
                    .EasingFunction = ease
                }
                AddHandler heightAnim.Completed, Sub(s, args)
                                                     card.BeginAnimation(FrameworkElement.HeightProperty, Nothing)
                                                     card.Height = Double.NaN
                                                 End Sub

                Dim opacityAnim As New DoubleAnimation() With {
                    .From = 0,
                    .To = 1,
                    .Duration = duration,
                    .EasingFunction = ease
                }

                card.BeginAnimation(FrameworkElement.HeightProperty, heightAnim)
                card.BeginAnimation(UIElement.OpacityProperty, opacityAnim)
            Else
                Dim startHeight As Double = If(card.ActualHeight > 0, card.ActualHeight, card.DesiredSize.Height)
                Dim heightAnim As New DoubleAnimation() With {
                    .From = startHeight,
                    .To = 0,
                    .Duration = duration,
                    .EasingFunction = ease
                }
                AddHandler heightAnim.Completed, Sub(s, args)
                                                     card.Visibility = Visibility.Collapsed
                                                     card.Margin = New Thickness(0)
                                                     card.BeginAnimation(FrameworkElement.HeightProperty, Nothing)
                                                     card.Height = Double.NaN
                                                 End Sub

                Dim opacityAnim As New DoubleAnimation() With {
                    .From = 1,
                    .To = 0,
                    .Duration = duration,
                    .EasingFunction = ease
                }

                card.BeginAnimation(FrameworkElement.HeightProperty, heightAnim)
                card.BeginAnimation(UIElement.OpacityProperty, opacityAnim)
            End If
        End Sub

        Private Sub OnCustomerSelectionSynced(partner As Partner, customName As String)
            Dispatcher.BeginInvoke(New Action(Sub()
                If CustomerDropdown Is Nothing Then Return
                If partner IsNot Nothing Then
                    CustomerDropdown.SelectedItem = partner
                ElseIf Not String.IsNullOrWhiteSpace(customName) Then
                    CustomerDropdown.SetDisplayText(customName)
                Else
                    CustomerDropdown.ClearSelection()
                End If
            End Sub), System.Windows.Threading.DispatcherPriority.Loaded)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Customer SearchableDropdown (مسجل أو غير مسجل)
        ' ══════════════════════════════════════════════════════

        Private Sub CustomerDropdown_SearchChanged(sender As Object, searchText As String)
            Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
            If vm IsNot Nothing Then
                vm.ApplyCustomerFilter(searchText)
            End If
        End Sub

        Private Sub CustomerDropdown_ItemSelected(sender As Object, item As Object)
            Dim selected = TryCast(item, Partner)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
            If vm IsNot Nothing Then
                vm.OnCustomerSelected(selected)
            End If
        End Sub

        Private Sub CustomerDropdown_MoveNext(sender As Object, e As EventArgs)
            If TxtCustomerPhone IsNot Nothing Then
                TxtCustomerPhone.Focus()
                TxtCustomerPhone.SelectAll()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  أدوات إدخال المبالغ والأرقام (نفس نمط المشروع الموحد)
        ' ══════════════════════════════════════════════════════

        Private Sub AmountBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim txt = tb.Text.Trim()
            If txt = "0" OrElse txt = "0.0" OrElse txt = "0.00" OrElse txt = "0.000" OrElse txt = "0.0000" Then
                tb.Text = ""
            Else
                tb.SelectAll()
            End If
        End Sub

        Private Sub TextBox_SelectAllGotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub DecimalBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim newText = tb.Text.Substring(0, tb.SelectionStart) &
                          e.Text &
                          tb.Text.Substring(tb.SelectionStart + tb.SelectionLength)
            Dim isValid = Regex.IsMatch(newText, "^\d*\.?\d*$")
            e.Handled = Not isValid
        End Sub

        Private Sub DecimalBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim isDecimalKey = (e.Key = Key.OemPeriod OrElse
                                e.Key = Key.Decimal OrElse
                                e.Key = Key.OemComma)
            If isDecimalKey Then
                If Not tb.Text.Contains(".") Then
                    Dim pos = tb.SelectionStart
                    Dim current = tb.Text.Remove(pos, tb.SelectionLength)
                    tb.Text = current.Insert(pos, ".")
                    tb.SelectionStart = pos + 1
                End If
                e.Handled = True
            ElseIf e.Key = Key.Enter Then
                e.Handled = True
                Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                tb.MoveFocus(req)
            End If
        End Sub

        Private Sub DecimalBox_Pasting(sender As Object, e As DataObjectPastingEventArgs)
            If e.DataObject.GetDataPresent(GetType(String)) Then
                Dim pastedText = CStr(e.DataObject.GetData(GetType(String)))
                If Not Regex.IsMatch(pastedText, "^\d*\.?\d*$") Then
                    e.CancelCommand()
                End If
            Else
                e.CancelCommand()
            End If
        End Sub

        Private Sub IntegerBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            For Each ch In e.Text
                If Not Char.IsDigit(ch) Then
                    e.Handled = True
                    Return
                End If
            Next
        End Sub

        Private Sub PhoneBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            For Each ch In e.Text
                If Not (Char.IsDigit(ch) OrElse ch = "+"c OrElse ch = " "c) Then
                    e.Handled = True
                    Return
                End If
            Next
        End Sub

        Private Sub InvIdBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
                If vm IsNot Nothing AndAlso vm.NewInvId > 0 Then
                    vm.TryAutoFillFromInvoice(vm.NewInvId)
                End If
                If TxtNewAmount IsNot Nothing Then
                    TxtNewAmount.Focus()
                    TxtNewAmount.SelectAll()
                End If
            End If
        End Sub

        Private Sub InvIdBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
            If vm IsNot Nothing AndAlso vm.NewInvId > 0 Then
                vm.TryAutoFillFromInvoice(vm.NewInvId)
            End If
        End Sub

        Private Sub SubInvIdBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
                If vm IsNot Nothing AndAlso vm.SubInvIdInput > 0 Then
                    vm.TryAutoFillSubInvoiceAmount(vm.SubInvIdInput)
                End If
                If TxtSubInvAmount IsNot Nothing Then
                    TxtSubInvAmount.Focus()
                    TxtSubInvAmount.SelectAll()
                End If
            End If
        End Sub

        Private Sub SubInvIdBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
            If vm IsNot Nothing AndAlso vm.SubInvIdInput > 0 Then
                vm.TryAutoFillSubInvoiceAmount(vm.SubInvIdInput)
            End If
        End Sub

        Private Sub SearchBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim vm = TryCast(Me.DataContext, PaymentGatewayInvoicesViewModel)
                If vm IsNot Nothing AndAlso vm.SearchCommand IsNot Nothing Then
                    vm.SearchCommand.Execute(Nothing)
                End If
            End If
        End Sub

    End Class
End Namespace
