Imports System.Windows
Imports System.Windows.Controls

Namespace Views
    Partial Public Class CancelledInvoiceDetailsPage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub BtnGoBack_Click(sender As Object, e As RoutedEventArgs)
            Dim parent = TryCast(Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing AndAlso parent.CanGoBack Then
                parent.GoBack()
            End If
        End Sub
    End Class
End Namespace
