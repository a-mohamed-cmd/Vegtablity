Namespace Models
    Public Class Partner
        Public Property PartnerID As Integer
        Public Property PartnerName As String
        Public Property PartnerType As String          ' Supplier / Customer
        Public Property Phone As String
        Public Property Address As String
        Public Property CurrentBalance As Decimal
        Public Property IsActive As Boolean
        Public Property AccountID As Integer?
        Public Property AccountCode As String          ' رقم الحساب المحاسبي

        ''' <summary>النص المعروض في قائمة البحث: (م) اسم المورد [كود] أو (ع) اسم العميل [كود]</summary>
        Public ReadOnly Property SearchText As String
            Get
                Dim typeLabel = If(PartnerType = "Supplier", "(م)", "(ع)")
                Dim code = If(String.IsNullOrEmpty(AccountCode), "", $" [{AccountCode}]")
                Return $"{typeLabel} {PartnerName}{code}"
            End Get
        End Property
    End Class
End Namespace
