Imports System.Windows
Imports System.Windows.Controls

Namespace Views
    Public Class ProductCardControl
        Inherits UserControl

        ' حدث مخصص لإبلاغ النافذة الأب بإغلاق هذه البطاقة
        Public Event OnCloseRequested As EventHandler

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub BtnClose_Click(sender As Object, e As RoutedEventArgs)
            RaiseEvent OnCloseRequested(Me, EventArgs.Empty)
        End Sub
    End Class
End Namespace
