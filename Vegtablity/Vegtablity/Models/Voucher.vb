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
        Public Property PaymentMethod As String           ' Cash / Bank
        Public Property UserID As Integer?
        Public Property UserName As String                ' من JOIN
        Public Property IsPosted As Boolean
    End Class
End Namespace
