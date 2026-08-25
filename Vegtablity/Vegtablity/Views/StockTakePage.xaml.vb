Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Threading
Imports System.Windows.Media.Animation
Imports Vegtablity.Models
Imports Vegtablity.ViewModels
Imports Vegtablity.Controls

Namespace Views
    Public Class StockTakePage
        Inherits UserControl

        Private _viewModel As StockTakeViewModel
        Private _isSidebarVisible As Boolean = True
        Private _isFilterVisible As Boolean = True
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

            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            If HistoryListView IsNot Nothing Then
                AddHandler HistoryListView.SelectionChanged, AddressOf HistoryListView_SelectionChanged
                AddHandler HistoryListView.MouseLeftButtonUp, AddressOf HistoryListView_MouseLeftButtonUp
            End If
        End Sub

        Private Sub HistoryListView_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            If _viewModel Is Nothing Then Return
            Dim selected = TryCast(HistoryListView.SelectedItem, StockTakeHeader)
            _viewModel.ForceLoadDetails(selected)
        End Sub

        Private Sub HistoryListView_MouseLeftButtonUp(sender As Object, e As MouseButtonEventArgs)
            If _viewModel Is Nothing Then Return
            Dim selected = TryCast(HistoryListView.SelectedItem, StockTakeHeader)
            _viewModel.ForceLoadDetails(selected)
        End Sub

        Private Sub BtnAddNew_Click(sender As Object, e As RoutedEventArgs)
            FocusLastRowBarcode()
        End Sub

        Private Sub btnToggleHistory_Click(sender As Object, e As RoutedEventArgs)
            _isSidebarVisible = Not _isSidebarVisible

            Dim targetWidth As Double = If(_isSidebarVisible, 350, 0)
            Dim widthAnim As New DoubleAnimation() With {
                .To = targetWidth,
                .Duration = New Duration(TimeSpan.FromMilliseconds(300)),
                .EasingFunction = New CubicEase() With {.EasingMode = If(_isSidebarVisible, EasingMode.EaseOut, EasingMode.EaseIn)}
            }
            HistoryCardBorder.BeginAnimation(Border.MaxWidthProperty, widthAnim)

            Dim opacityAnim As New DoubleAnimation() With {
                .To = If(_isSidebarVisible, 1.0, 0.0),
                .Duration = New Duration(TimeSpan.FromMilliseconds(250)),
                .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseInOut}
            }
            HistoryCardBorder.BeginAnimation(UIElement.OpacityProperty, opacityAnim)

            btnToggleHistory.ToolTip = If(_isSidebarVisible, "إخفاء سجل الجرد", "إظهار سجل الجرد")
        End Sub

        Private Sub btnToggleFilter_Click(sender As Object, e As RoutedEventArgs)
            _isFilterVisible = Not _isFilterVisible

            If _isFilterVisible Then
                FilterCardBorder.Visibility = Visibility.Visible
                Dim fadeIn As New DoubleAnimation() With {
                    .From = 0.0,
                    .To = 1.0,
                    .Duration = New Duration(TimeSpan.FromMilliseconds(200)),
                    .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseOut}
                }
                FilterCardBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)
                btnToggleFilter.Content = "🔍 تصفية ▼"
            Else
                Dim fadeOut As New DoubleAnimation() With {
                    .From = 1.0,
                    .To = 0.0,
                    .Duration = New Duration(TimeSpan.FromMilliseconds(150)),
                    .EasingFunction = New CubicEase() With {.EasingMode = EasingMode.EaseIn}
                }
                AddHandler fadeOut.Completed, Sub(s, ev)
                                                  FilterCardBorder.Visibility = Visibility.Collapsed
                                              End Sub
                FilterCardBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
                btnToggleFilter.Content = "🔍 تصفية ◀"
            End If
        End Sub

        Private Sub WarehouseComboBox_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim cmb = TryCast(sender, ComboBox)
            If cmb IsNot Nothing AndAlso cmb.IsDropDownOpen AndAlso cmb.SelectedValue IsNot Nothing Then
                cmb.IsDropDownOpen = False
                
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
                FocusLastRowBarcode()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  StockTakeItemRowControl Event Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub StockTakeItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            If _viewModel IsNot Nothing AndAlso _viewModel.CurrentStockTake IsNot Nothing Then
                Dim newDetail As New StockTakeDetails()
                _viewModel.AttachDetailHandler(newDetail)
                _viewModel.CurrentStockTake.Details.Add(newDetail)
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub StockTakeItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, StockTakeItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, StockTakeDetails)
            If detail IsNot Nothing AndAlso _viewModel IsNot Nothing AndAlso _viewModel.CurrentStockTake IsNot Nothing Then
                _viewModel.CurrentStockTake.Details.Remove(detail)
                _viewModel.CurrentStockTake.TotalDifferenceValue = _viewModel.CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)
            End If
        End Sub

        Private Sub StockTakeItemRow_AmountChanged(sender As Object, e As EventArgs)
            If _viewModel IsNot Nothing AndAlso _viewModel.CurrentStockTake IsNot Nothing Then
                _viewModel.CurrentStockTake.TotalDifferenceValue = _viewModel.CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)
            End If
        End Sub

        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                    Dim lastIndex = DetailsItemsControl.Items.Count - 1
                    Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                    If container IsNot Nothing Then
                        Dim rowCtrl = FindVisualChild(Of StockTakeItemRowControl)(container)
                        If rowCtrl IsNot Nothing Then
                            rowCtrl.FocusBarcode()
                        End If
                    End If
                End If
            End Sub), DispatcherPriority.Background)
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

        Private Function FindVisualChild(Of T As DependencyObject)(parent As DependencyObject) As T
            If parent Is Nothing Then Return Nothing
            For i As Integer = 0 To System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i)
                If child IsNot Nothing AndAlso TypeOf child Is T Then
                    Return DirectCast(child, T)
                Else
                    Dim childOfChild As T = FindVisualChild(Of T)(child)
                    If childOfChild IsNot Nothing Then Return childOfChild
                End If
            Next
            Return Nothing
        End Function

    End Class
End Namespace
