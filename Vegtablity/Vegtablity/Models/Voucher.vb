Namespace Models
    Public Class Voucher
        Public Property VoucherID As Integer
        Public Property VoucherNo As Integer             ' رقم السند التلقائي
        Public Property VoucherType As String            ' Receipt / Payment
        Public Property VoucherDate As DateTime
        Public Property PartnerID As Integer?
        Public Property PartnerName As String             ' من JOIN
        Public Property AccountID As Integer?
        Public Property AccountName As String             ' من JOIN
        Public Property Amount As Decimal
        Public Property Description As String
        Public Property PaymentMethod As String           ' معرف حساب طريقة الدفع (Cash/Bank AccountID)

        Private _paymentMethodName As String
        Public Property PaymentMethodName As String       ' اسم حساب طريقة الدفع من JOIN
            Get
                If Not String.IsNullOrEmpty(_paymentMethodName) Then
                    Return _paymentMethodName
                End If
                Return If(PaymentMethod, "")
            End Get
            Set(value As String)
                _paymentMethodName = value
            End Set
        End Property

        Public Property UserID As Integer?
        Public Property UserName As String                ' من JOIN
        Public Property IsPosted As Boolean
    End Class
End Namespace
