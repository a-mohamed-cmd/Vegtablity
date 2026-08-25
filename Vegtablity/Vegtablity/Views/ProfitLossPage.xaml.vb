Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Data
Imports Vegtablity.Models
Imports Vegtablity.ViewModels

Namespace Views
    Public Class ProfitLossPage
        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub ProfitLossPage_DataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs) Handles Me.DataContextChanged
            Dim oldVm = TryCast(e.OldValue, ProfitLossViewModel)
            If oldVm IsNot Nothing Then
                RemoveHandler oldVm.PropertyChanged, AddressOf OnViewModelPropertyChanged
            End If

            Dim newVm = TryCast(e.NewValue, ProfitLossViewModel)
            If newVm IsNot Nothing Then
                AddHandler newVm.PropertyChanged, AddressOf OnViewModelPropertyChanged
                If newVm.MonthlyReport IsNot Nothing Then
                    RebuildMonthlyGridColumns(newVm.MonthlyReport)
                End If
            End If
        End Sub

        Private Sub OnViewModelPropertyChanged(sender As Object, e As System.ComponentModel.PropertyChangedEventArgs)
            If e.PropertyName = NameOf(ProfitLossViewModel.MonthlyReport) Then
                Dim vm = TryCast(Me.DataContext, ProfitLossViewModel)
                If vm IsNot Nothing Then
                    RebuildMonthlyGridColumns(vm.MonthlyReport)
                End If
            End If
        End Sub

        Private Sub RebuildMonthlyGridColumns(report As MonthlyComparativeReport)
            If report Is Nothing OrElse report.Months Is Nothing Then Return
            RebuildGridFor(MonthlyRevenueGrid, report)
            RebuildGridFor(MonthlyExpenseGrid, report)
        End Sub

        Private Sub RebuildGridFor(grid As DataGrid, report As MonthlyComparativeReport)
            If grid Is Nothing Then Return
            grid.Columns.Clear()

            ' 1. Code
            grid.Columns.Add(New DataGridTextColumn() With {
                .Header = "الكود",
                .Binding = New Binding("AccountCode"),
                .Width = 90
            })

            ' 2. Name
            grid.Columns.Add(New DataGridTextColumn() With {
                .Header = "اسم الحساب",
                .Binding = New Binding("AccountName"),
                .Width = New DataGridLength(1, DataGridLengthUnitType.Star)
            })

            ' 3. Dynamic Month Columns
            Dim accConv = TryCast(FindResource("AccountConverter"), IValueConverter)
            For Each m In report.Months
                Dim monthKey = m.MonthKey
                Dim col As New DataGridTextColumn() With {
                    .Header = m.MonthName,
                    .Binding = New Binding($"MonthlyValues[{monthKey}]") With {
                        .Converter = accConv,
                        .TargetNullValue = "-"
                    },
                    .Width = 100
                }
                grid.Columns.Add(col)
            Next

            ' 4. Total Period
            grid.Columns.Add(New DataGridTextColumn() With {
                .Header = "إجمالي الفترة",
                .Binding = New Binding("TotalBalance") With {
                    .Converter = accConv
                },
                .FontWeight = FontWeights.Bold,
                .Width = 120
            })

            ' 5. % of Sales
            grid.Columns.Add(New DataGridTextColumn() With {
                .Header = "% من المبيعات",
                .Binding = New Binding("PercentageOfSalesText"),
                .FontWeight = FontWeights.Bold,
                .Width = 100
            })
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
        Private Sub StartDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim parsed As DateTime
            If ParseDateInput(tb.Text, parsed) Then
                Dim vm = TryCast(Me.DataContext, ProfitLossViewModel)
                If vm IsNot Nothing Then
                    vm.StartDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub EndDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim parsed As DateTime
            If ParseDateInput(tb.Text, parsed) Then
                Dim vm = TryCast(Me.DataContext, ProfitLossViewModel)
                If vm IsNot Nothing Then
                    vm.EndDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub Date_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Function ParseDateInput(raw As String, ByRef parsed As DateTime) As Boolean
            raw = raw.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Return DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                          System.Globalization.CultureInfo.InvariantCulture,
                                          System.Globalization.DateTimeStyles.None, parsed)
        End Function
    
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub
    End Class
End Namespace
