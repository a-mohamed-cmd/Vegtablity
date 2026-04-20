Imports System
Imports System.Collections.Generic

Namespace Models
    Public Class InvoiceReportData
        Public Property Header As InvoiceReportHeader
        Public Property Details As List(Of InvoiceReportItem)
    End Class

    Public Class InvoiceReportHeader
        Public Property InvID As Integer
        Public Property InvDate As DateTime
        Public Property TotalAmount As Decimal
        Public Property PartnerName As String
        Public Property AccountCode As String
        Public Property Notes As String
    End Class

    Public Class InvoiceReportItem
        Public Property ProductName As String
        Public Property ProductNameEn As String
        Public Property UnitName As String
        Public Property Quantity As Decimal
        Public Property UnitPrice As Decimal
        Public Property TotalPrice As Decimal
    End Class
End Namespace
