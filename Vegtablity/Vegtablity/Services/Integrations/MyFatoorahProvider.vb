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
    ''' مزود بوابة الدفع MyFatoorah API v2 (معزول بالكامل)
    ''' يطبق كتيب MyFatoorah الرسمي: InitiatePayment, SendPayment, GetPaymentStatus, MakeRefund
    ''' </summary>
    Public Class MyFatoorahProvider
        Implements IPaymentGatewayProvider

        Private Shared ReadOnly _httpClient As New HttpClient() With {.Timeout = TimeSpan.FromSeconds(20)}

        Public ReadOnly Property ProviderCode As String Implements IPaymentGatewayProvider.ProviderCode
            Get
                Return "MYFATOORAH"
            End Get
        End Property

        Private Function ResolveBaseUrl(config As IntegrationProviderConfig) As String
            If Not String.IsNullOrWhiteSpace(config.BaseUrl) Then
                Return config.BaseUrl.TrimEnd("/"c)
            End If
            If String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase) Then
                Return "https://api.myfatoorah.com"
            End If
            Return "https://apitest.myfatoorah.com"
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
                    res.MessageAr = "❌ يرجى إدخال رمز التوثيق (API Token Key) الخاص ببوابة MyFatoorah."
                    res.NextStepGuidanceAr = "انسخ API Token من حساب MyFatoorah -> Integration Settings -> API Key."
                    Return res
                End If

                Dim url As String = ResolveBaseUrl(config) & "/v2/InitiatePayment"
                Dim curr As String = If(String.IsNullOrWhiteSpace(config.DefaultCurrency), "KWD", config.DefaultCurrency)
                Dim payload As String = $"{{""InvoiceAmount"": 1.000, ""CurrencyIso"": ""{EscapeJson(curr)}""}}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        sw.Stop()
                        res.LatencyMs = sw.ElapsedMilliseconds
                        res.RawResponse = Await resp.Content.ReadAsStringAsync()

                        Dim isSuccessFlag As String = ExtractJsonString(res.RawResponse, "IsSuccess")
                        If resp.IsSuccessStatusCode AndAlso String.Equals(isSuccessFlag, "true", StringComparison.OrdinalIgnoreCase) Then
                            res.IsSuccess = True
                            res.VerifiedStatus = If(String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified")
                            res.MessageAr = $"✅ نجح الاتصال ببوابة MyFatoorah ({config.EnvironmentMode}) خلال {res.LatencyMs}ms."
                            res.NextStepGuidanceAr = "تم التحقق من صلاحية التوكن بنجاح! اضغط على (حفظ الإعدادات وتفعيل البوابة) لإتمام التفعيل."
                        Else
                            res.IsSuccess = False
                            res.VerifiedStatus = "Error"
                            res.MessageAr = $"❌ فشل التحقق من MyFatoorah ({CInt(resp.StatusCode)}): {ExtractJsonString(res.RawResponse, "Message")}"
                            res.NextStepGuidanceAr = "تأكد من توافق عنوان BaseUrl (apitest.myfatoorah.com للبيئة التجريبية و api.myfatoorah.com للبيئة الفعلية)."
                        End If
                    End Using
                End Using
            Catch ex As Exception
                sw.Stop()
                res.IsSuccess = False
                res.VerifiedStatus = "Error"
                res.MessageAr = "❌ خطأ أثناء الاتصال ببوابة MyFatoorah: " & ex.Message
                res.NextStepGuidanceAr = "تحقق من اتصال الشبكة وصحة عنوان الخادم."
            End Try

            Return res
        End Function

        Public Async Function CreatePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of PaymentLinkCreationResult) Implements IPaymentGatewayProvider.CreatePaymentLinkAsync
            Dim result As New PaymentLinkCreationResult()
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/v2/SendPayment"
                Dim curr As String = If(String.IsNullOrWhiteSpace(request.CurrencyCode), config.DefaultCurrency, request.CurrencyCode)
                Dim amtStr As String = request.Amount.ToString("0.000", CultureInfo.InvariantCulture)
                Dim custName As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.CustomerName), "عميل نقدي", request.CustomerName))
                Dim phoneDigits As String = CleanPhoneDigits(request.CustomerPhone)
                Dim callbackUrl As String = EscapeJson(If(String.IsNullOrWhiteSpace(config.CallbackUrl), "https://vegtablity.local/api/integrations/webhooks/myfatoorah", config.CallbackUrl))

                ' NotificationOption: LNK returns URL immediately so ERP/POS can send via WhatsApp or print QR
                Dim payload As String =
                    "{" &
                    $"""NotificationOption"": ""LNK""," &
                    $"""CustomerName"": ""{custName}""," &
                    $"""DisplayCurrencyIso"": ""{EscapeJson(curr)}""," &
                    """MobileCountryCode"": ""+965""," &
                    $"""CustomerMobile"": ""{phoneDigits}""," &
                    $"""InvoiceValue"": {amtStr}," &
                    """Language"": ""ar""," &
                    $"""CallBackUrl"": ""{callbackUrl}""," &
                    $"""ErrorUrl"": ""{callbackUrl}""," &
                    $"""CustomerReference"": ""INV_{request.InvID}""" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        result.RawJson = Await resp.Content.ReadAsStringAsync()
                        Dim isSuccessFlag As String = ExtractJsonString(result.RawJson, "IsSuccess")
                        If resp.IsSuccessStatusCode AndAlso String.Equals(isSuccessFlag, "true", StringComparison.OrdinalIgnoreCase) Then
                            result.ExternalInvoiceID = ExtractJsonString(result.RawJson, "InvoiceId")
                            result.ExternalChargeID = result.ExternalInvoiceID
                            result.PaymentUrl = ExtractJsonString(result.RawJson, "InvoiceURL")
                            result.QrCodePayload = result.PaymentUrl
                            result.IsSuccess = Not String.IsNullOrWhiteSpace(result.PaymentUrl)
                        Else
                            result.IsSuccess = False
                            result.ErrorMessageAr = $"خطأ من MyFatoorah: {ExtractJsonString(result.RawJson, "Message")}"
                        End If
                    End Using
                End Using
            Catch ex As Exception
                result.IsSuccess = False
                result.ErrorMessageAr = "استثناء أثناء إنشاء رابط MyFatoorah: " & ex.Message
            End Try
            Return result
        End Function

        Public Async Function CheckPaymentStatusAsync(config As IntegrationProviderConfig, externalId As String) As Task(Of String) Implements IPaymentGatewayProvider.CheckPaymentStatusAsync
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/v2/GetPaymentStatus"
                Dim payload As String = $"{{""Key"": ""{EscapeJson(externalId)}"", ""KeyType"": ""InvoiceId""}}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Dim body As String = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            Dim invStatus As String = ExtractJsonString(body, "InvoiceStatus").ToUpperInvariant()
                            Select Case invStatus
                                Case "PAID"
                                    Return "Paid"
                                Case "CANCELED", "EXPIRED"
                                    Return "Expired"
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
                Dim token As String = If(config.SecretKeyEncrypted, "").Trim()
                Dim url As String = ResolveBaseUrl(config) & "/v2/MakeRefund"
                Dim amtStr As String = request.RefundAmount.ToString("0.000", CultureInfo.InvariantCulture)
                Dim comment As String = EscapeJson(If(String.IsNullOrWhiteSpace(request.Reason), "إرجاع مبلغ للعميل", request.Reason))
                Dim refCharge As String = If(request.RefundChargeOnCustomer, "true", "false")
                Dim srvCharge As String = If(request.ServiceChargeOnCustomer, "true", "false")

                Dim payload As String =
                    "{" &
                    """KeyType"": ""InvoiceId""," &
                    $"""Key"": ""{EscapeJson(request.ExternalChargeID)}""," &
                    $"""RefundChargeOnCustomer"": {refCharge}," &
                    $"""ServiceChargeOnCustomer"": {srvCharge}," &
                    $"""Amount"": {amtStr}," &
                    $"""Comment"": ""{comment}""" &
                    "}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")

                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        res.RawJson = Await resp.Content.ReadAsStringAsync()
                        Dim isSuccessFlag As String = ExtractJsonString(res.RawJson, "IsSuccess")
                        If resp.IsSuccessStatusCode AndAlso String.Equals(isSuccessFlag, "true", StringComparison.OrdinalIgnoreCase) Then
                            res.ExternalRefundID = ExtractJsonString(res.RawJson, "RefundId")
                            res.RefundStatus = "REFUNDED"
                            res.IsSuccess = True
                            res.MessageAr = $"✅ تم تنفيذ إرجاع المبلغ عبر MyFatoorah بنجاح (رقم الاسترداد: {res.ExternalRefundID})."
                        Else
                            res.IsSuccess = False
                            res.MessageAr = TranslateGatewayRefundError("MyFatoorah", CInt(resp.StatusCode), res.RawJson)
                        End If
                    End Using
                End Using
            Catch ex As Exception
                res.IsSuccess = False
                res.MessageAr = "❌ استثناء أثناء إرجاع المبلغ عبر MyFatoorah: " & ex.Message
            End Try
            Return res
        End Function

    End Class

End Namespace

