Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media.Animation

Namespace Views
    Public Class ReportsPage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf OnPageLoaded
        End Sub

        Private Sub OnPageLoaded(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.ReportsViewModel)
            If vm IsNot Nothing Then
                ' Ensure we only subscribe once
                RemoveHandler vm.ReportLoaded, AddressOf OnReportLoaded
                AddHandler vm.ReportLoaded, AddressOf OnReportLoaded
            End If
            PlayFadeAnimation()
        End Sub

        Private Sub OnReportLoaded(sender As Object, e As EventArgs)
            PlayFadeAnimation()
        End Sub

        Private Sub PlayFadeAnimation()
            Dim sb As Storyboard = CType(Me.FindResource("FadeInStoryboard"), Storyboard)
            If sb IsNot Nothing AndAlso ReportGridContainer IsNot Nothing Then
                ' Dispatcher ensures UI is updated before animation starts
                Dispatcher.BeginInvoke(New Action(Sub()
                                                      sb.Begin(ReportGridContainer)
                                                  End Sub), System.Windows.Threading.DispatcherPriority.Background)
            End If
        End Sub

        Private Sub ContentGrid_Loaded(sender As Object, e As RoutedEventArgs)
            ' Handled by OnPageLoaded and OnReportLoaded now
        End Sub

        Private Sub ExportPdf_Click(sender As Object, e As RoutedEventArgs)
            Dim vm As ViewModels.ReportsViewModel = TryCast(Me.DataContext, ViewModels.ReportsViewModel)
            If vm Is Nothing Then Return

            Dim currentTabName = CType(CType(Me.FindName("TabControl"), TabControl)?.SelectedItem, TabItem)?.Header?.ToString()
            Dim activeGrid = GetActiveDataGrid(vm.SelectedReportTab)
            If activeGrid IsNot Nothing Then
                Helpers.ReportExporter.ExportDataGridToPdf(activeGrid, currentTabName)
                ShowSnackbar("تم تصدير ملف PDF بنجاح")
            Else
                MessageBox.Show("لم يتم العثور على جدول التقرير ليتم تصديره.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
            End If
        End Sub

        Private Sub ExportExcel_Click(sender As Object, e As RoutedEventArgs)
            Dim vm As ViewModels.ReportsViewModel = TryCast(Me.DataContext, ViewModels.ReportsViewModel)
            If vm Is Nothing Then Return

            Dim currentTabName = CType(CType(Me.FindName("TabControl"), TabControl)?.SelectedItem, TabItem)?.Header?.ToString()
            Dim activeGrid = GetActiveDataGrid(vm.SelectedReportTab)
            If activeGrid IsNot Nothing Then
                Helpers.ReportExporter.ExportDataGridToCsv(activeGrid, currentTabName)
                ShowSnackbar("تم تصدير ملف CSV بنجاح")
            Else
                MessageBox.Show("لم يتم العلمور على جدول التقرير ليتم تصديره.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
            End If
        End Sub

        Private Async Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible
            
            Dim fadeIn As New DoubleAnimation With {
                .From = 0,
                .To = 1,
                .Duration = TimeSpan.FromSeconds(0.3)
            }
            
            SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeIn)
            
            Await System.Threading.Tasks.Task.Delay(3000)
            
            Dim fadeOut As New DoubleAnimation With {
                .From = 1,
                .To = 0,
                .Duration = TimeSpan.FromSeconds(0.5)
            }
            
            SnackbarBorder.BeginAnimation(UIElement.OpacityProperty, fadeOut)
            Await System.Threading.Tasks.Task.Delay(500)
            SnackbarBorder.Visibility = Visibility.Collapsed
        End Sub

        Private Function GetActiveDataGrid(tabIndex As Integer) As DataGrid
            ' The Grids are the children of the Border/Grid named ReportGridContainer
            ' We can find them based on the tabIndex if they are directly inside
            ' To be safe, we iterate the VisualTree to find the visible DataGrid
            Return FindVisibleDataGrid(ReportGridContainer)
        End Function

        Private Function FindVisibleDataGrid(parent As DependencyObject) As DataGrid
            If parent Is Nothing Then Return Nothing
            For i As Integer = 0 To VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = VisualTreeHelper.GetChild(parent, i)
                Dim dg = TryCast(child, DataGrid)
                If dg IsNot Nothing AndAlso dg.IsVisible Then
                    Return dg
                End If
                Dim result = FindVisibleDataGrid(child)
                If result IsNot Nothing Then Return result
            Next
            Return Nothing
        End Function

    End Class
End Namespace
