Namespace Views
    Partial Public Class JournalEntryPage
        Public Sub New()
            InitializeComponent()
        End Sub

        ' Update totals if user finishes editing a cell
        Public Sub DataGrid_CellEditEnding(sender As Object, e As DataGridCellEditEndingEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm IsNot Nothing Then
                ' Use Dispatcher to wait for the value to be committed to the model
                Dispatcher.BeginInvoke(Sub() vm.UpdateTotals(), Windows.Threading.DispatcherPriority.Background)
            End If
        End Sub
    End Class
End Namespace
