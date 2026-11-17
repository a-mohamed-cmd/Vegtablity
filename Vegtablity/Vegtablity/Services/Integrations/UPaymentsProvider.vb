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
    ''' مزود بوابة الدفع UPayments API v1 (معزول بالكامل)
    ''' يطبق كتيب UPayments الرسمي: /charge, /get-payment-status, /create-refund, /check-refund
    ''' </summary>
    Public Class UPaymentsProvider
        Implements IPaymentGatewayProvider

        Private Shared ReadOnly _httpClient As New HttpClient() With {.Timeout = TimeSpan.FromSeconds(20)}

        Public ReadOnly Property ProviderCode As String Implements IPaymentGatewayProvider.ProviderCode
            Get
                Return "UPAYMENTS"
            End Get
        End Property

        Private Function ResolveBaseUrl(config As IntegrationProviderConfig) As String
            If Not String.IsNullOrWhiteSpace(config.BaseUrl) Then
                Return config.BaseUrl.TrimEnd("/"c)
            End If
            If String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase) Then
                Return "https://uapi.upayments.com/api/v1"
            End If
            Return "https://sandboxapi.upayments.com/api/v1"
        End Function

        Public Async Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult) Implements IPaymentGatewayProvider.TestConnectionAsync
            Dim sw As Stopwatch = Stopwatch.StartNew()
            Dim res As New ConnectionTestResult()

            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                If String.IsNullOrWhiteSpace(token) Then
                    res.IsSuccess = False
                    res.VerifiedStatus = "Error"
                    res.MessageAr = "❌ يرجى إدخال مفتاح Bearer Token الخاص ببوابة UPayments."
                    res.NextStepGuidanceAr = "احصل على التوكن من حساب UPayments (أو استخدم التوكن التجريبي لبيئة Sandbox)."
                    Return res
                End If

                Dim url As String = ResolveBaseUrl(config) & "/get-payment-status/TEST_PING_CHECK"
                Using req As New HttpRequestMessage(HttpMethod.Get, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Headers.Accept.Add(New MediaTypeWithQualityHeaderValue("application/json"))

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        sw.Stop()
                        res.LatencyMs = sw.ElapsedMilliseconds
                        res.RawResponse = Await resp.Content.ReadAsStringAsync()

                        ' In UPayments, 401/403 means invalid token; 200 or 404/422 with valid JSON means token authenticated
                        If CInt(resp.StatusCode) <> 401 AndAlso CInt(resp.StatusCode) <> 403 AndAlso (resp.IsSuccessStatusCode OrElse res.RawResponse.Contains("status")) Then
                            res.IsSuccess = True
                            res.VerifiedStatus = If(String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified")
                            res.MessageAr = $"✅ نجح الاتصال ببوابة UPayments ({config.EnvironmentMode}) خلال {res.LatencyMs}ms."
                            res.NextStepGuidanceAr = "تم التحقق من التوكن بنجاح! اضغط على (حفظ الإعدادات وتفعيل البوابة) لحفظ البيانات وإنشاء الحساب."
                        Else
                            res.IsSuccess = False
                            res.VerifiedStatus = "Error"
                            res.MessageAr = $"❌ فشل التحقق من توكن UPayments ({CInt(resp.StatusCode)}): تأكد من صحة Bearer Token."
                            res.NextStepGuidanceAr = "راجع Bearer Token وعنوان الخادم (sandboxapi.upayments.com للبيئة التجريبية و uapi.upayments.com للبيئة الفعلية)."
                        End If
                    End Using
                End Using
            Catch ex As Exception
                sw.Stop()
                res.IsSuccess = False
                res.VerifiedStatus = "Error"
                res.MessageAr = "❌ خطأ أثناء الاتصال ببوابة UPayments: " & ex.Message
                res.NextStepGuidanceAr = "تحقق من اتصال الشبكة وصحة عنوان Base URL."
            End Try

            Return res
        End Function

        Public Async Function CreatePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of PaymentLinkCreationResult) Implements IPaymentGatewayProvider.CreatePaymentLinkAsync
            Dim result As New PaymentLinkCreationResult()
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/charge"
                Dim curr As String = If(String.IsNullOrWhiteSpace(request.CurrencyCode), config.DefaultCurrency, request.CurrencyCode)
                Dim amtStr As String = request.Amount.ToString("0.000", CultureInfo.InvariantCulture)
                Dim custName As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.CustomerName), "Customer", request.CustomerName))
                Dim phoneDigits As String = CleanPhoneDigits(request.CustomerPhone)
                Dim callbackUrl As String = EscapeJson(If(String.IsNullOrWhiteSpace(config.CallbackUrl), "https://vegtablity.local/api/integrations/webhooks/upayments", config.CallbackUrl))
                Dim orderId As String = $"ORD_{request.InvID}_{DateTime.UtcNow.Ticks}"

                Dim payload As String =
                    "{" &
                    $"""order"": {{""id"": ""{orderId}"", ""reference"": ""INV_{request.InvID}"", ""description"": ""Invoice #{request.InvID}"", ""currency"": ""{EscapeJson(curr)}"", ""amount"": {amtStr}}}," &
                    """language"": ""ar""," &
                    """paymentGateway"": {""src"": ""create-invoice""}," &
                    $"""reference"": {{""id"": ""INV_{request.InvID}""}}," &
                    $"""customer"": {{""uniqueId"": ""CUST_{If(request.PartnerID, 0)}"", ""name"": ""{custName}"", ""mobile"": ""+965{phoneDigits}""}}," &
                    $"""returnUrl"": ""{callbackUrl}""," &
                    $"""cancelUrl"": ""{callbackUrl}""," &
                    $"""notificationUrl"": ""{callbackUrl}""" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        result.RawJson = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            result.PaymentUrl = ExtractJsonString(result.RawJson, "link")
                            result.ExternalChargeID = ExtractJsonString(result.RawJson, "trackId")
                            If String.IsNullOrWhiteSpace(result.ExternalChargeID) Then
                                result.ExternalChargeID = orderId
                            End If
                            result.QrCodePayload = result.PaymentUrl
                            result.IsSuccess = Not String.IsNullOrWhiteSpace(result.PaymentUrl)
                        Else
                            result.IsSuccess = False
                            result.ErrorMessageAr = $"خطأ من UPayments ({CInt(resp.StatusCode)}): {ExtractJsonString(result.RawJson, "message")}"
                        End If
                    End Using
                End Using
            Catch ex As Exception
                result.IsSuccess = False
                result.ErrorMessageAr = "استثناء أثناء إنشاء رابط UPayments: " & ex.Message
            End Try
            Return result
        End Function

        Public Async Function CheckPaymentStatusAsync(config As IntegrationProviderConfig, externalId As String) As Task(Of String) Implements IPaymentGatewayProvider.CheckPaymentStatusAsync
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/get-payment-status/" & Uri.EscapeDataString(externalId)

                Using req As New HttpRequestMessage(HttpMethod.Get, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Dim body As String = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            Dim resVal As String = ExtractJsonString(body, "result").ToUpperInvariant()
                            Select Case resVal
                                Case "CAPTURED", "PAID", "SUCCESS"
                                    Return "Paid"
                                Case "CANCELED", "CANCELLED", "EXPIRED"
                                    Return "Expired"
                                Case "NOT CAPTURED", "FAILED"
                                    Return "Failed"
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
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/create-refund"
                Dim amtStr As String = request.RefundAmount.ToString("0.000", CultureInfo.InvariantCulture)

                Dim payload As String =
                    "{" &
                    $"""order_id"": ""{EscapeJson(request.ExternalChargeID)}""," &
                    $"""total_price"": {amtStr}," &
                    """customer_first_name"": ""Customer""," &
                    """customer_email"": ""refund@vegtablity.local""," &
                    """customer_mobile_number"": ""+96550000000""," &
                    $"""reference_id"": ""REF_{request.LinkID}""" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        res.RawJson = Await resp.Content.ReadAsStringAsync()
                        Dim statusFlag As String = ExtractJsonString(res.RawJson, "status")
                        If resp.IsSuccessStatusCode AndAlso Not String.Equals(statusFlag, "false", StringComparison.OrdinalIgnoreCase) Then
                            res.ExternalRefundID = ExtractJsonString(res.RawJson, "refund_order_id")
                            If String.IsNullOrWhiteSpace(res.ExternalRefundID) Then
                                res.ExternalRefundID = ExtractJsonString(res.RawJson, "refundOrderId")
                            End If
                            If String.IsNullOrWhiteSpace(res.ExternalRefundID) Then
                                res.ExternalRefundID = ExtractJsonString(res.RawJson, "refund_arn")
                            End If
                            If String.IsNullOrWhiteSpace(res.ExternalRefundID) Then
                                res.ExternalRefundID = ExtractJsonString(res.RawJson, "refundArn")
                            End If
                            res.RefundStatus = "REFUNDED"
                            res.IsSuccess = True
                            res.MessageAr = $"✅ تم تنفيذ إرجاع المبلغ عبر UPayments بنجاح (مرجع الاسترداد: {res.ExternalRefundID})."
                        Else
                            res.IsSuccess = False
                            res.MessageAr = TranslateGatewayRefundError("UPayments", CInt(resp.StatusCode), res.RawJson)
                        End If
                    End Using
                End Using
            Catch ex As Exception
                res.IsSuccess = False
                res.MessageAr = "❌ استثناء أثناء إرجاع المبلغ عبر UPayments: " & ex.Message
            End Try
            Return res
        End Function

    End Class

End Namespace

