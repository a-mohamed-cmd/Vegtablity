Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Vegtablity.Models

Namespace Controls
    Public Class VoucherRowControl
        Inherits UserControl

        Public Event RequestPrint As EventHandler(Of Voucher)

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub PrintButton_Click(sender As Object, e As RoutedEventArgs)
            Dim voucher = TryCast(Me.DataContext, Voucher)
            If voucher Is Nothing Then Return

            ' Execute print directly or via parent ViewModel
            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm As ViewModels.VouchersViewModel = Nothing
            If parentListBox IsNot Nothing Then
                vm = TryCast(parentListBox.DataContext, ViewModels.VouchersViewModel)
            End If

            Dim isPayment = String.Equals(voucher.VoucherType, "Payment", StringComparison.OrdinalIgnoreCase)

            If vm IsNot Nothing Then
                If isPayment Then
                    If vm.PrintPaymentCommand IsNot Nothing Then
                        vm.PrintPaymentCommand.Execute(voucher)
                    Else
                        Helpers.ReportExporter.ExportPaymentVoucherToPdf(voucher)
                    End If
                Else
                    If vm.PrintReceiptCommand IsNot Nothing Then
                        vm.PrintReceiptCommand.Execute(voucher)
                    Else
                        Helpers.ReportExporter.ExportReceiptVoucherToPdf(voucher)
                    End If
                End If
            Else
                ' Fallback
                If isPayment Then
                    Helpers.ReportExporter.ExportPaymentVoucherToPdf(voucher)
                Else
                    Helpers.ReportExporter.ExportReceiptVoucherToPdf(voucher)
                End If
            End If

            RaiseEvent RequestPrint(Me, voucher)
        End Sub

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then
                Return parent
            Else
                Return FindVisualParent(Of T)(parentObject)
            End If
        End Function
    End Class
End Namespace
