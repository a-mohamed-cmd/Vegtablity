Imports System.Windows
Imports System.Windows.Controls
Imports Vegtablity.Models
Imports Vegtablity.ViewModels

Namespace Controls
    Public Class AccountTreeControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub TreeView_SelectedItemChanged(sender As Object, e As RoutedPropertyChangedEventArgs(Of Object))
            Dim selectedNode = TryCast(e.NewValue, AccountNode)
            Dim vm = TryCast(Me.DataContext, AccountingViewModel)
            If vm IsNot Nothing Then
                vm.SelectedNode = selectedNode
                If selectedNode IsNot Nothing Then
                    vm.SelectedAccount = selectedNode.Account
                End If
            End If
        End Sub
    End Class
End Namespace
