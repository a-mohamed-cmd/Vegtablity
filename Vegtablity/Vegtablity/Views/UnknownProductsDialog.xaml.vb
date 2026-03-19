Imports System.Windows
Imports Vegtablity.Helpers

Namespace Views
    Public Class UnknownProductsDialog
        Inherits Window

        Public Property Approved As Boolean = False

        Public Sub New(unknownRows As List(Of ImportedRow))
            InitializeComponent()
            dgUnknowns.ItemsSource = unknownRows
        End Sub

        Private Sub BtnApprove_Click(sender As Object, e As RoutedEventArgs)
            Approved = True
            Me.DialogResult = True
            Me.Close()
        End Sub

        Private Sub BtnReject_Click(sender As Object, e As RoutedEventArgs)
            Approved = False
            Me.DialogResult = False
            Me.Close()
        End Sub
    End Class
End Namespace
