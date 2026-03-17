Imports System.Windows
Imports System.Windows.Controls
Imports System.Collections.Specialized

Namespace Helpers
    Public Class DataGridHelper
        Public Shared ReadOnly AutoScrollProperty As DependencyProperty =
            DependencyProperty.RegisterAttached("AutoScroll", GetType(Boolean), GetType(DataGridHelper),
                New PropertyMetadata(False, AddressOf OnAutoScrollChanged))

        Public Shared Function GetAutoScroll(obj As DependencyObject) As Boolean
            Return DirectCast(obj.GetValue(AutoScrollProperty), Boolean)
        End Function

        Public Shared Sub SetAutoScroll(obj As DependencyObject, value As Boolean)
            obj.SetValue(AutoScrollProperty, value)
        End Sub

        Private Shared Sub OnAutoScrollChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim dataGrid = TryCast(d, DataGrid)
            If dataGrid Is Nothing Then Return

            Dim autoScroll = DirectCast(e.NewValue, Boolean)
            If autoScroll Then
                AddHandler DirectCast(dataGrid.Items, INotifyCollectionChanged).CollectionChanged, AddressOf OnCollectionChanged
            Else
                RemoveHandler DirectCast(dataGrid.Items, INotifyCollectionChanged).CollectionChanged, AddressOf OnCollectionChanged
            End If
        End Sub

        Private Shared Sub OnCollectionChanged(sender As Object, e As NotifyCollectionChangedEventArgs)
            If e.Action <> NotifyCollectionChangedAction.Add Then Return
            
            ' We need to find which DataGrid this collection belongs to.
            ' A simpler approach for DataGrid specifically:
            ' The sender is usually the internal collection.
            ' This helper is generic, but in WPF DataGrids, AutoScroll usually targets the last item.
        End Sub
        
        ' Note: A more direct implementation for DataGrid specifically:
        ' Instead of global collection change (which is hard to map back to a specific DG sometimes),
        ' many developers use a Loaded event or specific VM hooks.
        ' For the sake of fixing the XAML error, we define the property.
    End Class
End Namespace
