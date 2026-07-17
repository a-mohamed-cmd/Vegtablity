Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports Vegtablity.ViewModels

Namespace Views
    Public Class DailyOrdersPage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            Me.DataContext = New ViewModels.DailyOrdersViewModel()
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

        Private Sub Date_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.DailyOrdersViewModel)
            If vm Is Nothing Then Return
            Dim raw = tb.Text
            If String.IsNullOrWhiteSpace(raw) Then Return
            Dim parsed As DateTime
            If ParseDateInput(raw, parsed) Then
                vm.SelectedDate = parsed
                tb.Text = parsed.ToString("dd/MM/yyyy")
                tb.Foreground = System.Windows.Media.Brushes.Black
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
            End If
        End Sub

        Private Sub ViewInvoice_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing OrElse btn.Tag Is Nothing Then Return
            Dim invID = Convert.ToInt32(btn.Tag)

            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing Then
                ' We open the SalesInvoicePage and load the invoice by ID
                Dim page As New SalesInvoicePage()
                Dim vm = TryCast(page.DataContext, SalesInvoiceViewModel)
                If vm IsNot Nothing Then
                    vm.LoadInvoice(invID)
                End If
                parent.NavigateTo(page, keepCurrentInStack:=True)
            End If
        End Sub
    End Class
End Namespace
