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
    End Class
End Namespace
