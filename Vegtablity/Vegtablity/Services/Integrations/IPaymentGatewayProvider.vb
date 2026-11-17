Imports System
Imports System.Text.RegularExpressions
Imports System.Threading.Tasks
Imports Vegtablity.Models.Integrations

Namespace Services.Integrations

    ''' <summary>
    ''' الواجهة الموحدة لبوابات الدفع الإلكتروني (Tap, MyFatoorah, UPayments)
    ''' معزولة بالكامل بنمط Strategy Pattern
    ''' </summary>
    Public Interface IPaymentGatewayProvider
        ReadOnly Property ProviderCode As String
        Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult)
        Function CreatePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of PaymentLinkCreationResult)
        Function CheckPaymentStatusAsync(config As IntegrationProviderConfig, externalId As String) As Task(Of String)
        Function ProcessRefundAsync(config As IntegrationProviderConfig, request As PaymentRefundRequest) As Task(Of PaymentRefundResult)
    End Interface

    ''' <summary>
    ''' الواجهة الموحدة لمنصات الطلبات والتوصيل (Talabat, Jahez)
    ''' </summary>
    Public Interface IDeliveryPlatformProvider
        ReadOnly Property ProviderCode As String
        Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult)
        Function AcceptOrderAsync(config As IntegrationProviderConfig, orderToken As String, acceptanceTimeMinutes As Integer) As Task(Of Boolean)
        Function RejectOrderAsync(config As IntegrationProviderConfig, orderToken As String, reason As String) As Task(Of Boolean)
        Function MarkOrderPreparedAsync(config As IntegrationProviderConfig, orderToken As String) As Task(Of Boolean)
        Function UpdateVendorAvailabilityAsync(config As IntegrationProviderConfig, remoteVendorId As String, isOpen As Boolean) As Task(Of Boolean)
    End Interface

    ''' <summary>
    ''' أداة مساعدة خفيفة ومعزولة للتعامل مع نصوص JSON بدون الاعتماد على مكتبات خارجية
    ''' </summary>
    Friend Module IntegrationJsonHelper
        Public Function EscapeJson(val As String) As String
            If String.IsNullOrEmpty(val) Then Return ""
            Return val.Replace("\", "\\").Replace("""", "\""").Replace(vbCr, "\r").Replace(vbLf, "\n")
        End Function

        Public Function ExtractJsonString(json As String, key As String) As String
            If String.IsNullOrEmpty(json) OrElse String.IsNullOrEmpty(key) Then Return ""
            Dim pattern As String = """" & Regex.Escape(key) & """\s*:\s*""([^""\\]*(?:\\.[^""\\]*)*)"""
            Dim m As Match = Regex.Match(json, pattern, RegexOptions.IgnoreCase)
            If m.Success Then
                Return m.Groups(1).Value.Replace("\/", "/").Replace("\""", """")
            End If
            ' Try numeric or boolean token
            Dim numPattern As String = """" & Regex.Escape(key) & """\s*:\s*([0-9a-zA-Z\.\-_]+)"
            Dim m2 As Match = Regex.Match(json, numPattern, RegexOptions.IgnoreCase)
            If m2.Success Then
                Return m2.Groups(1).Value
            End If
            Return ""
        End Function

        Public Function CleanPhoneDigits(phone As String) As String
            If String.IsNullOrWhiteSpace(phone) Then Return "50000000"
            Dim digits As String = Regex.Replace(phone, "[^\d]", "")
            If digits.StartsWith("00965") Then digits = digits.Substring(5)
            If digits.StartsWith("965") AndAlso digits.Length > 8 Then digits = digits.Substring(3)
            If String.IsNullOrEmpty(digits) Then Return "50000000"
            Return digits
        End Function

        Public Function ExtractTapChargeId(json As String) As String
            If String.IsNullOrEmpty(json) Then Return ""
            Dim m As Match = Regex.Match(json, """id""\s*:\s*""(chg_[^""\\]+)""", RegexOptions.IgnoreCase)
            If m.Success Then Return m.Groups(1).Value
            Return ExtractJsonString(json, "id")
        End Function

        Public Function ExtractTapTransactionUrl(json As String, Optional callbackUrl As String = "") As String
            If String.IsNullOrEmpty(json) Then Return ""
            ' 1. Look specifically inside the "transaction": { ... "url": "..." } object
            Dim txMatch As Match = Regex.Match(json, """transaction""\s*:\s*\{[^{}]*?""url""\s*:\s*""([^""\\]*(?:\\.[^""\\]*)*)""", RegexOptions.IgnoreCase Or RegexOptions.Singleline)
            If txMatch.Success Then
                Return txMatch.Groups(1).Value.Replace("\/", "/").Replace("\""", """")
            End If
            ' 2. Fallback: find any "url" that is not the callback/redirect URL
            Dim allUrls As MatchCollection = Regex.Matches(json, """url""\s*:\s*""([^""\\]*(?:\\.[^""\\]*)*)""", RegexOptions.IgnoreCase)
            For Each u As Match In allUrls
                Dim candidate As String = u.Groups(1).Value.Replace("\/", "/").Replace("\""", """")
                If Not String.IsNullOrWhiteSpace(candidate) AndAlso
                   (String.IsNullOrWhiteSpace(callbackUrl) OrElse Not String.Equals(candidate, callbackUrl, StringComparison.OrdinalIgnoreCase)) AndAlso
                   (candidate.IndexOf("tap.company", StringComparison.OrdinalIgnoreCase) >= 0 OrElse candidate.IndexOf("gosell", StringComparison.OrdinalIgnoreCase) >= 0) Then
                    Return candidate
                End If
            Next
            Return ExtractJsonString(json, "url")
        End Function

        Public Function NormalizeTapRefundReason(reason As String) As String
            Dim txt As String = If(reason, "").Trim().ToLowerInvariant()
            If txt.Contains("duplicate") OrElse txt.Contains("مكرر") OrElse txt.Contains("تكرار") Then Return "duplicate"
            If txt.Contains("fraud") OrElse txt.Contains("احتيال") Then Return "fraudulent"
            Return "requested_by_customer"
        End Function

        Public Function TranslateGatewayRefundError(providerName As String, statusCode As Integer, rawJson As String, Optional fallbackDetail As String = "") As String
            Dim gw As String = If(String.IsNullOrWhiteSpace(providerName), "بوابة الدفع", providerName)
            Dim detail As String = If(fallbackDetail, "").Trim()
            If String.IsNullOrWhiteSpace(detail) AndAlso Not String.IsNullOrWhiteSpace(rawJson) Then
                For Each k In New String() {"description", "Message", "message", "Error", "error_description", "error"}
                    Dim v = ExtractJsonString(rawJson, k)
                    If Not String.IsNullOrWhiteSpace(v) AndAlso Not String.Equals(v, "Validation Errors", StringComparison.OrdinalIgnoreCase) Then
                        detail = v
                        Exit For
                    End If
                Next
            End If

            Dim hay As String = $"{detail} {rawJson}".ToLowerInvariant()
            If statusCode = 401 OrElse hay.Contains("unauthorized") OrElse hay.Contains("invalid token") OrElse hay.Contains("invalid key") OrElse hay.Contains("authentication") Then
                Return $"❌ فشل التحقق من مفتاح الربط السري (Secret Key) لبوابة {gw}؛ يرجى مراجعة المفتاح وبيئة التشغيل (Sandbox/Live) في إعدادات الربط."
            End If
            If statusCode = 403 OrElse hay.Contains("permission") OrElse hay.Contains("not enabled") OrElse hay.Contains("not allowed") OrElse hay.Contains("forbidden") OrElse hay.Contains("privilege") Then
                Return $"⚠️ خدمة الاسترداد غير مفعّلة في حساب التاجر لدى بوابة {gw} أو لا يملك الحساب صلاحية تنفيذ الاسترداد."
            End If
            If hay.Contains("already refunded") OrElse hay.Contains("fully refunded") OrElse hay.Contains("already reversed") Then
                Return $"ℹ️ تم استرداد كامل مبلغ هذه الفاتورة مسبقاً لدى بوابة {gw}."
            End If
            If hay.Contains("exceed") OrElse hay.Contains("greater than") OrElse hay.Contains("remaining amount") OrElse hay.Contains("more than paid") OrElse hay.Contains("refundable amount") Then
                Return $"⚠️ مبلغ الاسترداد المطلوب يتجاوز الرصيد المتاح للاسترداد في هذه العملية لدى بوابة {gw}."
            End If
            If hay.Contains("insufficient") OrElse hay.Contains("enough balance") OrElse hay.Contains("wallet balance") Then
                Return $"⚠️ الرصيد المتاح في حساب التاجر لدى بوابة {gw} غير كافٍ لتنفيذ الاسترداد."
            End If
            If hay.Contains("not captured") OrElse hay.Contains("not paid") OrElse hay.Contains("no paid transaction") OrElse hay.Contains("cannot be refunded") OrElse hay.Contains("invalid status") OrElse hay.Contains("unpaid") Then
                Return $"⚠️ لا يمكن استرداد هذه الفاتورة لدى بوابة {gw} لأن عملية الدفع غير محصلة أو غير مدفوعة بعد؛ يرجى فحص حالة الرابط أولاً."
            End If
            If statusCode = 404 OrElse hay.Contains("not found") OrElse hay.Contains("invalid charge") OrElse hay.Contains("invalid invoice") OrElse hay.Contains("invalid order") Then
                Return $"⚠️ لم يتم العثور على معاملة الدفع الأصلية لدى بوابة {gw} (راجع رقم المرجع أو بيئة التشغيل)."
            End If
            If hay.Contains("currency") Then
                Return $"⚠️ عملة الاسترداد غير مطابقة لعملة عملية الدفع الأصلية لدى بوابة {gw}."
            End If
            If statusCode = 429 OrElse hay.Contains("too many requests") OrElse hay.Contains("rate limit") Then
                Return $"⏳ تم تجاوز الحد المؤقت لطلبات بوابة {gw}؛ يرجى الانتظار دقيقة ثم المحاولة مجدداً."
            End If
            If hay.Contains("knet") OrElse hay.Contains("settled") OrElse hay.Contains("expired") OrElse hay.Contains("time limit") Then
                Return $"⚠️ تعذر الاسترداد الآلي لدى بوابة {gw} بسبب انتهاء مهلة الاسترداد أو أن وسيلة الدفع لا تدعم الاسترداد المباشر."
            End If
            If hay.Contains("reason") OrElse hay.Contains("validation") OrElse statusCode = 422 Then
                Return $"⚠️ رفضت بوابة {gw} بيانات طلب الاسترداد (راجع المبلغ وسبب الاسترداد)" & If(String.IsNullOrWhiteSpace(detail), ".", $": {detail}")
            End If
            If statusCode >= 500 Then
                Return $"🛠️ خادم بوابة {gw} غير متاح مؤقتاً (رمز {statusCode})؛ يرجى المحاولة بعد قليل."
            End If
            If Not String.IsNullOrWhiteSpace(detail) Then
                Return $"❌ تعذر تنفيذ الاسترداد عبر بوابة {gw}: {detail}"
            End If
            Return $"❌ تعذر إرجاع المبلغ عبر بوابة {gw} ({statusCode})؛ يرجى مراجعة إعدادات البوابة وحالة الرابط."
        End Function
    End Module

End Namespace

