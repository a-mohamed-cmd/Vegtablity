Imports System.Windows.Controls
Imports Vegtablity.ViewModels

Namespace Views
    Public Class YearEndClosePage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            Me.DataContext = New YearEndCloseViewModel()
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
        Private Sub Date_LostFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                Dim vm = TryCast(Me.DataContext, YearEndCloseViewModel)
                If vm IsNot Nothing Then
                    vm.ClosingDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub Date_GotFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub
    End Class
End Namespace
