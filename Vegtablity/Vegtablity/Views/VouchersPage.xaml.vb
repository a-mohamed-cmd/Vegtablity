Namespace Views
    Partial Public Class VouchersPage
        Private _voucherType As String

        Public Sub New()
            InitializeComponent()
        End Sub

        Public Sub New(voucherType As String)
            InitializeComponent()
            _voucherType = voucherType

            ' اختيار التبويب المناسب تلقائياً
            If voucherType = "Payment" Then
                VoucherTabControl.SelectedIndex = 1
            Else
                VoucherTabControl.SelectedIndex = 0
            End If
        End Sub
    End Class
End Namespace
