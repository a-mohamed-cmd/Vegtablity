Imports System.ComponentModel

Namespace Models

    ''' <summary>
    ''' ملخص لوحة المعلومات (المبيعات، المشتريات، الأصناف، العملاء)
    ''' </summary>
    Public Class DashboardSummary
        Public Property TodaySales As Decimal
        Public Property TodayPurchases As Decimal
        Public Property TotalProducts As Integer
        Public Property TotalCustomers As Integer
    End Class

    ''' <summary>
    ''' بيانات المبيعات للرسم البياني
    ''' </summary>
    Public Class DashboardSalesChart
        Public Property DateValue As DateTime
        Public Property TotalSales As Decimal
    End Class

    ''' <summary>
    ''' تنبيهات نقص المخزون
    ''' </summary>
    Public Class DashboardAlertProduct
        Public Property ProductID As Integer
        Public Property ProductName As String
        Public Property CurrentQty As Decimal
        Public Property AlertQty As Decimal
        
        ' Helpers for UI
        Public ReadOnly Property StatusColor As String
            Get
                If CurrentQty <= 0 Then Return "#e74c3c" ' Red (Out of Stock)
                Return "#f39c12" ' Orange (Low Stock)
            End Get
        End Property

        Public ReadOnly Property StatusText As String
            Get
                If CurrentQty <= 0 Then Return "نفد"
                Return "كمية منخفضة"
            End Get
        End Property
    End Class

    ''' <summary>
    ''' مديونيات العملاء والموردين
    ''' </summary>
    Public Class DashboardPartnerDebt
        Public Property PartnerID As Integer
        Public Property PartnerName As String
        Public Property Balance As Decimal
    End Class

End Namespace
