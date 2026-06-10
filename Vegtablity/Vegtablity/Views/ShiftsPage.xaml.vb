Imports System.Windows.Input
Imports System.Windows.Controls
Imports Vegtablity.Models
Imports Vegtablity.ViewModels

Namespace Views
    Public Class ShiftsPage
        Public Sub New()
            InitializeComponent()
            Me.DataContext = New ViewModels.ShiftsViewModel()
        End Sub

        Private Sub SalesDataGrid_MouseDoubleClick(sender As Object, e As MouseButtonEventArgs)
            Dim grid = TryCast(sender, DataGrid)
            If grid Is Nothing OrElse grid.SelectedItem Is Nothing Then Return

            Dim invoice = TryCast(grid.SelectedItem, InvoiceHeader)
            If invoice Is Nothing Then Return

            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing Then
                Dim dVm = TryCast(parent.DataContext, DashboardViewModel)
                If dVm IsNot Nothing Then
                    Dim page As New SalesInvoicePage()
                    Dim vm = TryCast(page.DataContext, SalesInvoiceViewModel)
                    If vm IsNot Nothing Then
                        vm.LoadInvoice(invoice.InvID)
                    End If
                    parent.NavigateTo(page, True)
                End If
            End If
        End Sub

        Private Sub PurchaseDataGrid_MouseDoubleClick(sender As Object, e As MouseButtonEventArgs)
            Dim grid = TryCast(sender, DataGrid)
            If grid Is Nothing OrElse grid.SelectedItem Is Nothing Then Return

            Dim invoice = TryCast(grid.SelectedItem, InvoiceHeader)
            If invoice Is Nothing Then Return

            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing Then
                Dim dVm = TryCast(parent.DataContext, DashboardViewModel)
                If dVm IsNot Nothing Then
                    Dim page As New PurchaseInvoicePage()
                    Dim vm = TryCast(page.DataContext, PurchaseInvoiceViewModel)
                    If vm IsNot Nothing Then
                        vm.LoadInvoice(invoice.InvID)
                    End If
                    parent.NavigateTo(page, True)
                End If
            End If
        End Sub
        Private Sub ReceiptDataGrid_MouseDoubleClick(sender As Object, e As MouseButtonEventArgs)
            Dim grid = TryCast(sender, DataGrid)
            If grid Is Nothing OrElse grid.SelectedItem Is Nothing Then Return

            Dim voucher = TryCast(grid.SelectedItem, Voucher)
            If voucher Is Nothing Then Return

            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing Then
                Dim page As New ReceiptVoucherPage()
                Dim vm = TryCast(page.DataContext, VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.SelectedReceipt = vm.Receipts.FirstOrDefault(Function(v) v.VoucherID = voucher.VoucherID)
                End If
                parent.NavigateTo(page, True)
            End If
        End Sub

        Private Sub PaymentDataGrid_MouseDoubleClick(sender As Object, e As MouseButtonEventArgs)
            Dim grid = TryCast(sender, DataGrid)
            If grid Is Nothing OrElse grid.SelectedItem Is Nothing Then Return

            Dim voucher = TryCast(grid.SelectedItem, Voucher)
            If voucher Is Nothing Then Return

            Dim parent = TryCast(System.Windows.Window.GetWindow(Me), DashboardWindow)
            If parent IsNot Nothing Then
                Dim page As New PaymentVoucherPage()
                Dim vm = TryCast(page.DataContext, VouchersViewModel)
                If vm IsNot Nothing Then
                    vm.SelectedPayment = vm.Payments.FirstOrDefault(Function(v) v.VoucherID = voucher.VoucherID)
                End If
                parent.NavigateTo(page, True)
            End If
        End Sub
    End Class
End Namespace
