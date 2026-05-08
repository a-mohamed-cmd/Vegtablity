Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Threading
Imports Vegtablity.ViewModels

Namespace Views
    Public Class QuotePage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()

            Dim vm = TryCast(DataContext, QuoteViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
                AddHandler vm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As System.ComponentModel.PropertyChangedEventArgs)
            If e.PropertyName = "HistoryPage" Then
                AnimateGrid(dgHistory)
            ElseIf e.PropertyName = "DetailsPage" Then
                AnimateGrid(dgQuoteDetails)
            End If
        End Sub

        Private Sub AnimateGrid(grid As UIElement)
            If grid Is Nothing Then Return
            Dim fadeOut As New Media.Animation.DoubleAnimation(1, 0, New Duration(TimeSpan.FromMilliseconds(100)))
            Dim fadeIn As New Media.Animation.DoubleAnimation(0, 1, New Duration(TimeSpan.FromMilliseconds(200)))
            
            AddHandler fadeOut.Completed, Sub()
                                              grid.BeginAnimation(UIElement.OpacityProperty, fadeIn)
                                          End Sub
            grid.BeginAnimation(UIElement.OpacityProperty, fadeOut)
        End Sub

        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible

            Dim timer As New DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(sender, e)
                                       SnackbarBorder.Visibility = Visibility.Collapsed
                                       timer.Stop()
                                   End Sub
            timer.Start()
        End Sub

        Private Sub HistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Visible
        End Sub

        Private Sub CloseHistoryButton_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        Private Sub EditFromHistory_Click(sender As Object, e As RoutedEventArgs)
            HistoryModal.Visibility = Visibility.Collapsed
        End Sub

        ' --- Grid Interactions (Simulating SalesInvoicePage UX) ---
        Private Sub TextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then
                tb.SelectAll()
            End If
        End Sub

        Private Sub ProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb IsNot Nothing AndAlso e.Key = Key.Enter Then
                e.Handled = True
                MoveFocusToNextCell(cb)
            End If
        End Sub

        Private Sub ProductComboBox_DropDownOpened(sender As Object, e As EventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb IsNot Nothing Then
                cb.IsEditable = True
            End If
        End Sub

        Private Sub ProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb IsNot Nothing Then
                If cb.SelectedItem Is Nothing AndAlso Not String.IsNullOrWhiteSpace(cb.Text) Then
                    Dim vm = TryCast(DataContext, QuoteViewModel)
                    If vm IsNot Nothing Then
                        Dim match = vm.GlobalFindProduct(cb.Text)
                        If match IsNot Nothing Then
                            cb.SelectedItem = match
                        Else
                            cb.Text = ""
                        End If
                    End If
                End If
                ' Reset filter in VM so next open shows first page
                Dim qvm = TryCast(DataContext, QuoteViewModel)
                If qvm IsNot Nothing Then qvm.ProductFilter = ""
            End If
        End Sub

        Private Sub ProductComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb IsNot Nothing Then
                If cb.SelectedItem Is Nothing AndAlso Not String.IsNullOrWhiteSpace(cb.Text) Then
                    cb.Text = ""
                End If
            End If
        End Sub

        Private Sub ProductComboBox_KeyUp(sender As Object, e As KeyEventArgs)
            Dim cb = TryCast(sender, ComboBox)
            If cb IsNot Nothing AndAlso cb.IsEditable AndAlso Not String.IsNullOrEmpty(cb.Text) Then
                If e.Key = Key.Up OrElse e.Key = Key.Down OrElse e.Key = Key.Enter OrElse e.Key = Key.Escape OrElse e.Key = Key.Tab OrElse e.Key = Key.LeftShift OrElse e.Key = Key.RightShift Then
                    Return
                End If

                Dim searchText = cb.Text.ToLower()
                Dim vm = TryCast(DataContext, QuoteViewModel)
                If vm IsNot Nothing Then
                    vm.ProductFilter = searchText
                    If Not cb.IsDropDownOpen Then cb.IsDropDownOpen = True
                End If
            End If
        End Sub

        Private Sub Price_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                ' Force the binding to update before moving focus, 
                ' so the typed price is committed to the ViewModel.
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                    If binding IsNot Nothing Then binding.UpdateSource()
                End If

                e.Handled = True

                ' Auto Add New Row
                Dim vm = TryCast(DataContext, QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemCommand.CanExecute(Nothing) Then
                    vm.AddItemCommand.Execute(Nothing)

                    ' Navigate to Barcode column (index 0) of the new last row
                    Dispatcher.BeginInvoke(New Action(Sub()
                                                          Try
                                                              Dim newItem = vm.CurrentQuote.Details.LastOrDefault()
                                                              If newItem Is Nothing Then Return

                                                              Dim barcodeColumn = dgQuoteDetails.Columns(0)
                                                              dgQuoteDetails.CurrentCell = New DataGridCellInfo(newItem, barcodeColumn)
                                                              dgQuoteDetails.ScrollIntoView(newItem)

                                                              Dim row = TryCast(dgQuoteDetails.ItemContainerGenerator.ContainerFromItem(newItem), DataGridRow)
                                                              If row IsNot Nothing Then
                                                                  Dim presenter = FindVisualChild(Of Primitives.DataGridCellsPresenter)(row)
                                                                  If presenter IsNot Nothing Then
                                                                      Dim cell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(0), DataGridCell)
                                                                      If cell IsNot Nothing Then
                                                                          Dim barcodeTb = FindVisualChild(Of TextBox)(cell)
                                                                          If barcodeTb IsNot Nothing Then
                                                                              barcodeTb.Focus()
                                                                              barcodeTb.SelectAll()
                                                                          End If
                                                                      End If
                                                                  End If
                                                              End If
                                                          Catch
                                                          End Try
                                                      End Sub), System.Windows.Threading.DispatcherPriority.Render)
                End If
            End If
        End Sub

        Private Sub BarcodeSearchBox_KeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim vm = TryCast(DataContext, QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.AddItemByBarcodeCommand.CanExecute(Nothing) Then
                    vm.AddItemByBarcodeCommand.Execute(Nothing)
                End If
                e.Handled = True
            End If
        End Sub

        Private Sub BarcodeCell_KeyDown(sender As Object, e As KeyEventArgs)
            If e.Key <> Key.Enter Then Return

            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing OrElse String.IsNullOrWhiteSpace(tb.Text) Then Return

            Dim vm = TryCast(DataContext, QuoteViewModel)
            If vm Is Nothing Then Return

            ' Get the QuoteDetail bound to this row
            Dim detail = TryCast(tb.DataContext, Models.QuoteDetail)
            If detail Is Nothing Then Return

            Dim searchLower = tb.Text.Trim().ToLower()

            ' Find globally (database-wide search via ViewModel's local copy)
            Dim found = vm.GlobalFindProduct(tb.Text)

            If found IsNot Nothing Then
                detail.ProductID = found.ProductID
                detail.Barcode = found.Barcode
                detail.UnitName = found.UnitName
                detail.QuotedPrice = found.SalePrice

                ' Navigate to price column (index 3) and SelectAll after render
                Dispatcher.BeginInvoke(New Action(Sub()
                                                      Try
                                                          ' Price column is at index 4 (Barcode=0, Product=1, FallbackName=2, Unit=3, Price=4)
                                                          Dim priceColumn = dgQuoteDetails.Columns(4)
                                                          dgQuoteDetails.CurrentCell = New DataGridCellInfo(detail, priceColumn)
                                                          dgQuoteDetails.BeginEdit()

                                                          ' Find the DataGridRow for this item
                                                          Dim row = TryCast(dgQuoteDetails.ItemContainerGenerator.ContainerFromItem(detail), DataGridRow)
                                                          If row IsNot Nothing Then
                                                              Dim presenter = FindVisualChild(Of Primitives.DataGridCellsPresenter)(row)
                                                              If presenter IsNot Nothing Then
                                                                  Dim cell = TryCast(presenter.ItemContainerGenerator.ContainerFromIndex(4), DataGridCell)
                                                                  If cell IsNot Nothing Then
                                                                      Dim priceTb = FindVisualChild(Of TextBox)(cell)
                                                                      If priceTb IsNot Nothing Then
                                                                          priceTb.Focus()
                                                                          priceTb.SelectAll()
                                                                      End If
                                                                  End If
                                                              End If
                                                          End If
                                                      Catch
                                                      End Try
                                                  End Sub), System.Windows.Threading.DispatcherPriority.Render)

            Else
                ' Flash the text red as a hint
                tb.Foreground = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Colors.Red)
                Dim timer As New System.Windows.Threading.DispatcherTimer()
                timer.Interval = TimeSpan.FromMilliseconds(800)
                AddHandler timer.Tick, Sub(s, ev)
                                           tb.Foreground = New System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(&H64, &H74, &H8B))
                                           timer.Stop()
                                       End Sub
                timer.Start()
            End If

            e.Handled = True
        End Sub

        Private Sub MoveFocusToNextCell(currentControl As Control)
            Dim request As New TraversalRequest(FocusNavigationDirection.Next)
            currentControl.MoveFocus(request)
        End Sub

        ''' <summary>Walks the visual tree to find the first child of type T.</summary>
        Private Shared Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            If parent Is Nothing Then Return Nothing
            For i As Integer = 0 To Media.VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = Media.VisualTreeHelper.GetChild(parent, i)
                Dim result = TryCast(child, T)
                If result IsNot Nothing Then Return result
                Dim deeper = FindVisualChild(Of T)(child)
                If deeper IsNot Nothing Then Return deeper
            Next
            Return Nothing
        End Function

        ' ══════════════════════════════════════════════════
        '  Partner Search ComboBox Handlers
        ' ══════════════════════════════════════════════════
        Private _isFilteringPartner As Boolean = False

        Private Sub PartnerSearch_TextChanged(sender As Object, e As System.Windows.Controls.TextChangedEventArgs)
            Dim _cbCheck = TryCast(sender, System.Windows.Controls.ComboBox)
            If _cbCheck IsNot Nothing AndAlso Not _cbCheck.IsEnabled Then Return
            If _isFilteringPartner Then Return

            ' sender = ComboBox | e.OriginalSource = TextBox الداخلي
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing Then Return
            Dim tb = TryCast(e.OriginalSource, TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing Then Return

            Dim searchText = tb.Text

            _isFilteringPartner = True
            Try
                Dim settingsSvc As New Services.SettingsService()
                Dim partnerSvc As New Services.PartnerService()
                Dim compInfo = settingsSvc.GetCompanyInfo()
                Dim isUnified = If(compInfo IsNot Nothing, compInfo.UnifiedPartnerSearch, True)

                Dim results As System.Collections.Generic.List(Of Models.Partner)
                If isUnified Then
                    results = partnerSvc.SearchAllPartners(searchText.Trim())
                Else
                    results = partnerSvc.SearchPartners("Customer", searchText.Trim())
                End If

                vm.FilteredPartners.Clear()
                For Each p In results
                    vm.FilteredPartners.Add(p)
                Next

                ' WPF يمسح النص بعد CollectionChanged — نُعيده بعد انتهاء معالجته
                Dispatcher.BeginInvoke(New Action(Sub()
                    _isFilteringPartner = True
                    tb.Text = searchText
                    tb.CaretIndex = searchText.Length
                    _isFilteringPartner = False
                    If Not String.IsNullOrEmpty(searchText) AndAlso cmb.IsEnabled Then
                        cmb.IsDropDownOpen = True
                    End If
                End Sub), System.Windows.Threading.DispatcherPriority.Input)

            Finally
                _isFilteringPartner = False
            End Try
        End Sub

        Private Sub PartnerComboBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm IsNot Nothing Then
                ' إعادة عرض اسم الشريك المحدد بعد مغادرة القائمة
                If cmb.SelectedItem IsNot Nothing Then
                    Dim selected = TryCast(cmb.SelectedItem, Models.Partner)
                    If selected IsNot Nothing Then
                        Dim tb As TextBox = TryCast(cmb.Template?.FindName("PART_EditableTextBox", cmb), TextBox)
                        If tb IsNot Nothing Then tb.Text = selected.SearchText
                    End If
                End If
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date Parsing Handlers
        ' ══════════════════════════════════════════════════
        Private Sub QuoteDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If String.IsNullOrWhiteSpace(raw) Then Return

            ' قبول صيغة بدون فواصل: 01052026 → 01/05/2026
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                Dim vm = TryCast(Me.DataContext, QuoteViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentQuote IsNot Nothing Then
                    vm.CurrentQuote.QuoteDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
                ShowSnackbar("تنسيق التاريخ غير صحيح، استخدم يوم/شهر/سنة")
            End If
        End Sub

        Private Sub ExpiryDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            Dim vm = TryCast(Me.DataContext, QuoteViewModel)
            If vm Is Nothing OrElse vm.CurrentQuote Is Nothing Then Return

            If String.IsNullOrWhiteSpace(raw) Then
                vm.CurrentQuote.ExpiryDate = Nothing
                tb.Text = ""
                tb.Foreground = System.Windows.Media.Brushes.Black
                Return
            End If

            ' قبول صيغة بدون فواصل: 01052026 → 01/05/2026
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                vm.CurrentQuote.ExpiryDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
                tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy"
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
                ShowSnackbar("تنسيق التاريخ غير صحيح، استخدم يوم/شهر/سنة")
            End If
        End Sub

        ''' <summary>يبحث في الشجرة البصرية عن عنصر أب من نوع T</summary>
        Private Shared Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parent = Media.VisualTreeHelper.GetParent(child)
            While parent IsNot Nothing
                Dim result = TryCast(parent, T)
                If result IsNot Nothing Then Return result
                parent = Media.VisualTreeHelper.GetParent(parent)
            End While
            Return Nothing
        End Function
    
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
                If tb IsNot Nothing Then
                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub

        Private Sub PartnerComboBox_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim cb = TryCast(sender, ComboBox)
                If cb Is Nothing Then Return

                If cb.IsDropDownOpen Then cb.IsDropDownOpen = False
                
                Dim doMove = Sub()
                                 Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                                 Dim focusedElement = TryCast(System.Windows.Input.Keyboard.FocusedElement, System.Windows.UIElement)
                                 If focusedElement IsNot Nothing Then
                                     focusedElement.MoveFocus(request)
                                 Else
                                     cb.MoveFocus(request)
                                 End If
                             End Sub

                Dim vm = TryCast(Me.DataContext, ViewModels.QuoteViewModel)
                If vm Is Nothing Then Return
                
                If cb.SelectedItem IsNot Nothing Then
                    doMove()
                    Return
                End If
                
                Dim tb = TryCast(cb.Template.FindName("PART_EditableTextBox", cb), TextBox)
                If tb IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    Dim match As Models.Partner = Nothing
                    
                    If vm.AllPartners IsNot Nothing Then
                        match = System.Linq.Enumerable.FirstOrDefault(vm.AllPartners, Function(pt) pt.PartnerName.ToLower() = searchText OrElse pt.AccountCode = searchText)
                    End If
                    
                    If match Is Nothing AndAlso vm.FilteredPartners IsNot Nothing Then
                        match = System.Linq.Enumerable.FirstOrDefault(vm.FilteredPartners, Function(pt) pt.PartnerName.ToLower() = searchText OrElse pt.AccountCode = searchText)
                    End If
                    
                    If match Is Nothing AndAlso vm.FilteredPartners IsNot Nothing AndAlso vm.FilteredPartners.Count = 1 Then
                        match = vm.FilteredPartners(0)
                    End If
                    
                    If match IsNot Nothing Then
                        cb.SelectedItem = match
                        doMove()
                        Return
                    End If
                End If

                ShowSnackbar("الرجاء اختيار اسم المورد أو العميل الصحيح من القائمة")
            End If
        End Sub
    End Class
End Namespace