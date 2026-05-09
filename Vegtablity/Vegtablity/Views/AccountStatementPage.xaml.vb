Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports Vegtablity.Controls

Namespace Views
    Partial Public Class AccountStatementPage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  SearchableDropdown Events — حساب
        ' ══════════════════════════════════════════════════════

        ''' <summary>يُطلَق عند كتابة نص — نفِّذ الفلترة المحلية</summary>
        Private Sub AccountDropdown_SearchChanged(sender As Object, e As String)
            Dim vm = TryCast(Me.DataContext, ViewModels.AccountStatementViewModel)
            If vm Is Nothing Then Return
            vm.FilterAccounts(e)   ' "" = أظهر الكل
        End Sub

        ''' <summary>يُطلَق عند اختيار عنصر (ماوس أو Enter)</summary>
        Private Sub AccountDropdown_ItemSelected(sender As Object, e As Object)
            Dim selected = TryCast(e, Models.Account)
            If selected Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.AccountStatementViewModel)
            If vm IsNot Nothing Then vm.SelectedAccount = selected
        End Sub

        ''' <summary>يُطلَق عند تأكيد الاختيار — انتقل للحقل التالي</summary>
        Private Sub AccountDropdown_MoveNext(sender As Object, e As EventArgs)
            Dim ctrl = TryCast(sender, Vegtablity.Controls.SearchableDropdown)
            If ctrl IsNot Nothing Then
                Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                ctrl.MoveFocus(req)
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Date Helpers
        ' ══════════════════════════════════════════════════════

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
            Dim vm = TryCast(Me.DataContext, ViewModels.AccountStatementViewModel)
            If vm Is Nothing Then Return
            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return
            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.StartDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
            End If
        End Sub

        Private Sub EndDate_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.AccountStatementViewModel)
            If vm Is Nothing Then Return
            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return
            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.EndDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
            End If
        End Sub

        Private Sub Date_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                    tb.MoveFocus(req)
                End If
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Snackbar
        ' ══════════════════════════════════════════════════════

        Private Async Sub ShowSnackbar(message As String)
            If SnackbarBorder Is Nothing Then Return
            SnackbarText.Text = message
            SnackbarIcon.Text = "⚠️"
            SnackbarBorder.Visibility = Visibility.Visible
            Await System.Threading.Tasks.Task.Delay(3000)
            SnackbarBorder.Visibility = Visibility.Collapsed
        End Sub

    End Class
End Namespace
