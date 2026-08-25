Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Threading
Imports System.Windows.Media.Animation
Imports Vegtablity.ViewModels
Imports Vegtablity.Models
Imports Vegtablity.Controls

Namespace Views
    Public Class WastagePage
        Inherits UserControl

        Private _isSidebarVisible As Boolean = True
        Private _isFilterVisible As Boolean = True

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf Page_Loaded
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            RemoveHandler Me.Loaded, AddressOf Page_Loaded
            Dim vm = TryCast(Me.DataContext, WastageViewModel)
            If vm IsNot Nothing Then
                AddHandler vm.RequestSnackbar, AddressOf ShowSnackbar
            End If
        End Sub

        ' =====================================================
        ' Snackbar Notification
        ' =====================================================
        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = System.Windows.Visibility.Visible
            Dim timer As New DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(s, e)
                                       SnackbarBorder.Visibility = System.Windows.Visibility.Collapsed
                                       DirectCast(s, DispatcherTimer).Stop()
                                   End Sub
            timer.Start()
        End Sub

        ' =====================================================
        ' Sidebar & Filter Toggle with Animations
        ' =====================================================
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

            btnToggleHistory.ToolTip = If(_isSidebarVisible, "إخفاء سجل التوالف", "إظهار سجل التوالف")
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

        ' =====================================================
        ' Focus Last Row Barcode
        ' =====================================================
        Private Sub FocusLastRowBarcode()
            Dispatcher.BeginInvoke(New Action(Sub()
                If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                    Dim lastIndex = DetailsItemsControl.Items.Count - 1
                    Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                    If container IsNot Nothing Then
                        Dim rowCtrl = FindVisualChild(Of Controls.WastageItemRowControl)(container)
                        If rowCtrl IsNot Nothing Then
                            rowCtrl.FocusBarcode()
                        End If
                    End If
                End If
            End Sub), DispatcherPriority.Background)
        End Sub

        Private Sub BtnAddItem_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, WastageViewModel)
            If vm IsNot Nothing Then
                vm.AddItem()
            End If
            FocusLastRowBarcode()
        End Sub

        ' =====================================================
        ' WastageItemRowControl Event Handlers
        ' =====================================================

        Private Sub WastageItemRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, WastageViewModel)
            If vm IsNot Nothing Then
                vm.AddItem()
                FocusLastRowBarcode()
            End If
        End Sub

        Private Sub WastageItemRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.WastageItemRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.WastageDetails)
            Dim vm = TryCast(Me.DataContext, WastageViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing AndAlso vm.CurrentWastage IsNot Nothing AndAlso vm.CurrentWastage.Details IsNot Nothing Then
                vm.CurrentWastage.Details.Remove(detail)
                vm.CurrentWastage.TotalValue = vm.CurrentWastage.Details.Sum(Function(d) d.TotalCost)
            End If
        End Sub

        Private Sub WastageItemRow_AmountChanged(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, WastageViewModel)
            If vm IsNot Nothing AndAlso vm.CurrentWastage IsNot Nothing AndAlso vm.CurrentWastage.Details IsNot Nothing Then
                vm.CurrentWastage.TotalValue = vm.CurrentWastage.Details.Sum(Function(d) d.TotalCost)
            End If
        End Sub

        ' =====================================================
        ' Visual Tree Helpers
        ' =====================================================
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
