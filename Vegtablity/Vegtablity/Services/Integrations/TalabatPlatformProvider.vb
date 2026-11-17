Imports System
Imports System.Collections.Generic
Imports System.Diagnostics
Imports System.Net
Imports System.Net.Http
Imports System.Net.Http.Headers
Imports System.Text
Imports System.Threading.Tasks
Imports Vegtablity.Models.Integrations

Namespace Services.Integrations

    ''' <summary>
    ''' مزود منصة طلبات (Talabat / Delivery Hero Integration Middleware API v2)
    ''' يطبق كتيب Talabat الرسمي:
    ''' - POST /v2/login (OAuth2 Client Credentials)
    ''' - POST /v2/orders/{orderToken}/accept and reject
    ''' - POST /v2/pos/orders/{orderToken}/prepared
    ''' - PUT  /v2/chains/{chainCode}/remoteVendors/{posVendorId}/availability
    ''' </summary>
    Public Class TalabatPlatformProvider
        Implements IDeliveryPlatformProvider

        Private Shared ReadOnly _httpClient As New HttpClient() With {.Timeout = TimeSpan.FromSeconds(20)}

        Public ReadOnly Property ProviderCode As String Implements IDeliveryPlatformProvider.ProviderCode
            Get
                Return "TALABAT"
            End Get
        End Property

        Private Function ResolveBaseUrl(config As IntegrationProviderConfig) As String
            If Not String.IsNullOrWhiteSpace(config.BaseUrl) Then
                Return config.BaseUrl.TrimEnd("/"c)
            End If
            If String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase) Then
                Return "https://integration-middleware.restaurant-partners.com"
            End If
            Return "https://integration-middleware.stg.restaurant-partners.com"
        End Function

        Private Async Function GetAccessTokenAsync(config As IntegrationProviderConfig) As Task(Of (Success As Boolean, Token As String, ErrorMsg As String, LatencyMs As Long))
            Dim sw As Stopwatch = Stopwatch.StartNew()
            Try
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
                Dim username As String = If(config.PublicKey, "").Trim()
                Dim secret As String = If(config.SecretKeyEncrypted, "").Trim()

                If String.IsNullOrWhiteSpace(username) OrElse String.IsNullOrWhiteSpace(secret) Then
                    Return (False, "", "يرجى إدخال اسم المستخدم (Client ID / Username) وكلمة المرور (Client Secret) الخاصة بـ Talabat.", 0)
                End If

                Dim url As String = ResolveBaseUrl(config) & "/v2/login"
                Dim formFields As New List(Of KeyValuePair(Of String, String)) From {
                    New KeyValuePair(Of String, String)("username", username),
                    New KeyValuePair(Of String, String)("password", secret),
                    New KeyValuePair(Of String, String)("grant_type", "client_credentials")
                }

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Content = New FormUrlEncodedContent(formFields)
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        sw.Stop()
                        Dim body As String = Await resp.Content.ReadAsStringAsync()
                        If resp.IsSuccessStatusCode Then
                            Dim token As String = ExtractJsonString(body, "access_token")
                            If Not String.IsNullOrWhiteSpace(token) Then
                                Return (True, token, "", sw.ElapsedMilliseconds)
                            End If
                        End If
                        Return (False, "", $"كود HTTP {CInt(resp.StatusCode)}: {ExtractJsonString(body, "message")}", sw.ElapsedMilliseconds)
                    End Using
                End Using
            Catch ex As Exception
                sw.Stop()
                Return (False, "", ex.Message, sw.ElapsedMilliseconds)
            End Try
        End Function

        Public Async Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult) Implements IDeliveryPlatformProvider.TestConnectionAsync
            Dim res As New ConnectionTestResult()
            Dim authResult = Await GetAccessTokenAsync(config)
            res.LatencyMs = authResult.LatencyMs

            If authResult.Success Then
                res.IsSuccess = True
                res.VerifiedStatus = If(String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified")
                res.MessageAr = $"✅ نجح الاتصال بمنصة Talabat ({config.EnvironmentMode}) وتم استلام رمز الجلسة (Bearer Token) خلال {res.LatencyMs}ms."
                res.NextStepGuidanceAr = "تم التحقق من الاتصال بنجاح! اضغط الآن على (حفظ الإعدادات وتفعيل البوابة) ليتم إضافة عميل المبيعات (Talabat) وشجرته المحاسبية وإظهار شاشة طلبات Talabat في قسم المبيعات وتطبيق الكاشير."
            Else
                res.IsSuccess = False
                res.VerifiedStatus = "Error"
                res.MessageAr = "❌ فشل الاتصال بمنصة Talabat: " & authResult.ErrorMsg
                res.NextStepGuidanceAr = "تأكد من صحة Client Username (في حقل المفتاح العام) و Client Secret (في حقل المفتاح السري) وكود السلسلة Chain Code (في حقل Merchant ID)."
            End If

            Return res
        End Function

        Public Async Function AcceptOrderAsync(config As IntegrationProviderConfig, orderToken As String, acceptanceTimeMinutes As Integer) As Task(Of Boolean) Implements IDeliveryPlatformProvider.AcceptOrderAsync
            Try
                Dim authResult = Await GetAccessTokenAsync(config)
                If Not authResult.Success Then Return False

                Dim url As String = $"{ResolveBaseUrl(config)}/v2/orders/{Uri.EscapeDataString(orderToken)}/accept"
                Dim payload As String = $"{{""acceptanceTime"": {Math.Max(5, acceptanceTimeMinutes)}, ""remoteOrderId"": ""POS_{orderToken}""}}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", authResult.Token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Return resp.IsSuccessStatusCode OrElse CInt(resp.StatusCode) = 202
                    End Using
                End Using
            Catch
                Return False
            End Try
        End Function

        Public Async Function RejectOrderAsync(config As IntegrationProviderConfig, orderToken As String, reason As String) As Task(Of Boolean) Implements IDeliveryPlatformProvider.RejectOrderAsync
            Try
                Dim authResult = Await GetAccessTokenAsync(config)
                If Not authResult.Success Then Return False

                Dim url As String = $"{ResolveBaseUrl(config)}/v2/orders/{Uri.EscapeDataString(orderToken)}/reject"
                Dim safeReason As String = EscapeJson(If(String.IsNullOrWhiteSpace(reason), "ITEM_UNAVAILABLE", reason))
                Dim payload As String = $"{{""reason"": ""{safeReason}"", ""message"": ""{safeReason}""}}"

                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", authResult.Token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Return resp.IsSuccessStatusCode OrElse CInt(resp.StatusCode) = 202
                    End Using
                End Using
            Catch
                Return False
            End Try
        End Function

        Public Async Function MarkOrderPreparedAsync(config As IntegrationProviderConfig, orderToken As String) As Task(Of Boolean) Implements IDeliveryPlatformProvider.MarkOrderPreparedAsync
            Try
                Dim authResult = Await GetAccessTokenAsync(config)
                If Not authResult.Success Then Return False

                Dim url As String = $"{ResolveBaseUrl(config)}/v2/pos/orders/{Uri.EscapeDataString(orderToken)}/prepared"
                Using req As New HttpRequestMessage(HttpMethod.Post, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", authResult.Token)
                    req.Content = New StringContent("{}", Encoding.UTF8, "application/json")
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Return resp.IsSuccessStatusCode OrElse CInt(resp.StatusCode) = 202
                    End Using
                End Using
            Catch
                Return False
            End Try
        End Function

        Public Async Function UpdateVendorAvailabilityAsync(config As IntegrationProviderConfig, remoteVendorId As String, isOpen As Boolean) As Task(Of Boolean) Implements IDeliveryPlatformProvider.UpdateVendorAvailabilityAsync
            Try
                Dim authResult = Await GetAccessTokenAsync(config)
                If Not authResult.Success Then Return False

                Dim chainCode As String = If(String.IsNullOrWhiteSpace(config.MerchantID), "DEFAULT_CHAIN", config.MerchantID.Trim())
                Dim vendorId As String = If(String.IsNullOrWhiteSpace(remoteVendorId), "BRANCH_1", remoteVendorId.Trim())
                Dim url As String = $"{ResolveBaseUrl(config)}/v2/chains/{Uri.EscapeDataString(chainCode)}/remoteVendors/{Uri.EscapeDataString(vendorId)}/availability"
                Dim state As String = If(isOpen, "OPEN", "CLOSED")
                Dim payload As String = $"{{""availabilityState"": ""{state}""}}"

                Using req As New HttpRequestMessage(HttpMethod.Put, url)
                    req.Headers.Authorization = New AuthenticationHeaderValue("Bearer", authResult.Token)
                    req.Content = New StringContent(payload, Encoding.UTF8, "application/json")
                    Using resp As HttpResponseMessage = Await _httpClient.SendAsync(req)
                        Return resp.IsSuccessStatusCode
                    End Using
                End Using
            Catch
                Return False
            End Try
        End Function

    End Class

End Namespace
