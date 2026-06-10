Namespace Models
    Public Class Shift
        Public Property ShiftID As Integer
        Public Property UserID As Integer
        Public Property UserName As String
        Public Property StartTime As DateTime
        Public Property EndTime As DateTime?
        Public Property StartingCash As Decimal
        Public Property EndingCash As Decimal?
        Public Property Status As String

        ' Summary properties from sp_Shift_GetSummary
        Public Property TotalSales As Decimal
        Public Property TotalPurchases As Decimal
        Public Property SalesCount As Integer
        Public Property PurchasesCount As Integer
        Public Property TotalPaidSales As Decimal
        Public Property TotalRemainder As Decimal
        Public Property TotalPaidPurchases As Decimal
        Public Property TotalPurchasesRemainder As Decimal
        Public Property TotalReceiptVouchers As Decimal
        Public Property TotalPaymentVouchers As Decimal
    End Class
End Namespace
