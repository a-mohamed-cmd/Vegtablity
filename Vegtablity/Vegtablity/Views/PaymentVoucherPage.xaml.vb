Imports System.Windows.Input

Namespace Views
    Partial Public Class PaymentVoucherPage
        Private Sub Amount_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim regex As New System.Text.RegularExpressions.Regex("[^0-9.]+")
            If regex.IsMatch(e.Text) Then
                e.Handled = True
                Return
            End If
            
            Dim txt As System.Windows.Controls.TextBox = TryCast(sender, System.Windows.Controls.TextBox)
            If txt IsNot Nothing AndAlso e.Text = "." AndAlso txt.Text.Contains(".") Then
                e.Handled = True
            End If
        End Sub
    End Class
End Namespace
