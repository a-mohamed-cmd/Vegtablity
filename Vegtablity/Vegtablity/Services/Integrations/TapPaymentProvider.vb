Imports System
Imports System.Diagnostics
Imports System.Globalization
Imports System.Net
Imports System.Net.Http
Imports System.Net.Http.Headers
Imports System.Text
Imports System.Threading.Tasks
Imports Vegtablity.Models.Integrations

Namespace Services.Integrations

    ''' <summary>
    ''' مزود بوابة الدفع Tap Payments API v2 (معزول بالكامل)
    ''' يطبق كتيب Tap الرسمي: Charges, Invoices, Refunds, Connection Verification
    ''' </summary>
    Public Class TapPaymentProvider
        Implements IPaymentGatewayProvider

        Private Shared ReadOnly _httpClient As New HttpClient() With {.Timeout = TimeSpan.FromSeconds(20)}

        Public ReadOnly Property ProviderCode As String Implements IPaymentGatewayProvider.ProviderCode
            Get
                Return "TAP"
            End Get
        End Property

        Private Function ResolveBaseUrl(config As IntegrationProviderConfig) As String
            If Not String.IsNullOrWhiteSpace(config.BaseUrl) Then
                Return config.BaseUrl.TrimEnd("/"c)
            End If
            Return "https://api.tap.company/v2"
        End Function

        Public Async Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult) Implements IPaymentGatewayProvider.TestConnectionAsync
            Dim sw As Stopwatch = Stopwatch.StartNew()
            Dim res As New ConnectionTestResult()

            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim secret As String = If(config.SecretKeyEncrypted, "").Trim()
                If String.IsNullOrWhiteSpace(secret) Then
                    res.IsSuccess = False
                    res.VerifiedStatus = "Error"
                    res.MessageAr = "❌ يرجى إدخال المفتاح السري (Secret Key) الخاص ببوابة Tap."
                    res.NextStepGuidanceAr = "احصل على المفتاح السري من لوحة تحكم Tap -> goCollect -> API Credentials."
                    Return res
                End If

                Dim isTestKey As Boolean = secret.StartsWith("sk_test_", StringComparison.OrdinalIgnoreCase)
                Dim isLiveKey As Boolean = secret.StartsWith("sk_live_", StringComparison.OrdinalIgnoreCase)

                Dim url As String = ResolveBaseUrl(config) & "/charges/list"
                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", secret)
                    req.Content = New StringContent("{""limit"": 1}", Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        sw.Stop()
                        res.LatencyMs = sw.ElapsedMilliseconds
                        res.RawResponse = Await resp.Content.ReadAsStringAsync()

                        If resp.IsSuccessStatusCode OrElse CInt(resp.StatusCode) = 200 OrElse CInt(resp.StatusCode) = 204 Then
                            res.IsSuccess = True
                            res.VerifiedStatus = If(isLiveKey OrElse String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified")
                            res.MessageAr = If(res.VerifiedStatus = "LiveVerified",
                                               $"✅ نجح الاتصال الفعلي ببوابة Tap (بيئة الإنتاج Live) خلال {res.LatencyMs}ms.",
                                               $"✅ نجح الاتصال التجريبي ببوابة Tap (بيئة الاختبار Sandbox) خلال {res.LatencyMs}ms.")
                            res.NextStepGuidanceAr = "تم التحقق من الاتصال بنجاح! يمكنك الآن الضغط على زر (حفظ الإعدادات وتفعيل البوابة) لإنشاء الحساب المحاسبي وتفعيل الروابط."
                        Else
                            res.IsSuccess = False
                            res.VerifiedStatus = "Error"
                            res.MessageAr = $"❌ فشل الاتصال ببوابة Tap (كود HTTP {CInt(resp.StatusCode)}): تأكد من صحة المفتاح السري."
                            res.NextStepGuidanceAr = "تأكد من نسخ Secret Key بالكامل دون مسافات إضافية، وتطابق وضع البيئة (Sandbox / Live)."
                        End If
                    End Using
                End Using
            Catch ex As Exception
                sw.Stop()
                res.IsSuccess = False
                res.VerifiedStatus = "Error"
                res.MessageAr = "❌ تعذر الاتصال بخوادم Tap Payments: " & ex.Message
                res.NextStepGuidanceAr = "تحقق من اتصال الإنترنت، أو من عنوان Base URL (https://api.tap.company/v2)."
            End Try

            Return res
        End Function

        Public Async Function CreatePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of PaymentLinkCreationResult) Implements IPaymentGatewayProvider.CreatePaymentLinkAsync
            Dim result As New PaymentLinkCreationResult()
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim secret As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim baseUrl As String = ResolveBaseUrl(config) & "/charges"
                Dim currency As String = If(String.IsNullOrWhiteSpace(request.CurrencyCode), config.DefaultCurrency, request.CurrencyCode)
                Dim amtStr As String = request.Amount.ToString("0.000", CultureInfo.InvariantCulture)
                Dim custName As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.CustomerName), "عميل نقدي", request.CustomerName))
                Dim phoneDigits As String = CleanPhoneDigits(request.CustomerPhone)
                Dim callbackUrl As String = EscapeJson(If(String.IsNullOrWhiteSpace(config.CallbackUrl), "https://vegtablity.local/api/integrations/webhooks/tap", config.CallbackUrl))
                Dim desc As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.Description), $"فاتورة مبيعات رقم #{request.InvID}", request.Description))

                Dim payload As String =
                    "{" &
                    $"""amount"": {amtStr}," &
                    $"""currency"": ""{EscapeJson(currency)}""," &
                    """customer_initiated"": true," &
                    """threeDSecure"": true," &
                    $"""description"": ""{desc}""," &
                    $"""reference"": {{""transaction"": ""INV_{request.InvID}"", ""order"": ""ORD_{request.InvID}""}}," &
                    """receipt"": {""email"": false, ""sms"": true}," &
                    $"""customer"": {{""first_name"": ""{custName}"", ""phone"": {{""country_code"": ""965"", ""number"": ""{phoneDigits}""}}}}," &
                    """source"": {""id"": ""src_all""}," &
                    $"""post"": {{""url"": ""{callbackUrl}""}}," &
                    $"""redirect"": {{""url"": ""{callbackUrl}""}}" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, baseUrl)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", secret)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        result.RawJson = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            result.ExternalChargeID = ExtractTapChargeId(result.RawJson)
                            result.PaymentUrl = ExtractTapTransactionUrl(result.RawJson, callbackUrl)
                            result.QrCodePayload = result.PaymentUrl
                            result.IsSuccess = Not String.IsNullOrWhiteSpace(result.PaymentUrl)
                            If Not result.IsSuccess Then
                                result.ErrorMessageAr = "تم إنشاء العملية ولكن لم يتم استلام رابط الدفع من Tap."
                            End If
                        Else
                            result.IsSuccess = False
                            result.ErrorMessageAr = $"خطأ من بوابة Tap ({CInt(resp.StatusCode)}): {ExtractJsonString(result.RawJson, "description")}"
                        End If
                    End Using
                End Using
            Catch ex As Exception
                result.IsSuccess = False
                result.ErrorMessageAr = "استثناء أثناء إنشاء رابط Tap: " & ex.Message
            End Try
            Return result
        End Function

        Public Async Function CheckPaymentStatusAsync(config As IntegrationProviderConfig, externalId As String) As Task(Of String) Implements IPaymentGatewayProvider.CheckPaymentStatusAsync
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim secret As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/charges/" & Uri.EscapeDataString(externalId)

                Using req As New HttpRequestMessage(HttpMethod.Get, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", secret)
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Dim body As String = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            Dim tapStatus As String = ExtractJsonString(body, "status").ToUpperInvariant()
                            Select Case tapStatus
                                Case "CAPTURED"
                                    Return "Paid"
                                Case "REFUNDED"
                                    Return "Refunded"
                                Case "PARTIALLY_REFUNDED"
                                    Return "PartiallyRefunded"
                                Case "CANCELLED", "ABANDONED", "TIMEDOUT", "VOID"
                                    Return "Expired"
                                Case "FAILED", "DECLINED", "RESTRICTED"
                                    Return "Failed"
                                Case Else
                                    Return "Pending"
                            End Select
                        End If
                    End Using
                End Using
            Catch
            End Try
            Return "Pending"
        End Function

        Public Async Function ProcessRefundAsync(config As IntegrationProviderConfig, request As PaymentRefundRequest) As Task(Of PaymentRefundResult) Implements IPaymentGatewayProvider.ProcessRefundAsync
            Dim res As New PaymentRefundResult()
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim secret As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/refunds"
                Dim amtStr As String = request.RefundAmount.ToString("0.000", CultureInfo.InvariantCulture)
                Dim curr As String = If(String.IsNullOrWhiteSpace(request.CurrencyCode), config.DefaultCurrency, request.CurrencyCode)
                Dim desc As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.Reason), $"استرداد رابط #{request.LinkID}", request.Reason))
                Dim tapReason As String = NormalizeTapRefundReason(request.Reason)

                Dim payload As String =
                    "{" &
                    $"""charge_id"": ""{EscapeJson(request.ExternalChargeID)}""," &
                    $"""amount"": {amtStr}," &
                    $"""currency"": ""{EscapeJson(curr)}""," &
                    $"""description"": ""{desc}""," &
                    $"""reason"": ""{tapReason}""," &
                    $"""reference"": {{""merchant"": ""REF_LNK_{request.LinkID}""}}" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", secret)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        res.RawJson = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            res.ExternalRefundID = ExtractJsonString(res.RawJson, "id")
                            res.RefundStatus = ExtractJsonString(res.RawJson, "status")
                            Dim stUpper As String = If(res.RefundStatus, "").ToUpperInvariant()
                            If stUpper = "DECLINED" OrElse stUpper = "FAILED" OrElse stUpper = "CANCELLED" Then
                                res.IsSuccess = False
                                res.MessageAr = TranslateGatewayRefundError("Tap Payments", CInt(resp.StatusCode), res.RawJson)
                            Else
                                res.IsSuccess = True
                                res.MessageAr = $"✅ تم تنفيذ إرجاع المبلغ عبر Tap بنجاح (رقم المرجع: {res.ExternalRefundID})."
                            End If
                        Else
                            res.IsSuccess = False
                            res.MessageAr = TranslateGatewayRefundError("Tap Payments", CInt(resp.StatusCode), res.RawJson)
                        End If
                    End Using
                End Using
            Catch ex As Exception
                res.IsSuccess = False
                res.MessageAr = "❌ خطأ أثناء الاتصال ببوابة Tap لإرجاع المبلغ: " & ex.Message
            End Try
            Return res
        End Function

    End Class

End Namespace

