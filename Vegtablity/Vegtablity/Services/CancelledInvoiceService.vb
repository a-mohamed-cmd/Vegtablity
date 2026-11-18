Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Linq
Imports System.Web.Script.Serialization
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    ''' <summary>
    ''' خدمة مستقلة تماماً لإدارة وقراءة أرشيف الفواتير المحذوفة / الملغاة (Cancel)
    ''' تستدعي فقط الإجراءات المخزنة المعزولة [Sales].[sp_CancelledInvoice_*]
    ''' </summary>
    Public Class CancelledInvoiceService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ''' <summary>
        ''' جلب قائمة الفواتير الملغاة من جدول الأرشيف مع دعم الترقيم والبحث (بنفس هيكل InvoiceListItem)
        ''' </summary>
        Public Function GetCancelledInvoicesPaged(
                Optional invType As String = Nothing,
                Optional dateFrom As Date? = Nothing,
                Optional dateTo As Date? = Nothing,
                Optional searchText As String = Nothing,
                Optional pageNumber As Integer = 0,
                Optional pageSize As Integer = 20) As (Items As List(Of InvoiceListItem), TotalCount As Integer)

            Using conn As IDbConnection = _dbHelper.GetConnection()
                Using multi = conn.QueryMultiple(
                        Helpers.StoredProcedures.SP_CANCELLED_INVOICE_GET_PAGED,
                        New With {
                            .InvType = invType,
                            .DateFrom = dateFrom,
                            .DateTo = dateTo,
                            .SearchText = searchText,
                            .PageNumber = pageNumber,
                            .PageSize = pageSize
                        },
                        commandType:=CommandType.StoredProcedure)
                    Dim items = multi.Read(Of InvoiceListItem)().ToList()
                    Dim total = multi.ReadSingleOrDefault(Of Integer)()
                    Return (items, total)
                End Using
            End Using
        End Function

        ''' <summary>
        ''' جلب كامل بيانات الفاتورة الملغاة وفك لقطة JSON المحفوظة للعرض والطباعة فقط
        ''' </summary>
        Public Function GetCancelledInvoiceDetails(
                Optional archiveID As Integer? = Nothing,
                Optional originalInvID As Integer? = Nothing) As CancelledInvoiceSnapshot

            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim row = conn.QueryFirstOrDefault(Of CancelledInvoiceDbRow)(
                    Helpers.StoredProcedures.SP_CANCELLED_INVOICE_GET_BY_ID,
                    New With {
                        .ArchiveID = archiveID,
                        .OriginalInvID = originalInvID
                    },
                    commandType:=CommandType.StoredProcedure)

                If row Is Nothing Then Return Nothing
                Return BuildSnapshotFromRow(row)
            End Using
        End Function

        Private Function BuildSnapshotFromRow(row As CancelledInvoiceDbRow) As CancelledInvoiceSnapshot
            Dim snap As New CancelledInvoiceSnapshot() With {
                .ArchiveID = row.ArchiveID,
                .OriginalInvID = row.OriginalInvID,
                .InvType = row.InvType,
                .InvDate = row.InvDate,
                .PartnerID = row.PartnerID,
                .PartnerName = If(String.IsNullOrWhiteSpace(row.PartnerName), "—", row.PartnerName),
                .WarehouseID = row.WarehouseID,
                .WarehouseName = If(String.IsNullOrWhiteSpace(row.WarehouseName), "—", row.WarehouseName),
                .TotalAmount = row.TotalAmount,
                .Discount = row.Discount,
                .NetAmount = row.NetAmount,
                .PaidAmount = row.PaidAmount,
                .Remainder = row.Remainder,
                .ReferenceNo = row.ReferenceNo,
                .Notes = row.Notes,
                .OriginalUserName = row.OriginalUserName,
                .CancelledByUserID = row.CancelledByUserID,
                .CancelledByUserName = If(String.IsNullOrWhiteSpace(row.CancelledByUserName), "النظام", row.CancelledByUserName),
                .CancelledAt = row.CancelledAt,
                .RawSnapshotJson = row.InvoiceSnapshotJson
            }

            If String.IsNullOrWhiteSpace(row.InvoiceSnapshotJson) Then Return snap

            Try
                Dim ser As New JavaScriptSerializer() With {.MaxJsonLength = Integer.MaxValue}
                Dim root = TryCast(ser.DeserializeObject(row.InvoiceSnapshotJson), Dictionary(Of String, Object))
                If root Is Nothing Then Return snap

                ' 1. InvoiceHeader
                Dim hdr = GetDict(root, "InvoiceHeader")
                If hdr IsNot Nothing Then
                    snap.PartnerPhone = GetStr(hdr, "PartnerPhone")
                    snap.PaymentAccountName = GetStr(hdr, "PaymentAccountName")
                    snap.AccountCode = GetStr(hdr, "PaymentAccountCode")
                    Dim pName = GetStr(hdr, "PartnerName")
                    If Not String.IsNullOrWhiteSpace(pName) Then snap.PartnerName = pName
                    Dim wName = GetStr(hdr, "WarehouseName")
                    If Not String.IsNullOrWhiteSpace(wName) Then snap.WarehouseName = wName
                    Dim uName = GetStr(hdr, "UserName")
                    If Not String.IsNullOrWhiteSpace(uName) Then snap.OriginalUserName = uName
                    snap.OriginalIsPosted = GetBool(hdr, "IsPosted")
                End If

                ' 2. AuditMeta
                Dim audit = GetDict(root, "AuditMeta")
                If audit IsNot Nothing Then
                    Dim cBy = GetStr(audit, "CancelledByUserName")
                    If Not String.IsNullOrWhiteSpace(cBy) Then snap.CancelledByUserName = cBy
                    If audit.ContainsKey("OriginalIsPosted") Then
                        snap.OriginalIsPosted = GetBool(audit, "OriginalIsPosted")
                    End If
                End If

                ' 3. InvoiceDetails
                For Each d In GetListOfDict(root, "InvoiceDetails")
                    snap.Details.Add(New CancelledInvoiceDetailItem() With {
                        .DetID = GetInt(d, "DetID"),
                        .InvID = GetInt(d, "InvID"),
                        .ProductID = GetInt(d, "ProductID"),
                        .Barcode = GetStr(d, "Barcode"),
                        .ProductName = GetStr(d, "ProductName"),
                        .ProductNameEn = GetStr(d, "ProductNameEn"),
                        .UnitName = GetStr(d, "UnitName"),
                        .UnitPrice = GetDec(d, "UnitPrice"),
                        .Quantity = GetDec(d, "Quantity"),
                        .TotalPrice = GetDec(d, "TotalPrice"),
                        .CostPrice = GetDec(d, "CostPrice"),
                        .DiscountAmount = GetDec(d, "DiscountAmount")
                    })
                Next

                ' 4. TempOrderInfo
                Dim temp = GetDict(root, "TempOrderInfo")
                If temp IsNot Nothing Then
                    snap.TempOrderInfo = New CancelledTempOrderInfo() With {
                        .TempOrderID = GetInt(temp, "TempOrderID"),
                        .InvID = GetInt(temp, "InvID"),
                        .CustomerName = GetStr(temp, "CustomerName"),
                        .Phone = GetStr(temp, "Phone"),
                        .Address = GetStr(temp, "Address"),
                        .DeliveryDate = GetNullableDate(temp, "DeliveryDate"),
                        .DeliveryTime = GetStr(temp, "DeliveryTime"),
                        .CreatedAt = GetNullableDate(temp, "CreatedAt")
                    }
                End If

                ' 5. InvoicePaymentSplits
                For Each s In GetListOfDict(root, "InvoicePaymentSplits")
                    snap.PaymentSplits.Add(New CancelledPaymentSplitItem() With {
                        .SplitID = GetInt(s, "SplitID"),
                        .InvID = GetInt(s, "InvID"),
                        .PaymentAccountID = GetInt(s, "PaymentAccountID"),
                        .AccountName = GetStr(s, "AccountName"),
                        .AccountCode = GetStr(s, "AccountCode"),
                        .Amount = GetDec(s, "Amount"),
                        .CreatedAt = GetNullableDate(s, "CreatedAt")
                    })
                Next

                ' 6. InvoicePaymentLinks
                For Each l In GetListOfDict(root, "InvoicePaymentLinks")
                    snap.PaymentLinks.Add(New CancelledPaymentLinkItem() With {
                        .LinkID = GetInt(l, "LinkID"),
                        .InvID = GetInt(l, "InvID"),
                        .ProviderID = GetInt(l, "ProviderID"),
                        .ProviderCode = GetStr(l, "ProviderCode"),
                        .ProviderNameAr = GetStr(l, "ProviderNameAr"),
                        .ExternalChargeID = GetStr(l, "ExternalChargeID"),
                        .PaymentUrl = GetStr(l, "PaymentUrl"),
                        .Amount = GetDec(l, "Amount"),
                        .CurrencyCode = GetStr(l, "CurrencyCode"),
                        .LinkStatus = GetStr(l, "LinkStatus"),
                        .CreatedAt = GetNullableDate(l, "CreatedAt"),
                        .PaidAt = GetNullableDate(l, "PaidAt"),
                        .Notes = GetStr(l, "Notes")
                    })
                Next

                ' 7. InvoicePaymentLinkAllocations
                For Each a In GetListOfDict(root, "InvoicePaymentLinkAllocations")
                    snap.PaymentLinkAllocations.Add(New CancelledPaymentLinkAllocationItem() With {
                        .AllocationID = GetInt(a, "AllocationID"),
                        .LinkID = GetInt(a, "LinkID"),
                        .InvID = GetInt(a, "InvID"),
                        .AllocatedAmount = GetDec(a, "AllocatedAmount"),
                        .ProviderCode = GetStr(a, "ProviderCode"),
                        .LinkStatus = GetStr(a, "LinkStatus"),
                        .LinkTotalAmount = GetDec(a, "LinkTotalAmount"),
                        .ExternalChargeID = GetStr(a, "ExternalChargeID")
                    })
                Next

                ' 8. TalabatOrders
                For Each t In GetListOfDict(root, "TalabatOrders")
                    snap.TalabatOrders.Add(New CancelledTalabatOrderItem() With {
                        .TalabatOrderID = GetInt(t, "TalabatOrderID"),
                        .OrderCode = GetStr(t, "OrderCode"),
                        .ShortCode = GetStr(t, "ShortCode"),
                        .ExpeditionType = GetStr(t, "ExpeditionType"),
                        .PaymentType = GetStr(t, "PaymentType"),
                        .GrandTotal = GetDec(t, "GrandTotal"),
                        .CurrencyCode = GetStr(t, "CurrencyCode"),
                        .OrderStatus = GetStr(t, "OrderStatus"),
                        .CustomerName = GetStr(t, "CustomerName"),
                        .CustomerPhone = GetStr(t, "CustomerPhone"),
                        .DeliveryAddress = GetStr(t, "DeliveryAddress"),
                        .CreatedAt = GetNullableDate(t, "CreatedAt")
                    })
                Next
            Catch
                ' في حال وجود نقص في تحليل JSON تبقى البيانات الأساسية للرأس متاحة للعرض
            End Try

            Return snap
        End Function

        Private Shared Function GetDict(parent As Dictionary(Of String, Object), key As String) As Dictionary(Of String, Object)
            If parent Is Nothing OrElse Not parent.ContainsKey(key) OrElse parent(key) Is Nothing Then Return Nothing
            Return TryCast(parent(key), Dictionary(Of String, Object))
        End Function

        Private Shared Function GetListOfDict(parent As Dictionary(Of String, Object), key As String) As List(Of Dictionary(Of String, Object))
            Dim list As New List(Of Dictionary(Of String, Object))()
            If parent Is Nothing OrElse Not parent.ContainsKey(key) OrElse parent(key) Is Nothing Then Return list

            Dim arr = TryCast(parent(key), IEnumerable)
            If arr Is Nothing Then Return list
            For Each item In arr
                Dim d = TryCast(item, Dictionary(Of String, Object))
                If d IsNot Nothing Then list.Add(d)
            Next
            Return list
        End Function

        Private Shared Function GetStr(d As Dictionary(Of String, Object), key As String) As String
            If d Is Nothing OrElse Not d.ContainsKey(key) OrElse d(key) Is Nothing Then Return ""
            Return Convert.ToString(d(key), CultureInfo.InvariantCulture)
        End Function

        Private Shared Function GetInt(d As Dictionary(Of String, Object), key As String) As Integer
            If d Is Nothing OrElse Not d.ContainsKey(key) OrElse d(key) Is Nothing Then Return 0
            Dim val As Integer = 0
            Integer.TryParse(Convert.ToString(d(key), CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, val)
            Return val
        End Function

        Private Shared Function GetDec(d As Dictionary(Of String, Object), key As String) As Decimal
            If d Is Nothing OrElse Not d.ContainsKey(key) OrElse d(key) Is Nothing Then Return 0D
            Dim val As Decimal = 0D
            Decimal.TryParse(Convert.ToString(d(key), CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, val)
            Return val
        End Function

        Private Shared Function GetBool(d As Dictionary(Of String, Object), key As String) As Boolean
            If d Is Nothing OrElse Not d.ContainsKey(key) OrElse d(key) Is Nothing Then Return False
            Dim raw = d(key)
            If TypeOf raw Is Boolean Then Return DirectCast(raw, Boolean)
            Dim str = Convert.ToString(raw, CultureInfo.InvariantCulture)
            Return str = "1" OrElse String.Equals(str, "True", StringComparison.OrdinalIgnoreCase)
        End Function

        Private Shared Function GetNullableDate(d As Dictionary(Of String, Object), key As String) As DateTime?
            If d Is Nothing OrElse Not d.ContainsKey(key) OrElse d(key) Is Nothing Then Return Nothing
            Dim dt As DateTime
            If DateTime.TryParse(Convert.ToString(d(key), CultureInfo.InvariantCulture), CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, dt) Then
                Return dt
            End If
            Return Nothing
        End Function
    End Class
End Namespace
