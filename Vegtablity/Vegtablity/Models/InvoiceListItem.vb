Namespace Models
    ''' <summary>Lightweight model used in Invoice Dashboard list</summary>
    Public Class InvoiceListItem
        Public Property InvID As Integer
        Public Property InvType As String         ' "Sales" or "Purchase"
        Public Property InvDate As Date
        Public Property PartnerID As Integer?
        Public Property PartnerName As String
        Public Property WarehouseID As Integer?
        Public Property WarehouseName As String
        Public Property TotalAmount As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property PaidAmount As Decimal
        Public Property Remainder As Decimal
        Public Property IsPosted As Boolean
        Public Property ReferenceNo As String
        Public Property Notes As String

        ''' <summary>Human-readable label for InvType</summary>
        Public ReadOnly Property InvTypeLabel As String
            Get
                Return If(InvType = "Sales", "مبيعات", "مشتريات")
            End Get
        End Property

        ''' <summary>True when invoice is posted and has remaining balance</summary>
        Public ReadOnly Property CanAddPayment As Boolean
            Get
                Return IsPosted AndAlso Remainder > 0
            End Get
        End Property
    End Class

    ''' <summary>Dashboard KPI stats returned by sp_Invoice_GetDashboardStats</summary>
    Public Class DashboardStats
        Public Property TotalSalesCount As Integer
        Public Property TotalSalesAmount As Decimal
        Public Property SalesRemainder As Decimal
        Public Property TotalPurchaseCount As Integer
        Public Property TotalPurchaseAmount As Decimal
        Public Property PurchaseRemainder As Decimal
        Public Property TotalInvoices As Integer
    End Class
End Namespace
