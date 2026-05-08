Namespace Views
    Public Class TrialBalancePage
        Public Sub New()
            InitializeComponent()
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

        Private Sub Date_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub

        Private Sub StartDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.TrialBalanceViewModel)
            If vm Is Nothing Then Return

            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return

            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.StartDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
                tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy"
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub EndDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim vm = TryCast(Me.DataContext, ViewModels.TrialBalanceViewModel)
            If vm Is Nothing Then Return

            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return

            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.EndDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
                tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy"
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub
    
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
End Class
End Namespace
