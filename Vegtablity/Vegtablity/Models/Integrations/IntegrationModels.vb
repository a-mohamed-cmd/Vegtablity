Imports System

Namespace Models.Integrations

    ''' <summary>
    ''' خيار حساب محاسبي لقوائم تخصيص طرفي القيد (المدين والدائن) في إعدادات البوابات
    ''' </summary>
    Public Class GatewayAccountOption
        Public Property AccountID As Integer?
        Public Property AccountCode As String = ""
        Public Property AccountName As String = ""
        Public Property DisplayText As String = ""
    End Class

    ''' <summary>
    ''' نموذج إعدادات بوابة الدفع أو منصة التوصيل (معزول تماماً عن النماذج الحالية)
    ''' </summary>
    Public Class IntegrationProviderConfig
        Public Property ProviderID As Integer
        Public Property ProviderCode As String = ""
        Public Property ProviderNameAr As String = ""
        Public Property ProviderNameEn As String = ""
        Public Property ProviderCategory As String = "PAYMENT_GATEWAY"
        Public Property IsEnabledInCompany As Boolean = False
        Public Property IsConfigured As Boolean = False
        Public Property EnvironmentMode As String = "Sandbox"
        Public Property BaseUrl As String = ""
        Public Property MerchantID As String = ""
        Public Property PublicKey As String = ""
        Public Property SecretKeyEncrypted As String = ""
        Public Property WebhookSecret As String = ""
        Public Property CallbackUrl As String = ""
        Public Property DefaultCurrency As String = "KWD"
        Public Property CommissionPercent As Decimal = 0D
        Public Property FixedFee As Decimal = 0D
        Public Property LinkedAccountID As Integer?
        Public Property LinkedAccountCode As String = ""
        Public Property LinkedAccountName As String = ""
        Public Property DefaultCreditAccountID As Integer?
        Public Property DefaultCreditAccountCode As String = ""
        Public Property DefaultCreditAccountName As String = ""
        Public Property CommissionAccountID As Integer?
        Public Property CommissionAccountCode As String = ""
        Public Property CommissionAccountName As String = ""
        Public Property RefundDebitAccountID As Integer?
        Public Property RefundDebitAccountCode As String = ""
        Public Property RefundDebitAccountName As String = ""
        Public Property RefundCreditAccountID As Integer?
        Public Property RefundCreditAccountCode As String = ""
        Public Property RefundCreditAccountName As String = ""
        Public Property PartnerID As Integer?
        Public Property LinkedPartnerName As String = ""

        ' === الإضافات والخصائص التخصصية (7 Add-ons) ===
        Public Property AutoSendLinkOnInvoiceSave As Boolean = False
        Public Property PrintQrOnPos80mm As Boolean = True
        Public Property PrintQrOnPos58mm As Boolean = False
        Public Property PrintQrOnWpfInvoice As Boolean = False
        Public Property AutoSendWhatsApp As Boolean = True
        Public Property AutoSendSms As Boolean = False
        Public Property LinkExpiryHours As Integer = 24
        Public Property EnableConsolidatedLinks As Boolean = True
        Public Property DeductCommissionOnShiftClose As Boolean = False
        Public Property EnableGatewayRefunds As Boolean = False
        Public Property AllowPartialRefunds As Boolean = True
        Public Property AutoPostRefundJournalEntry As Boolean = True
        Public Property RefundChargeOnCustomer As Boolean = False
        Public Property ServiceChargeOnCustomer As Boolean = False

        ' === حالة الاتصال والتشخيص ===
        Public Property ConnectionStatus As String = "Disconnected"
        Public Property StatusMessageAr As String = ""
        Public Property LastTestedAt As DateTime?
        Public Property UpdatedAt As DateTime

        Public ReadOnly Property IsConnectionVerified As Boolean
            Get
                Return String.Equals(ConnectionStatus, "SandboxVerified", StringComparison.OrdinalIgnoreCase) OrElse
                       String.Equals(ConnectionStatus, "LiveVerified", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property IsDeliveryPlatform As Boolean
            Get
                Return String.Equals(ProviderCategory, "DELIVERY_PLATFORM", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property IsPaymentGateway As Boolean
            Get
                Return String.Equals(ProviderCategory, "PAYMENT_GATEWAY", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property StatusBadgeText As String
            Get
                Select Case ConnectionStatus
                    Case "LiveVerified"
                        Return "🟢 متصل ومُفعل (بيئة فعلية Live)"
                    Case "SandboxVerified"
                        Return "🟡 متصل ومُفعل (بيئة تجريبية Sandbox)"
                    Case "Error"
                        Return "🔴 خطأ في الاتصال أو المفاتيح"
                    Case Else
                        Return "⚪ غير مُعدّ (بانتظار اختبار الاتصال)"
                End Select
            End Get
        End Property

        Public ReadOnly Property PrintOptionsSummary As String
            Get
                Dim list As New List(Of String)()
                If PrintQrOnPos80mm Then list.Add("80mm")
                If PrintQrOnPos58mm Then list.Add("58mm")
                If PrintQrOnWpfInvoice Then list.Add("WPF")
                Return If(list.Count > 0, String.Join(",", list), "None")
            End Get
        End Property
    End Class

    ''' <summary>
    ''' نتيجة اختبار الاتصال الحي مع البوابة
    ''' </summary>
    Public Class ConnectionTestResult
        Public Property IsSuccess As Boolean = False
        Public Property VerifiedStatus As String = "Disconnected" ' SandboxVerified | LiveVerified | Error
        Public Property MessageAr As String = ""
        Public Property NextStepGuidanceAr As String = ""
        Public Property RawResponse As String = ""
        Public Property LatencyMs As Long = 0
    End Class

    ''' <summary>
    ''' طلب إنشاء رابط دفع إلكتروني (مفرد أو مجمع)
    ''' </summary>
    Public Class PaymentLinkRequest
        Public Property InvID As Integer
        Public Property PartnerID As Integer?
        Public Property ProviderID As Integer
        Public Property ProviderCode As String = ""
        Public Property Amount As Decimal
        Public Property CurrencyCode As String = "KWD"
        Public Property CustomerName As String = ""
        Public Property CustomerPhone As String = ""
        Public Property CustomerEmail As String = ""
        Public Property Description As String = ""
        Public Property SendViaWhatsApp As Boolean = True
        Public Property SendViaSms As Boolean = False
        Public Property SendViaEmail As Boolean = False
        Public Property IsConsolidated As Boolean = False
        Public Property ConsolidatedInvoicesCsv As String = ""
        Public Property CreatedByUserID As Integer = 1
        Public Property ShiftID As Integer?
    End Class

    ''' <summary>
    ''' نتيجة إنشاء رابط الدفع من البوابة
    ''' </summary>
    Public Class PaymentLinkCreationResult
        Public Property IsSuccess As Boolean = False
        Public Property ExternalChargeID As String = ""
        Public Property ExternalInvoiceID As String = ""
        Public Property PaymentUrl As String = ""
        Public Property QrCodePayload As String = ""
        Public Property RawJson As String = ""
        Public Property ErrorMessageAr As String = ""
    End Class

    ''' <summary>
    ''' طلب استرداد المبلغ (Refund) عبر البوابة
    ''' </summary>
    Public Class PaymentRefundRequest
        Public Property LinkID As Integer
        Public Property ExternalChargeID As String = ""
        Public Property RefundAmount As Decimal
        Public Property CurrencyCode As String = "KWD"
        Public Property Reason As String = "Customer Request"
        Public Property RefundChargeOnCustomer As Boolean = False
        Public Property ServiceChargeOnCustomer As Boolean = False
        Public Property UserID As Integer = 1
    End Class

    ''' <summary>
    ''' نتيجة استرداد المبلغ (Refund)
    ''' </summary>
    Public Class PaymentRefundResult
        Public Property IsSuccess As Boolean = False
        Public Property ExternalRefundID As String = ""
        Public Property RefundStatus As String = ""
        Public Property MessageAr As String = ""
        Public Property RawJson As String = ""
    End Class

    ''' <summary>
    ''' سجل رابط وفاتورة الدفع الإلكتروني للعرض في شاشة المتابعة
    ''' </summary>
    Public Class PaymentLinkRecord
        Public Property LinkID As Integer
        Public Property InvID As Integer
        Public Property PartnerID As Integer?
        Public Property ProviderID As Integer
        Public Property ProviderCode As String = ""
        Public Property ProviderNameAr As String = ""
        Public Property ExternalChargeID As String = ""
        Public Property ExternalInvoiceID As String = ""
        Public Property PaymentUrl As String = ""
        Public Property QrCodePayload As String = ""
        Public Property Amount As Decimal
        Public Property CurrencyCode As String = "KWD"
        Public Property GatewayFeeAmount As Decimal
        Public Property NetAmount As Decimal
        Public Property LinkStatus As String = "Pending"
        Public Property CustomerName As String = ""
        Public Property CustomerPhone As String = ""
        Public Property CustomerEmail As String = ""
        Public Property DisplayCustomerName As String = ""
        Public Property DisplayCustomerPhone As String = ""
        Public Property SendViaWhatsApp As Boolean
        Public Property SendViaSms As Boolean
        Public Property SendViaEmail As Boolean
        Public Property PrintQrMode As String = ""
        Public Property CreatedAt As DateTime
        Public Property ExpiresAt As DateTime?
        Public Property PaidAt As DateTime?
        Public Property JournalEntryNo As Integer?
        Public Property IsConsolidated As Boolean
        Public Property RefundedAmount As Decimal
        Public Property ExternalRefundID As String = ""
        Public Property RefundReason As String = ""
        Public Property RefundedAt As DateTime?
        Public Property RefundJournalNo As Integer?
        Public Property EnableGatewayRefunds As Boolean = False
        Public Property AllowPartialRefunds As Boolean = True
        Public Property InvoiceTotalAmount As Decimal
        Public Property InvoiceNetAmount As Decimal
        Public Property InvoicePaidAmount As Decimal
        Public Property InvoiceRemainder As Decimal
        Public Property Notes As String = ""

        ' حقول الترقيم والإحصائيات الإجمالية القادمة من الإجراء المخزن (Server-Side Pagination & KPIs)
        Public Property TotalRecordsCount As Integer
        Public Property SummaryPaidAmount As Decimal
        Public Property SummaryPendingAmount As Decimal
        Public Property SummaryRefundedAmount As Decimal

        Public ReadOnly Property StatusArabic As String
            Get
                Select Case LinkStatus
                    Case "Paid"
                        Return "✅ مدفوع (Paid)"
                    Case "Pending"
                        Return "⏳ بانتظار الدفع (Pending)"
                    Case "Refunded"
                        Return "↩️ مسترد بالكامل (Refunded)"
                    Case "PartiallyRefunded"
                        Return "↩️ مسترد جزئياً (Partial Refund)"
                    Case "Expired"
                        Return "⌛ منتهي الصلاحية (Expired)"
                    Case "Cancelled"
                        Return "🚫 ملغي (Cancelled)"
                    Case Else
                        Return "❌ فشل الدفع (" & LinkStatus & ")"
                End Select
            End Get
        End Property

        ''' <summary>
        ''' يتحكم في إظهار أو إخفاء زر إرجاع المبلغ (Refund) في جدول الروابط:
        ''' يظهر فقط إذا كانت صلاحية الإرجاع مفعلة في إعدادات البوابة وكان الرابط مدفوعاً أو مسترداً جزئياً
        ''' </summary>
        Public ReadOnly Property CanRefund As Boolean
            Get
                Return EnableGatewayRefunds AndAlso
                       (String.Equals(LinkStatus, "Paid", StringComparison.OrdinalIgnoreCase) OrElse
                        String.Equals(LinkStatus, "PartiallyRefunded", StringComparison.OrdinalIgnoreCase)) AndAlso
                       (Amount - RefundedAmount) > 0D
            End Get
        End Property

        Public ReadOnly Property RemainingRefundableAmount As Decimal
            Get
                Dim remAmt = Amount - RefundedAmount
                Return If(remAmt > 0D, remAmt, 0D)
            End Get
        End Property
    End Class

    ''' <summary>
    ''' عنصر فاتورة فرعية ضمن رابط الدفع المجمّع (Consolidated Payment Link Item)
    ''' </summary>
    Public Class ConsolidatedInvoiceItem
        Public Property InvID As Integer
        Public Property Amount As Decimal

        Public ReadOnly Property DisplayBadge As String
            Get
                Return $"🧾 فاتورة #{InvID} ({Amount:N3})"
            End Get
        End Property
    End Class

    ''' <summary>
    ''' خيار فلترة حالة روابط الدفع في شاشة المتابعة
    ''' </summary>
    Public Class PaymentLinkStatusFilterItem
        Public Property StatusCode As String = "ALL"
        Public Property TitleAr As String = "الكل"
    End Class

    ''' <summary>
    ''' سجل طلب منصة Talabat للعرض في شاشة مبيعات Talabat
    ''' </summary>
    Public Class TalabatOrderRecord
        Public Property TalabatOrderID As Integer
        Public Property ProviderID As Integer
        Public Property OrderToken As String = ""
        Public Property OrderCode As String = ""
        Public Property ShortCode As String = ""
        Public Property RemoteVendorId As String = ""
        Public Property ExpeditionType As String = "delivery"
        Public Property PaymentType As String = "ONLINE"
        Public Property SubTotal As Decimal
        Public Property DeliveryFee As Decimal
        Public Property DiscountAmount As Decimal
        Public Property GrandTotal As Decimal
        Public Property CurrencyCode As String = "KWD"
        Public Property OrderStatus As String = "Received"
        Public Property CustomerName As String = ""
        Public Property CustomerPhone As String = ""
        Public Property DeliveryAddress As String = ""
        Public Property Comments As String = ""
        Public Property ItemsJson As String = ""
        Public Property RawPayloadJson As String = ""
        Public Property InvID As Integer?
        Public Property PartnerID As Integer?
        Public Property TalabatPartnerName As String = ""
        Public Property CreatedAt As DateTime
        Public Property AcceptedAt As DateTime?
        Public Property PreparedAt As DateTime?
        Public Property RejectedAt As DateTime?
        Public Property RejectionReason As String = ""

        Public ReadOnly Property OrderStatusArabic As String
            Get
                Select Case OrderStatus
                    Case "Received"
                        Return "🔔 طلب جديد وارد (بانتظار القبول)"
                    Case "Accepted"
                        Return "👨‍🍳 قيد التحضير (تم القبول وإصدار الفاتورة)"
                    Case "Prepared"
                        Return "✅ جاهز للتسليم (Order Prepared)"
                    Case "Rejected"
                        Return "❌ مرفوض (Rejected)"
                    Case "Cancelled"
                        Return "🚫 ملغي من المنصة (Cancelled)"
                    Case Else
                        Return OrderStatus
                End Select
            End Get
        End Property

        Public ReadOnly Property CanAcceptOrReject As Boolean
            Get
                Return String.Equals(OrderStatus, "Received", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property

        Public ReadOnly Property CanMarkPrepared As Boolean
            Get
                Return String.Equals(OrderStatus, "Accepted", StringComparison.OrdinalIgnoreCase)
            End Get
        End Property
    End Class

End Namespace

