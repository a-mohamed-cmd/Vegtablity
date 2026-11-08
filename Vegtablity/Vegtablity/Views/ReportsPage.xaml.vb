Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports System.Windows.Media.Animation
Imports System.Text.RegularExpressions
Imports System.Globalization
Imports System.Linq
Imports Vegtablity.Helpers
Imports Vegtablity.ViewModels
Imports Vegtablity.Models

Namespace Views
    Partial Public Class ReportsPage
        Inherits UserControl

        Private _isSidebarCollapsed As Boolean = False

        Public Sub New()
            InitializeComponent()
            AddHandler Me.Loaded, AddressOf ReportsPage_Loaded
        End Sub

        Private Sub ReportsPage_Loaded(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm IsNot Nothing Then
                RemoveHandler vm.ReportLoaded, AddressOf OnReportLoaded
                AddHandler vm.ReportLoaded, AddressOf OnReportLoaded
            End If
            SyncDropdownSelectionsFromViewModel()
            RebuildTableHeaders()
        End Sub

        Private Sub OnReportLoaded(sender As Object, e As EventArgs)
            SyncDropdownSelectionsFromViewModel()
            RebuildTableHeaders()
            If ReportScrollViewer IsNot Nothing Then
                ReportScrollViewer.ScrollToTop()
            End If
            If JournalDebtAgingView IsNot Nothing Then
                JournalDebtAgingView.ScrollToTop()
            End If
        End Sub

        ' =======================================================
        ' Dynamic Proportional Table Header Builder (Matches ReportRowControl)
        ' =======================================================
        Private Sub RebuildTableHeaders()
            If ReportHeadersGrid Is Nothing Then Return
            ReportHeadersGrid.Children.Clear()
            ReportHeadersGrid.ColumnDefinitions.Clear()

            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm Is Nothing OrElse vm.CurrentReportHeaders Is Nothing Then Return

            ' Column 0: Sequence Number (#) - Fixed 48px matching ReportRowControl
            ReportHeadersGrid.ColumnDefinitions.Add(New ColumnDefinition() With {.Width = New GridLength(48, GridUnitType.Pixel)})
            Dim seqHeader As New TextBlock() With {
                .Text = "#",
                .FontSize = 12,
                .FontWeight = FontWeights.Bold,
                .Foreground = New SolidColorBrush(CType(ColorConverter.ConvertFromString("#64748B"), Color)),
                .HorizontalAlignment = HorizontalAlignment.Center,
                .VerticalAlignment = VerticalAlignment.Center
            }
            Grid.SetColumn(seqHeader, 0)
            ReportHeadersGrid.Children.Add(seqHeader)

            For i As Integer = 0 To vm.CurrentReportHeaders.Count - 1
                Dim h = vm.CurrentReportHeaders(i)
                Dim colIdx As Integer = i + 1
                Dim weight As Double = If(h.WidthWeight > 0, h.WidthWeight, 1.0)
                ReportHeadersGrid.ColumnDefinitions.Add(New ColumnDefinition() With {.Width = New GridLength(weight, GridUnitType.Star)})

                Dim fgHex As String = If(h.IsHighlight AndAlso Not String.IsNullOrEmpty(h.AccentColor), h.AccentColor, "#334155")
                Dim fgBrush As New SolidColorBrush(CType(ColorConverter.ConvertFromString(fgHex), Color))

                Dim tb As New TextBlock() With {
                    .Text = h.Title,
                    .FontSize = 12.5,
                    .FontWeight = FontWeights.Bold,
                    .Foreground = fgBrush,
                    .Margin = New Thickness(6, 0, 6, 0),
                    .VerticalAlignment = VerticalAlignment.Center,
                    .TextTrimming = TextTrimming.CharacterEllipsis
                }
                Grid.SetColumn(tb, colIdx)
                ReportHeadersGrid.Children.Add(tb)
            Next
        End Sub

        ' =======================================================
        ' Collapsible Sidebar with Smooth Animation
        ' =======================================================
        Private Sub BtnToggleSidebar_Click(sender As Object, e As RoutedEventArgs)
            _isSidebarCollapsed = Not _isSidebarCollapsed
            Dim duration As New Duration(TimeSpan.FromMilliseconds(260))
            Dim ease As New CubicEase() With {.EasingMode = EasingMode.EaseInOut}

            If _isSidebarCollapsed Then
                Dim widthAnim As New DoubleAnimation(255, 0, duration) With {.EasingFunction = ease}
                Dim opacityAnim As New DoubleAnimation(1, 0, duration) With {.EasingFunction = ease}
                AddHandler widthAnim.Completed, Sub(s, args)
                                                    SidebarBorder.Visibility = Visibility.Collapsed
                                                End Sub
                SidebarBorder.BeginAnimation(FrameworkElement.MaxWidthProperty, widthAnim)
                SidebarBorder.BeginAnimation(UIElement.OpacityProperty, opacityAnim)
                SidebarBorder.Margin = New Thickness(0)
                If TxtToggleLabel IsNot Nothing Then TxtToggleLabel.Text = "إظهار التقارير"
                If TxtToggleIcon IsNot Nothing Then TxtToggleIcon.Text = "☰"
            Else
                SidebarBorder.Visibility = Visibility.Visible
                SidebarBorder.Margin = New Thickness(0, 0, 12, 0)
                Dim widthAnim As New DoubleAnimation(0, 255, duration) With {.EasingFunction = ease}
                Dim opacityAnim As New DoubleAnimation(0, 1, duration) With {.EasingFunction = ease}
                SidebarBorder.BeginAnimation(FrameworkElement.MaxWidthProperty, widthAnim)
                SidebarBorder.BeginAnimation(UIElement.OpacityProperty, opacityAnim)
                If TxtToggleLabel IsNot Nothing Then TxtToggleLabel.Text = "طي القائمة"
                If TxtToggleIcon IsNot Nothing Then TxtToggleIcon.Text = "❯"
            End If
        End Sub

        ' =======================================================
        ' SearchableDropdown Synchronization & Event Handlers
        ' =======================================================
        Private Sub SyncDropdownSelectionsFromViewModel()
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm Is Nothing Then Return

            Dim selectedPartner = vm.Partners.FirstOrDefault(Function(p) p.PartnerID = vm.SelectedPartnerID)
            If PartnerFilterDropdown IsNot Nothing Then
                PartnerFilterDropdown.SelectedItem = selectedPartner
            End If

            Dim selectedWarehouse = vm.Warehouses.FirstOrDefault(Function(w) w.WarehouseID = vm.SelectedWarehouseID)
            If WarehouseFilterDropdown IsNot Nothing Then
                WarehouseFilterDropdown.SelectedItem = selectedWarehouse
            End If

            Dim selectedProduct = vm.Products.FirstOrDefault(Function(p) p.ProductID = vm.SelectedProductID)
            If ProductFilterDropdown IsNot Nothing Then
                ProductFilterDropdown.SelectedItem = selectedProduct
            End If
        End Sub

        Private Sub PartnerDropdown_SearchChanged(sender As Object, searchText As String)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm IsNot Nothing Then
                vm.ApplyPartnerFilter(searchText)
            End If
        End Sub

        Private Sub PartnerDropdown_ItemSelected(sender As Object, selectedItem As Object)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            Dim partner = TryCast(selectedItem, Partner)
            If vm IsNot Nothing AndAlso partner IsNot Nothing Then
                vm.SelectedPartnerID = partner.PartnerID
                vm.ApplyPartnerFilter("")
                If PartnerFilterDropdown IsNot Nothing Then PartnerFilterDropdown.SelectedItem = partner
                vm.LoadReportCommand.Execute(Nothing)
            End If
        End Sub

        Private Sub WarehouseDropdown_SearchChanged(sender As Object, searchText As String)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm IsNot Nothing Then
                vm.ApplyWarehouseFilter(searchText)
            End If
        End Sub

        Private Sub WarehouseDropdown_ItemSelected(sender As Object, selectedItem As Object)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            Dim wh = TryCast(selectedItem, Warehouse)
            If vm IsNot Nothing AndAlso wh IsNot Nothing Then
                vm.SelectedWarehouseID = wh.WarehouseID
                vm.ApplyWarehouseFilter("")
                If WarehouseFilterDropdown IsNot Nothing Then WarehouseFilterDropdown.SelectedItem = wh
                vm.LoadReportCommand.Execute(Nothing)
            End If
        End Sub

        Private Sub ProductDropdown_SearchChanged(sender As Object, searchText As String)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm IsNot Nothing Then
                vm.ApplyProductFilter(searchText)
            End If
        End Sub

        Private Sub ProductDropdown_ItemSelected(sender As Object, selectedItem As Object)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            Dim prod = TryCast(selectedItem, Product)
            If vm IsNot Nothing AndAlso prod IsNot Nothing Then
                vm.SelectedProductID = prod.ProductID
                vm.ApplyProductFilter("")
                If ProductFilterDropdown IsNot Nothing Then ProductFilterDropdown.SelectedItem = prod
                vm.LoadReportCommand.Execute(Nothing)
            End If
        End Sub

        ' ===================================================
        ' Export Logic (CSV & PDF) using Custom UserControl Rows & Summary Bar
        ' ===================================================
        Private Sub BtnExportCsv_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm Is Nothing Then Return
            If vm.IsJournalDebtAgingTabSelected Then
                vm.JournalDebtAgingVM.ExportToExcel(vm.CurrentReportTitle, vm.SummaryMetrics)
                Return
            End If
            ReportExporter.ExportReportRowsToCsv(vm.CurrentReportTitle, vm.CurrentReportHeaders, vm.AllFilteredRowsForExport, vm.SummaryMetrics)
        End Sub

        Private Sub BtnExportPdf_Click(sender As Object, e As RoutedEventArgs)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm Is Nothing Then Return
            If vm.IsJournalDebtAgingTabSelected Then
                vm.JournalDebtAgingVM.ExportToPdf(vm.CurrentReportTitle, vm.SummaryMetrics)
                Return
            End If
            ReportExporter.ExportReportRowsToPdf(vm.CurrentReportTitle, vm.CurrentReportHeaders, vm.AllFilteredRowsForExport, vm.SummaryMetrics)
        End Sub

        ' ===================================================
        ' Smart Date Input Logic
        ' ===================================================
        Private _isFormattingDate As Boolean = False

        Private Sub DateTextBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim regex As New Regex("[^0-9/]+")
            e.Handled = regex.IsMatch(e.Text)
        End Sub

        Private Sub FormatDateTextBox(tb As TextBox)
            If _isFormattingDate OrElse tb Is Nothing Then Return
            _isFormattingDate = True

            Try
                Dim digitsOnly As String = Regex.Replace(tb.Text, "[^\d]", "")
                If digitsOnly.Length > 8 Then digitsOnly = digitsOnly.Substring(0, 8)

                Dim formatted As String = ""
                If digitsOnly.Length > 0 Then
                    formatted = digitsOnly.Substring(0, Math.Min(2, digitsOnly.Length))
                    If digitsOnly.Length >= 2 Then
                        Dim dayVal As Integer = Integer.Parse(formatted)
                        If dayVal > 31 Then formatted = "31"
                        If dayVal = 0 AndAlso digitsOnly.Length > 2 Then formatted = "01"
                    End If
                End If

                If digitsOnly.Length > 2 Then
                    Dim monthPart As String = digitsOnly.Substring(2, Math.Min(2, digitsOnly.Length - 2))
                    If monthPart.Length = 2 Then
                        Dim monthVal As Integer = Integer.Parse(monthPart)
                        If monthVal > 12 Then monthPart = "12"
                        If monthVal = 0 Then monthPart = "01"
                    End If
                    formatted &= "/" & monthPart
                End If

                If digitsOnly.Length > 4 Then
                    Dim yearPart As String = digitsOnly.Substring(4, digitsOnly.Length - 4)
                    formatted &= "/" & yearPart
                End If

                If tb.Text <> formatted Then
                    tb.Text = formatted
                    tb.CaretIndex = formatted.Length
                End If
            Finally
                _isFormattingDate = False
            End Try
        End Sub

        Private Sub ParseAndCommitDate(tb As TextBox, isStartDate As Boolean)
            Dim vm = TryCast(Me.DataContext, ReportsViewModel)
            If vm Is Nothing OrElse tb Is Nothing Then Return

            Dim raw As String = tb.Text.Trim()
            Dim parsedDate As DateTime
            Dim formats As String() = {"d/M/yyyy", "dd/MM/yyyy", "d/M/yy", "dd/MM/yy", "yyyy/MM/dd", "d-M-yyyy", "dd-MM-yyyy"}

            If DateTime.TryParseExact(raw, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, parsedDate) Then
                If isStartDate Then
                    vm.SelectedStartDate = parsedDate
                    vm.SelectedStartDateText = parsedDate.ToString("dd/MM/yyyy")
                Else
                    vm.SelectedEndDate = parsedDate
                    vm.SelectedEndDateText = parsedDate.ToString("dd/MM/yyyy")
                End If
            Else
                If isStartDate Then
                    tb.Text = vm.SelectedStartDate.ToString("dd/MM/yyyy")
                Else
                    tb.Text = vm.SelectedEndDate.ToString("dd/MM/yyyy")
                End If
            End If
        End Sub

        Private Sub StartDateTextBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            FormatDateTextBox(TryCast(sender, TextBox))
        End Sub

        Private Sub StartDateTextBox_LostFocus(sender As Object, e As RoutedEventArgs)
            ParseAndCommitDate(TryCast(sender, TextBox), True)
        End Sub

        Private Sub EndDateTextBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            FormatDateTextBox(TryCast(sender, TextBox))
        End Sub

        Private Sub EndDateTextBox_LostFocus(sender As Object, e As RoutedEventArgs)
            ParseAndCommitDate(TryCast(sender, TextBox), False)
        End Sub

    End Class
End Namespace
