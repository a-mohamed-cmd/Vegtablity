Imports System
Imports System.ComponentModel
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models.Integrations
Imports Vegtablity.Services
Imports Vegtablity.ViewModels.Integrations

Namespace Controls

    Partial Public Class PaymentGatewayLinkRowControl
        Inherits UserControl

        Private _subscribedVm As PaymentGatewayInvoicesViewModel

        Public Sub New()
            InitializeComponent()
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            AddHandler Me.Loaded, AddressOf OnLoaded
            AddHandler Me.Unloaded, AddressOf OnUnloaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            AttachViewModelSubscription()
            UpdateVisualStatus()
        End Sub

        Private Sub OnUnloaded(sender As Object, e As RoutedEventArgs)
            DetachViewModelSubscription()
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            UpdateVisualStatus()
        End Sub

        Private Sub AttachViewModelSubscription()
            Dim vm = GetParentViewModel()
            If _subscribedVm Is vm Then Return
            DetachViewModelSubscription()
            If vm IsNot Nothing Then
                _subscribedVm = vm
                AddHandler _subscribedVm.PropertyChanged, AddressOf OnParentVmPropertyChanged
            End If
        End Sub

        Private Sub DetachViewModelSubscription()
            If _subscribedVm IsNot Nothing Then
                RemoveHandler _subscribedVm.PropertyChanged, AddressOf OnParentVmPropertyChanged
                _subscribedVm = Nothing
            End If
        End Sub

        Private Sub OnParentVmPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e Is Nothing OrElse String.IsNullOrEmpty(e.PropertyName) OrElse e.PropertyName = NameOf(PaymentGatewayInvoicesViewModel.CanCurrentUserRefund) Then
                UpdateVisualStatus()
            End If
        End Sub

        Public Sub UpdateVisualStatus()
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            If item Is Nothing OrElse StatusBadge Is Nothing Then Return

            Dim status = If(item.LinkStatus, "Pending").Trim()

            Select Case status.ToLowerInvariant()
                Case "paid"
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(16, 185, 129))   ' #10B981
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(220, 252, 231))  ' #DCFCE7
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(134, 239, 172)) ' #86EFAC
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(22, 101, 52)) ' #166534

                Case "pending"
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(245, 158, 11))   ' #F59E0B
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(254, 243, 199))  ' #FEF3C7
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(252, 211, 77))  ' #FCD34D
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(146, 64, 14)) ' #92400E

                Case "refunded", "partiallyrefunded"
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(239, 68, 68))    ' #EF4444
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(254, 226, 226))  ' #FEE2E2
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(252, 165, 165)) ' #FCA5A5
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(153, 27, 27)) ' #991B1B

                Case Else
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(100, 116, 139))  ' #64748B
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(241, 245, 249))  ' #F1F5F9
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(203, 213, 225)) ' #CBD5E1
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(71, 85, 105)) ' #475569
            End Select

            If BtnRefundRow IsNot Nothing Then
                Dim vm = GetParentViewModel()
                Dim canUserRefund As Boolean = If(vm IsNot Nothing,
                                                  vm.CanCurrentUserRefund,
                                                  (Session.CurrentUser IsNot Nothing AndAlso Session.CurrentUser.CanRefundPaymentGateway))
                BtnRefundRow.Visibility = If(item.CanRefund AndAlso canUserRefund, Visibility.Visible, Visibility.Collapsed)
            End If
        End Sub

        Private Sub MainRowBorder_MouseEnter(sender As Object, e As MouseEventArgs)
            MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(147, 197, 253)) ' #93C5FD
        End Sub

        Private Sub MainRowBorder_MouseLeave(sender As Object, e As MouseEventArgs)
            MainRowBorder.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240)) ' #E2E8F0
        End Sub

        Private Function GetParentViewModel() As PaymentGatewayInvoicesViewModel
            Dim curr As DependencyObject = Me
            While curr IsNot Nothing
                curr = VisualTreeHelper.GetParent(curr)
                Dim fe = TryCast(curr, FrameworkElement)
                If fe IsNot Nothing AndAlso TypeOf fe.DataContext Is PaymentGatewayInvoicesViewModel Then
                    Return CType(fe.DataContext, PaymentGatewayInvoicesViewModel)
                End If
            End While
            Return Nothing
        End Function

        Private Sub BtnRefreshStatus_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.RefreshStatusCommand?.Execute(item)
            End If
        End Sub

        Private Sub BtnWhatsApp_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.SendWhatsAppCommand?.Execute(item)
            End If
        End Sub

        Private Sub BtnCopyLink_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            If item IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(item.PaymentUrl) Then
                Clipboard.SetText(item.PaymentUrl)
                MessageBox.Show("تم نسخ رابط الدفع الإلكتروني إلى الحافظة بنجاح.", "نسخ الرابط", MessageBoxButton.OK, MessageBoxImage.Information)
            End If
        End Sub

        Private Sub BtnPrint80_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.PrintQr80mmCommand?.Execute(item)
            End If
        End Sub

        Private Sub BtnPrint58_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.PrintQr58mmCommand?.Execute(item)
            End If
        End Sub

        Private Sub BtnPrintWpf_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.PrintQrWpfCommand?.Execute(item)
            End If
        End Sub

        Private Sub BtnRefund_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, PaymentLinkRecord)
            Dim vm = GetParentViewModel()
            If item IsNot Nothing AndAlso vm IsNot Nothing Then
                vm.SelectedLink = item
                vm.OpenRefundDialogCommand?.Execute(item)
            End If
        End Sub

    End Class

End Namespace

