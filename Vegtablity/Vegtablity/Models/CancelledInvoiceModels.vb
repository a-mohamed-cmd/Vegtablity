Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel

Namespace Models
    ''' <summary>
    ''' سجل الفاتورة المحذوفة / الملغاة المقروء من [Sales].[CancelledInvoicesArchive]
    ''' </summary>
    Public Class CancelledInvoiceDbRow
        Public Property ArchiveID As Integer
        Public Property OriginalInvID As Integer
        Public Property InvType As String
        Public Property InvDate As DateTime
        Public Property PartnerID As Integer?
        Public Property PartnerName As String
        Public Property WarehouseID As Integer?
        Public Property WarehouseName As String
        Public Property TotalAmount As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property PaidAmount As Decimal
        Public Property Remainder As Decimal
        Public Property ReferenceNo As String
        Public Property Notes As String
        Public Property OriginalUserID As Integer?
        Public Property OriginalUserName As String
        Public Property CancelledByUserID As Integer?
        Public Property CancelledByUserName As String
        Public Property CancelledAt As DateTime
        Public Property InvoiceSnapshotJson As String
    End Class

    Public Class CancelledInvoiceDetailItem
        Public Property DetID As Integer
        Public Property InvID As Integer
        Public Property ProductID As Integer
        Public Property Barcode As String
        Public Property ProductName As String
        Public Property ProductNameEn As String
        Public Property UnitName As String
        Public Property UnitPrice As Decimal
        Public Property Quantity As Decimal
        Public Property TotalPrice As Decimal
        Public Property CostPrice As Decimal
        Public Property DiscountAmount As Decimal
    End Class

    Public Class CancelledTempOrderInfo
        Public Property TempOrderID As Integer
        Public Property InvID As Integer
        Public Property CustomerName As String
        Public Property Phone As String
        Public Property Address As String
        Public Property DeliveryDate As DateTime?
        Public Property DeliveryTime As String
        Public Property CreatedAt As DateTime?
    End Class

    Public Class CancelledPaymentSplitItem
        Public Property SplitID As Integer
        Public Property InvID As Integer
        Public Property PaymentAccountID As Integer
        Public Property AccountName As String
        Public Property AccountCode As String
        Public Property Amount As Decimal
        Public Property CreatedAt As DateTime?
    End Class

    Public Class CancelledPaymentLinkItem
        Public Property LinkID As Integer
        Public Property InvID As Integer
        Public Property ProviderID As Integer
        Public Property ProviderCode As String
        Public Property ProviderNameAr As String
        Public Property ExternalChargeID As String
        Public Property PaymentUrl As String
        Public Property Amount As Decimal
        Public Property CurrencyCode As String
        Public Property LinkStatus As String
        Public Property CreatedAt As DateTime?
        Public Property PaidAt As DateTime?
        Public Property Notes As String
    End Class

    Public Class CancelledPaymentLinkAllocationItem
        Public Property AllocationID As Integer
        Public Property LinkID As Integer
        Public Property InvID As Integer
        Public Property AllocatedAmount As Decimal
        Public Property ProviderCode As String
        Public Property LinkStatus As String
        Public Property LinkTotalAmount As Decimal
        Public Property ExternalChargeID As String
    End Class

    Public Class CancelledTalabatOrderItem
        Public Property TalabatOrderID As Integer
        Public Property OrderCode As String
        Public Property ShortCode As String
        Public Property ExpeditionType As String
        Public Property PaymentType As String
        Public Property GrandTotal As Decimal
        Public Property CurrencyCode As String
        Public Property OrderStatus As String
        Public Property CustomerName As String
        Public Property CustomerPhone As String
        Public Property DeliveryAddress As String
        Public Property CreatedAt As DateTime?
    End Class

    ''' <summary>
    ''' النموذج الكامل المعزول لعرض وطباعة الفاتورة الملغاة بعد فك JSON Snapshot
    ''' </summary>
    Public Class CancelledInvoiceSnapshot
        Public Property ArchiveID As Integer
        Public Property OriginalInvID As Integer
        Public Property InvType As String
        Public Property InvDate As DateTime
        Public Property PartnerID As Integer?
        Public Property PartnerName As String
        Public Property PartnerPhone As String
        Public Property WarehouseID As Integer?
        Public Property WarehouseName As String
        Public Property AccountCode As String
        Public Property PaymentAccountName As String
        Public Property TotalAmount As Decimal
        Public Property Discount As Decimal
        Public Property NetAmount As Decimal
        Public Property PaidAmount As Decimal
        Public Property Remainder As Decimal
        Public Property ReferenceNo As String
        Public Property Notes As String
        Public Property OriginalUserName As String
        Public Property CancelledByUserID As Integer?
        Public Property CancelledByUserName As String
        Public Property CancelledAt As DateTime
        Public Property OriginalIsPosted As Boolean
        Public Property RawSnapshotJson As String

        Public Property Details As ObservableCollection(Of CancelledInvoiceDetailItem)
        Public Property TempOrderInfo As CancelledTempOrderInfo
        Public Property PaymentSplits As ObservableCollection(Of CancelledPaymentSplitItem)
        Public Property PaymentLinks As ObservableCollection(Of CancelledPaymentLinkItem)
        Public Property PaymentLinkAllocations As ObservableCollection(Of CancelledPaymentLinkAllocationItem)
        Public Property TalabatOrders As ObservableCollection(Of CancelledTalabatOrderItem)

        Public Sub New()
            Details = New ObservableCollection(Of CancelledInvoiceDetailItem)()
            PaymentSplits = New ObservableCollection(Of CancelledPaymentSplitItem)()
            PaymentLinks = New ObservableCollection(Of CancelledPaymentLinkItem)()
            PaymentLinkAllocations = New ObservableCollection(Of CancelledPaymentLinkAllocationItem)()
            TalabatOrders = New ObservableCollection(Of CancelledTalabatOrderItem)()
        End Sub

        Public ReadOnly Property InvTypeLabel As String
            Get
                Return If(String.Equals(InvType, "Purchase", StringComparison.OrdinalIgnoreCase), "فاتورة مشتريات", "فاتورة مبيعات")
            End Get
        End Property

        Public ReadOnly Property IsSalesInvoice As Boolean
            Get
                Return Not String.Equals(InvType, "Purchase", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property HasTempOrderInfo As Boolean
            Get
                Return TempOrderInfo IsNot Nothing AndAlso
                       (Not String.IsNullOrWhiteSpace(TempOrderInfo.CustomerName) OrElse
                        Not String.IsNullOrWhiteSpace(TempOrderInfo.Phone) OrElse
                        Not String.IsNullOrWhiteSpace(TempOrderInfo.Address))
            End Get
        End Property

        Public ReadOnly Property HasPaymentSplits As Boolean
            Get
                Return PaymentSplits IsNot Nothing AndAlso PaymentSplits.Count > 0
            End Get
        End Property

        Public ReadOnly Property HasPaymentLinks As Boolean
            Get
                Return (PaymentLinks IsNot Nothing AndAlso PaymentLinks.Count > 0) OrElse
                       (PaymentLinkAllocations IsNot Nothing AndAlso PaymentLinkAllocations.Count > 0)
            End Get
        End Property

        Public ReadOnly Property HasTalabatOrders As Boolean
            Get
                Return TalabatOrders IsNot Nothing AndAlso TalabatOrders.Count > 0
            End Get
        End Property

        ''' <summary>
        ''' تحويل الفاتورة المؤرشفة إلى كائن طباعة وتصدير PDF قياسي دون أي اتصال بجداول الفواتير النشطة
        ''' </summary>
        Public Function ToInvoiceReportData() As InvoiceReportData
            Dim headerNote As String = If(String.IsNullOrWhiteSpace(Notes),
                                          $"[ملغاة / CANCELLED - أرشيف #{ArchiveID}]",
                                          $"[ملغاة / CANCELLED - أرشيف #{ArchiveID}] {Notes}")

            Dim hdr As New InvoiceReportHeader() With {
                .InvID = OriginalInvID,
                .InvDate = InvDate,
                .TotalAmount = TotalAmount,
                .PartnerName = If(String.IsNullOrWhiteSpace(PartnerName), "—", PartnerName),
                .AccountCode = If(AccountCode, ""),
                .Notes = headerNote,
                .Remainder = Remainder,
                .PaidAmount = PaidAmount,
                .NetAmount = NetAmount
            }

            Dim detList As New List(Of InvoiceReportItem)()
            If Details IsNot Nothing Then
                For Each d In Details
                    detList.Add(New InvoiceReportItem() With {
                        .ProductName = If(String.IsNullOrWhiteSpace(d.ProductName), $"صنف #{d.ProductID}", d.ProductName),
                        .ProductNameEn = If(d.ProductNameEn, ""),
                        .UnitName = If(d.UnitName, ""),
                        .Quantity = d.Quantity,
                        .UnitPrice = d.UnitPrice,
                        .TotalPrice = d.TotalPrice
                    })
                Next
            End If

            Return New InvoiceReportData() With {
                .Header = hdr,
                .Details = detList
            }
        End Function
    End Class
End Namespace
