Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Threading
Imports Vegtablity.Models
Imports Vegtablity.ViewModels

Namespace Views
    Public Class StockTakePage
        Inherits UserControl

        Private _viewModel As StockTakeViewModel
        Private _isHistoryCollapsed As Boolean = False
        Private _snackbarTimer As DispatcherTimer

        Public Sub New()
            InitializeComponent()
            _viewModel = TryCast(Me.DataContext, StockTakeViewModel)
            If _viewModel IsNot Nothing Then
                AddHandler _viewModel.RequestSnackbar, AddressOf ShowSnackbar
            End If

            _snackbarTimer = New DispatcherTimer()
            _snackbarTimer.Interval = TimeSpan.FromSeconds(3)
            AddHandler _snackbarTimer.Tick, AddressOf OnSnackbarTimerTick

            ' إضافة حدث SelectionChanged يدوياً لضمان استجابة كل ضغطة
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            If HistoryListView IsNot Nothing Then
                AddHandler HistoryListView.SelectionChanged, AddressOf HistoryListView_SelectionChanged
                AddHandler HistoryListView.MouseLeftButtonUp, AddressOf HistoryListView_MouseLeftButtonUp
            End If
        End Sub

        ' يُطلَق عند تغيير التحديد بين عناصر مختلفة
        Private Sub HistoryListView_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            If _viewModel Is Nothing Then Return
            Dim selected = TryCast(HistoryListView.SelectedItem, StockTakeHeader)
            _viewModel.ForceLoadDetails(selected)
        End Sub

        ' يُطلَق عند الضغط على نفس السجل مرتين بدون تغيير التحديد
        Private Sub HistoryListView_MouseLeftButtonUp(sender As Object, e As MouseButtonEventArgs)
            If _viewModel Is Nothing Then Return
            Dim selected = TryCast(HistoryListView.SelectedItem, StockTakeHeader)
            _viewModel.ForceLoadDetails(selected)
        End Sub

        Private Sub BtnAddNew_Click(sender As Object, e As RoutedEventArgs)
            Dispatcher.BeginInvoke(New Action(Sub()
                                                  If dgDetails.Items.Count > 0 Then
                                                      dgDetails.SelectedIndex = 0
                                                      dgDetails.CurrentCell = New DataGridCellInfo(dgDetails.Items(0), dgDetails.Columns(0))
                                                      dgDetails.BeginEdit()
                                                  End If
                                              End Sub), DispatcherPriority.Input)
        End Sub

        Private Sub btnToggleHistory_Click(sender As Object, e As RoutedEventArgs)
            _isHistoryCollapsed = Not _isHistoryCollapsed
            If _isHistoryCollapsed Then
                HistoryCard.Visibility = Visibility.Collapsed
                btnToggleHistory.Content = ">>"
                btnToggleHistory.ToolTip = "إظهار السجل"
            Else
                HistoryCard.Visibility = Visibility.Visible
                btnToggleHistory.Content = "≡"
                btnToggleHistory.ToolTip = "تصغير / تكبير"
            End If
        End Sub

        ''' <summary>
        ''' عند اختيار مستودع من القائمة يتم إغلاق الـ ComboBox ونقل الفوكس لحقل الملاحظات
        ''' </summary>
        Private Sub WarehouseComboBox_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            ' نُغلق القائمة فقط إذا كان المستخدم قد فتحها فعلاً (وليس عند التهيئة البرمجية)
            If cmb IsNot Nothing AndAlso cmb.IsDropDownOpen AndAlso cmb.SelectedValue IsNot Nothing Then
                cmb.IsDropDownOpen = False
                
                ' إيقاف تفعيل الـ ComboBox بحيث يمكن اختياره مرة واحدة فقط قبل كتابة الأصناف
                If _viewModel IsNot Nothing Then
                    _viewModel.IsWarehouseEnabled = False
                End If

                Dispatcher.BeginInvoke(New Action(Sub()
                                                      Dim req As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                                                      cmb.MoveFocus(req)
                                                  End Sub), DispatcherPriority.Input)
            End If
        End Sub

        Private Sub BtnAddItem_Click(sender As Object, e As RoutedEventArgs)
            If _viewModel IsNot Nothing AndAlso _viewModel.CurrentStockTake IsNot Nothing Then
                Dim newDetail As New StockTakeDetails()
                _viewModel.AttachDetailHandler(newDetail)
                _viewModel.CurrentStockTake.Details.Add(newDetail)
                dgDetails.SelectedIndex = dgDetails.Items.Count - 1
                dgDetails.ScrollIntoView(newDetail)
                dgDetails.CurrentCell = New DataGridCellInfo(newDetail, dgDetails.Columns(0))
                dgDetails.BeginEdit()
            End If
        End Sub

        Private Sub BtnDeleteRow_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn IsNot Nothing Then
                Dim row = TryCast(btn.Tag, StockTakeDetails)
                If row IsNot Nothing AndAlso _viewModel IsNot Nothing Then
                    _viewModel.CurrentStockTake.Details.Remove(row)
                    _viewModel.CurrentStockTake.TotalDifferenceValue = _viewModel.CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)
                End If
            End If
        End Sub

        Private Sub TextBox_Loaded(sender As Object, e As RoutedEventArgs)
            Dim txt = TryCast(sender, TextBox)
            If txt IsNot Nothing Then
                txt.Focus()
                txt.SelectAll()
            End If
        End Sub

        Private Sub Barcode_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                Dim tb = TryCast(sender, TextBox)
                If tb Is Nothing Then Return
                e.Handled = True

                Dim binding = tb.GetBindingExpression(TextBox.TextProperty)
                If binding IsNot Nothing Then binding.UpdateSource()

                If Not String.IsNullOrWhiteSpace(tb.Text) Then
                    Dim searchText = tb.Text.Trim().ToLower()
                    If _viewModel IsNot Nothing AndAlso _viewModel.AvailableProducts IsNot Nothing Then
                        Dim matched = _viewModel.AvailableProducts.FirstOrDefault(
                            Function(p) (p.Barcode IsNot Nothing AndAlso p.Barcode.ToLower() = searchText) OrElse
                                        p.ProductID.ToString() = searchText)
                        If matched IsNot Nothing Then
                            Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(tb)
                            If cell IsNot Nothing Then
                                Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                                If row IsNot Nothing Then
                                    Dim detail = TryCast(row.Item, StockTakeDetails)
                                    If detail IsNot Nothing Then
                                        _viewModel.AttachDetailHandler(detail)
                                        detail.ProductID = matched.ProductID
                                        detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                                        detail.ProductName = matched.ProductName
                                    End If
                                End If
                            End If
                            MoveToNextColumn(4) ' الكمية الفعلية = العمود رقم 4
                            Return
                        End If
                    End If
                End If
                ' لم يُعثَر على الصنف — انتقل إلى عمود اختيار المنتج
                MoveToNextColumn(1) ' عمود ComboBox المنتج
            End If
        End Sub

        Private Sub Quantity_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim txt = TryCast(sender, TextBox)
                If txt IsNot Nothing Then
                    Dim bBinding = txt.GetBindingExpression(TextBox.TextProperty)
                    If bBinding IsNot Nothing Then bBinding.UpdateSource()
                End If
                MoveToNextRowAndAddIfLast()
            End If
        End Sub

        Private Sub ProductComboBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                MoveToNextColumn(2) ' Move to ActualQuantity
            End If
        End Sub

        Private Sub ProductComboBox_DropDownClosed(sender As Object, e As EventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing AndAlso cmb.SelectedValue IsNot Nothing Then
                Dim selectedID = CInt(cmb.SelectedValue)
                ' نعبئ ProductCode مباشرةً من الـ Code-Behind بدون انتظار الـ ViewModel
                Dim cell As DataGridCell = FindVisualParent(Of DataGridCell)(cmb)
                If cell IsNot Nothing Then
                    Dim row As DataGridRow = FindVisualParent(Of DataGridRow)(cell)
                    If row IsNot Nothing Then
                        Dim detail = TryCast(row.Item, StockTakeDetails)
                        If detail IsNot Nothing AndAlso _viewModel IsNot Nothing Then
                            Dim matched = _viewModel.AvailableProducts.FirstOrDefault(Function(p) p.ProductID = selectedID)
                            If matched IsNot Nothing Then
                                detail.ProductID = matched.ProductID
                                detail.ProductName = matched.ProductName
                                detail.ProductCode = If(Not String.IsNullOrEmpty(matched.Barcode), matched.Barcode, matched.ProductID.ToString())
                            End If
                        End If
                    End If
                End If
            End If

            Dispatcher.BeginInvoke(New Action(Sub()
                                                  dgDetails.CommitEdit()
                                                  MoveToNextColumn(4) ' الكمية الفعلية
                                              End Sub), DispatcherPriority.Input)
        End Sub

        Private Sub MoveToNextColumn(colIndex As Integer)
            If dgDetails.SelectedIndex >= 0 Then
                Dim item = dgDetails.SelectedItem
                dgDetails.CurrentCell = New DataGridCellInfo(item, dgDetails.Columns(colIndex))
                dgDetails.BeginEdit()
            End If
        End Sub

        Private Sub MoveToNextRowAndAddIfLast()
            If dgDetails.SelectedIndex < dgDetails.Items.Count - 1 Then
                dgDetails.SelectedIndex += 1
                Dim nextItem = dgDetails.Items(dgDetails.SelectedIndex)
                dgDetails.ScrollIntoView(nextItem)
                dgDetails.CurrentCell = New DataGridCellInfo(nextItem, dgDetails.Columns(0))
                dgDetails.BeginEdit()
            Else
                BtnAddItem_Click(Nothing, Nothing)
            End If
        End Sub

        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            Snackbar.Visibility = Visibility.Visible
            _snackbarTimer.Stop()
            _snackbarTimer.Start()
        End Sub

        Private Sub OnSnackbarTimerTick(sender As Object, e As EventArgs)
            _snackbarTimer.Stop()
            Snackbar.Visibility = Visibility.Collapsed
        End Sub

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then
                Return parent
            Else
                Return FindVisualParent(Of T)(parentObject)
            End If
        End Function

    End Class
End Namespace
