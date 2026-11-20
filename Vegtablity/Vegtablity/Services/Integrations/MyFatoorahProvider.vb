Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Diagnostics
Imports System.Globalization
Imports System.Net
Imports System.Net.Http
Imports System.Net.Http.Headers
Imports System.Text
Imports System.Threading.Tasks
Imports System.Web.Script.Serialization
Imports Vegtablity.Models.Integrations

Namespace Services.Integrations

    ''' <summary>
    ''' مزود بوابة الدفع MyFatoorah API v2 (كلاس معزول بالكامل عن Tap وبقية المزودين)
    ''' يدعم نقاط النهاية المعتمدة: InitiatePayment, SendPayment, ExecutePayment, GetPaymentStatus, MakeRefund, GetRefundStatus
    ''' بالتطابق المعماري مع TapPaymentProvider.
    ''' </summary>
    Public Class MyFatoorahProvider
        Implements IPaymentGatewayProvider

        Private Shared ReadOnly JsonSerializer As New JavaScriptSerializer() With {.MaxJsonLength = Integer.MaxValue}

        Public ReadOnly Property ProviderCode As String Implements IPaymentGatewayProvider.ProviderCode
            Get
                Return "MYFATOORAH"
            End Get
        End Property

        Private Function ResolveBaseUrl(config As IntegrationProviderConfig) As String
            If config IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(config.BaseUrl) Then
                Return config.BaseUrl.Trim().TrimEnd("/"c)
            End If
            If config IsNot Nothing AndAlso String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase) Then
                Return "https://api.myfatoorah.com"
            End If
            Return "https://apitest.myfatoorah.com"
        End Function

        Private Function CreateClient(secretKey As String, Optional timeoutSeconds As Integer = 20) As HttpClient
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
            Dim client As New HttpClient() With {.Timeout = TimeSpan.FromSeconds(timeoutSeconds)}
            client.DefaultRequestHeaders.Authorization = New AuthenticationHeaderValue("Bearer", secretKey.Trim())
            client.DefaultRequestHeaders.Accept.Add(New MediaTypeWithQualityHeaderValue("application/json"))
            Return client
        End Function

        Private Function DeserializeDict(rawJson As String) As Dictionary(Of String, Object)
            If String.IsNullOrWhiteSpace(rawJson) Then Return New Dictionary(Of String, Object)()
            Try
                Dim obj = JsonSerializer.DeserializeObject(rawJson)
                Dim dict = TryCast(obj, Dictionary(Of String, Object))
                If dict IsNot Nothing Then Return dict
            Catch
            End Try
            Return New Dictionary(Of String, Object)()
        End Function

        Private Function GetStr(dict As Dictionary(Of String, Object), key As String) As String
            If dict Is Nothing Then Return ""
            For Each kvp In dict
                If String.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase) Then
                    Return If(kvp.Value Is Nothing, "", Convert.ToString(kvp.Value, CultureInfo.InvariantCulture))
                End If
            Next
            Return ""
        End Function

        Private Function GetBool(dict As Dictionary(Of String, Object), key As String, defaultVal As Boolean) As Boolean
            If dict Is Nothing Then Return defaultVal
            For Each kvp In dict
                If String.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase) AndAlso kvp.Value IsNot Nothing Then
                    Dim parsed As Boolean
                    If Boolean.TryParse(kvp.Value.ToString(), parsed) Then Return parsed
                End If
            Next
            Return defaultVal
        End Function

        Private Function GetDict(dict As Dictionary(Of String, Object), key As String) As Dictionary(Of String, Object)
            If dict Is Nothing Then Return Nothing
            For Each kvp In dict
                If String.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase) Then
                    Return TryCast(kvp.Value, Dictionary(Of String, Object))
                End If
            Next
            Return Nothing
        End Function

        Private Function GetArray(dict As Dictionary(Of String, Object), key As String) As Object()
            If dict Is Nothing Then Return Nothing
            For Each kvp In dict
                If String.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase) Then
                    Dim arr = TryCast(kvp.Value, Object())
                    If arr IsNot Nothing Then Return arr
                    Dim lst = TryCast(kvp.Value, ArrayList)
                    If lst IsNot Nothing Then Return lst.ToArray()
                End If
            Next
            Return Nothing
        End Function

        Private Function ExtractMyFatoorahErrorDetails(rawJson As String) As String
            Dim root = DeserializeDict(rawJson)
            If root.Count = 0 Then Return ExtractJsonString(rawJson, "Message")

            Dim parts As New List(Of String)()
            Dim msg = GetStr(root, "Message").Trim()
            If Not String.IsNullOrWhiteSpace(msg) Then parts.Add(msg)

            Dim valErrs = GetArray(root, "ValidationErrors")
            If valErrs IsNot Nothing Then
                For Each item In valErrs
                    Dim errDict = TryCast(item, Dictionary(Of String, Object))
                    If errDict IsNot Nothing Then
                        Dim fieldName = GetStr(errDict, "Name").Trim()
                        Dim detail = GetStr(errDict, "Error").Trim()
                        If Not String.IsNullOrWhiteSpace(detail) Then
                            parts.Add(If(String.IsNullOrWhiteSpace(fieldName), detail, $"{fieldName}: {detail}"))
                        End If
                    End If
                Next
            End If

            Dim fieldErrs = GetArray(root, "FieldsErrors")
            If fieldErrs IsNot Nothing Then
                For Each item In fieldErrs
                    Dim errDict = TryCast(item, Dictionary(Of String, Object))
                    If errDict IsNot Nothing Then
                        Dim fieldName = GetStr(errDict, "Name").Trim()
                        Dim detail = GetStr(errDict, "Error").Trim()
                        If Not String.IsNullOrWhiteSpace(detail) Then
                            parts.Add(If(String.IsNullOrWhiteSpace(fieldName), detail, $"{fieldName}: {detail}"))
                        End If
                    End If
                Next
            End If

            Return String.Join(" | ", parts)
        End Function

        ''' <summary>
        ''' اختبار الاتصال وجلب وسائل الدفع المتاحة عبر POST /v2/InitiatePayment
        ''' </summary>
        Public Async Function TestConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult) Implements IPaymentGatewayProvider.TestConnectionAsync
            Dim res As New ConnectionTestResult()
            Dim sw = Stopwatch.StartNew()

            Try
                If config Is Nothing OrElse String.IsNullOrWhiteSpace(config.SecretKeyEncrypted) Then
                    res.IsSuccess = False
                    res.VerifiedStatus = "Error"
                    res.MessageAr = "❌ يرجى إدخال رمز التوثيق (API Token Key) الخاص ببوابة MyFatoorah."
                    res.NextStepGuidanceAr = "انسخ API Token من حساب MyFatoorah -> Integration Settings -> API Key."
                    Return res
                End If

                Dim currencyCode As String = If(String.IsNullOrWhiteSpace(config.DefaultCurrency), "KWD", config.DefaultCurrency.Trim())
                Dim url As String = ResolveBaseUrl(config) & "/v2/InitiatePayment"
                Dim payloadObj As New Dictionary(Of String, Object) From {
                    {"InvoiceAmount", 1.000D},
                    {"CurrencyIso", currencyCode}
                }
                Dim bodyJson As String = JsonSerializer.Serialize(payloadObj)

                Using client = CreateClient(config.SecretKeyEncrypted, 15)
                    Dim content As New StringContent(bodyJson, Encoding.UTF8, "application/json")
                    Dim resp = Await client.PostAsync(url, content)
                    res.RawResponse = Await resp.Content.ReadAsStringAsync()
                    sw.Stop()
                    res.LatencyMs = sw.ElapsedMilliseconds

                    Dim root = DeserializeDict(res.RawResponse)
                    Dim apiOk As Boolean = resp.IsSuccessStatusCode AndAlso GetBool(root, "IsSuccess", resp.IsSuccessStatusCode)

                    If apiOk Then
                        Dim dataDict = GetDict(root, "Data")
                        Dim methodsArr = GetArray(dataDict, "PaymentMethods")
                        Dim methodCount As Integer = If(methodsArr IsNot Nothing, methodsArr.Length, 0)

                        res.IsSuccess = True
                        res.VerifiedStatus = If(String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified")
                        res.MessageAr = $"✅ نجح الاتصال ببوابة MyFatoorah ({config.EnvironmentMode}) خلال {res.LatencyMs}ms — وسائل الدفع المفعلة: {methodCount}."
                        res.NextStepGuidanceAr = "الاتصال جاهز. سيتم الآن تفعيل إنشاء الحساب الفرعي في شجرة الحسابات وإصدار روابط الدفع والاسترداد."
                    Else
                        res.IsSuccess = False
                        res.VerifiedStatus = "Error"
                        Dim errDetail = ExtractMyFatoorahErrorDetails(res.RawResponse)
                        If CInt(resp.StatusCode) = 401 OrElse CInt(resp.StatusCode) = 403 Then
                            res.MessageAr = $"❌ رمز التوثيق (API Token) مرفوض من MyFatoorah ({CInt(resp.StatusCode)}): {errDetail}"
                        Else
                            res.MessageAr = $"❌ فشل التحقق من MyFatoorah ({CInt(resp.StatusCode)}): {errDetail}"
                        End If
                        res.NextStepGuidanceAr = "تأكد من صحة الـ API Token وتوافق عنوان BaseUrl (apitest.myfatoorah.com للبيئة التجريبية و api.myfatoorah.com للكويت الفعلي)."
                    End If
                End Using
            Catch ex As Exception
                sw.Stop()
                res.IsSuccess = False
                res.VerifiedStatus = "Error"
                res.LatencyMs = sw.ElapsedMilliseconds
                res.MessageAr = "❌ خطأ أثناء الاتصال ببوابة MyFatoorah: " & ex.Message
                res.NextStepGuidanceAr = "تحقق من اتصال الإنترنت وصحة رابط BaseUrl الخاص بالبوابة."
            End Try

            Return res
        End Function

        ''' <summary>
        ''' إصدار رابط دفع إلكتروني عبر POST /v2/SendPayment (أو /v2/ExecutePayment عند تمرير PaymentMethodId)
        ''' </summary>
        Public Async Function CreatePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of PaymentLinkCreationResult) Implements IPaymentGatewayProvider.CreatePaymentLinkAsync
            Return Await SendOrExecutePaymentAsync(config, request, Nothing)
        End Function

        ''' <summary>
        ''' إصدار رابط دفع إلكتروني مباشر لوسيلة محددة (مثل KNET) عبر POST /v2/ExecutePayment أو SendPayment
        ''' </summary>
        Public Async Function SendOrExecutePaymentAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest, Optional paymentMethodId As Integer? = Nothing) As Task(Of PaymentLinkCreationResult)
            Dim result As New PaymentLinkCreationResult()
            Try
                Dim baseUrl As String = ResolveBaseUrl(config)
                Dim endpoint As String = If(paymentMethodId.HasValue AndAlso paymentMethodId.Value > 0, "/v2/ExecutePayment", "/v2/SendPayment")
                Dim url As String = baseUrl & endpoint

                Dim custName As String = If(String.IsNullOrWhiteSpace(request.CustomerName), "عميل نقدي", request.CustomerName.Trim())
                Dim phoneDigits As String = CleanPhoneDigits(request.CustomerPhone)
                Dim currencyCode As String = If(String.IsNullOrWhiteSpace(request.CurrencyCode), If(String.IsNullOrWhiteSpace(config.DefaultCurrency), "KWD", config.DefaultCurrency), request.CurrencyCode)
                Dim callbackUrl As String = If(String.IsNullOrWhiteSpace(config.CallbackUrl), "https://vegtablity.local/api/integrations/webhooks/myfatoorah", config.CallbackUrl.Trim())
                Dim amountVal As Decimal = Math.Round(request.Amount, 3, MidpointRounding.AwayFromZero)
                Dim descText As String = If(String.IsNullOrWhiteSpace(request.Description), $"INV_{request.InvID}", request.Description.Trim())
                If descText.Length > 200 Then descText = descText.Substring(0, 200)

                Dim expiryHours As Integer = If(config IsNot Nothing AndAlso config.LinkExpiryHours > 0, config.LinkExpiryHours, 72)
                Dim expiryStr As String = DateTime.UtcNow.AddHours(expiryHours).ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture)

                Dim payloadObj As New Dictionary(Of String, Object) From {
                    {"CustomerName", custName},
                    {"DisplayCurrencyIso", currencyCode},
                    {"MobileCountryCode", "+965"},
                    {"CustomerMobile", phoneDigits},
                    {"InvoiceValue", amountVal},
                    {"Language", "ar"},
                    {"CallBackUrl", callbackUrl},
                    {"ErrorUrl", callbackUrl},
                    {"CustomerReference", $"INV_{request.InvID}"},
                    {"UserDefinedField", descText},
                    {"ExpiryDate", expiryStr}
                }

                If paymentMethodId.HasValue AndAlso paymentMethodId.Value > 0 Then
                    payloadObj("PaymentMethodId") = paymentMethodId.Value
                Else
                    payloadObj("NotificationOption") = "LNK"
                End If

                If Not String.IsNullOrWhiteSpace(request.CustomerEmail) Then
                    payloadObj("CustomerEmail") = request.CustomerEmail.Trim()
                End If

                Dim bodyJson As String = JsonSerializer.Serialize(payloadObj)

                Using client = CreateClient(config.SecretKeyEncrypted, 20)
                    Dim resp = Await client.PostAsync(url, New StringContent(bodyJson, Encoding.UTF8, "application/json"))
                    result.RawJson = Await resp.Content.ReadAsStringAsync()

                    Dim root = DeserializeDict(result.RawJson)
                    Dim apiOk As Boolean = resp.IsSuccessStatusCode AndAlso GetBool(root, "IsSuccess", resp.IsSuccessStatusCode)

                    If apiOk Then
                        Dim dataDict = GetDict(root, "Data")
                        Dim invIdStr As String = GetStr(dataDict, "InvoiceId")
                        Dim payUrl As String = GetStr(dataDict, "InvoiceURL")
                        If String.IsNullOrWhiteSpace(payUrl) Then
                            payUrl = GetStr(dataDict, "PaymentURL")
                        End If

                        If Not String.IsNullOrWhiteSpace(payUrl) AndAlso Not String.IsNullOrWhiteSpace(invIdStr) Then
                            result.IsSuccess = True
                            result.ExternalChargeID = invIdStr
                            result.ExternalInvoiceID = invIdStr
                            result.PaymentUrl = payUrl
                            result.QrCodePayload = payUrl
                            Return result
                        End If
                    End If

                    Dim errDetail = ExtractMyFatoorahErrorDetails(result.RawJson)
                    result.IsSuccess = False
                    result.ErrorMessageAr = $"خطأ من MyFatoorah ({CInt(resp.StatusCode)}): {If(String.IsNullOrWhiteSpace(errDetail), "لم يتم إرجاع رابط الدفع من البوابة.", errDetail)}"
                End Using
            Catch ex As Exception
                result.IsSuccess = False
                result.ErrorMessageAr = "استثناء أثناء إنشاء رابط MyFatoorah: " & ex.Message
            End Try

            Return result
        End Function

        ''' <summary>
        ''' الاستعلام عن حالة الفاتورة والمعاملات عبر POST /v2/GetPaymentStatus
        ''' </summary>
        Public Async Function CheckPaymentStatusAsync(config As IntegrationProviderConfig, externalId As String) As Task(Of String) Implements IPaymentGatewayProvider.CheckPaymentStatusAsync
            Try
                If String.IsNullOrWhiteSpace(externalId) Then Return "Pending"

                Dim url As String = ResolveBaseUrl(config) & "/v2/GetPaymentStatus"
                Dim bodyJson As String = JsonSerializer.Serialize(New Dictionary(Of String, Object) From {
                    {"Key", externalId.Trim()},
                    {"KeyType", "InvoiceId"}
                })

                Using client = CreateClient(config.SecretKeyEncrypted, 15)
                    Dim resp = Await client.PostAsync(url, New StringContent(bodyJson, Encoding.UTF8, "application/json"))
                    Dim rawJson = Await resp.Content.ReadAsStringAsync()
                    If Not resp.IsSuccessStatusCode Then Return "Pending"

                    Dim root = DeserializeDict(rawJson)
                    If Not GetBool(root, "IsSuccess", True) Then Return "Pending"

                    Dim dataDict = GetDict(root, "Data")
                    Dim invStatus As String = GetStr(dataDict, "InvoiceStatus").Trim().ToUpperInvariant()
                    Dim txArr = GetArray(dataDict, "InvoiceTransactions")

                    Dim hasSuccessTx As Boolean = False
                    Dim hasAnyTx As Boolean = False
                    Dim allTxFailed As Boolean = True

                    If txArr IsNot Nothing AndAlso txArr.Length > 0 Then
                        hasAnyTx = True
                        For Each item In txArr
                            Dim txDict = TryCast(item, Dictionary(Of String, Object))
                            If txDict Is Nothing Then Continue For
                            Dim txStatus As String = GetStr(txDict, "TransactionStatus").Trim().ToUpperInvariant()
                            If txStatus = "SUCCSS" OrElse txStatus = "SUCCESS" OrElse txStatus = "PAID" OrElse txStatus = "CAPTURED" Then
                                hasSuccessTx = True
                                allTxFailed = False
                            ElseIf txStatus <> "FAILED" AndAlso txStatus <> "ERROR" AndAlso txStatus <> "DECLINED" Then
                                allTxFailed = False
                            End If
                        Next
                    Else
                        allTxFailed = False
                    End If

                    If invStatus = "PAID" OrElse invStatus = "CAPTURED" OrElse invStatus = "SUCCESS" OrElse hasSuccessTx Then
                        Return "Paid"
                    ElseIf invStatus = "REFUNDED" Then
                        Return "Refunded"
                    ElseIf invStatus = "PARTIALLYREFUNDED" OrElse invStatus = "PARTIALLY_REFUNDED" Then
                        Return "PartiallyRefunded"
                    ElseIf invStatus = "CANCELED" OrElse invStatus = "CANCELLED" OrElse invStatus = "EXPIRED" Then
                        Return "Expired"
                    ElseIf invStatus = "FAILED" OrElse invStatus = "DECLINED" OrElse (hasAnyTx AndAlso allTxFailed) Then
                        Return "Failed"
                    End If
                End Using
            Catch
            End Try
            Return "Pending"
        End Function

        ''' <summary>
        ''' إرجاع المبلغ كلياً أو جزئياً عبر POST /v2/MakeRefund
        ''' </summary>
        Public Async Function ProcessRefundAsync(config As IntegrationProviderConfig, request As PaymentRefundRequest) As Task(Of PaymentRefundResult) Implements IPaymentGatewayProvider.ProcessRefundAsync
            Dim res As New PaymentRefundResult()
            Try
                Dim url As String = ResolveBaseUrl(config) & "/v2/MakeRefund"
                Dim reasonText As String = If(String.IsNullOrWhiteSpace(request.Reason), "إرجاع مبلغ للعميل", request.Reason.Trim())
                If reasonText.Length > 200 Then reasonText = reasonText.Substring(0, 200)

                Dim payloadObj As New Dictionary(Of String, Object) From {
                    {"KeyType", "InvoiceId"},
                    {"Key", If(request.ExternalChargeID, "").Trim()},
                    {"RefundChargeOnCustomer", request.RefundChargeOnCustomer},
                    {"ServiceChargeOnCustomer", request.ServiceChargeOnCustomer},
                    {"Amount", Math.Round(request.RefundAmount, 3, MidpointRounding.AwayFromZero)},
                    {"Comment", reasonText}
                }
                Dim bodyJson As String = JsonSerializer.Serialize(payloadObj)

                Using client = CreateClient(config.SecretKeyEncrypted, 20)
                    Dim resp = Await client.PostAsync(url, New StringContent(bodyJson, Encoding.UTF8, "application/json"))
                    res.RawJson = Await resp.Content.ReadAsStringAsync()

                    Dim root = DeserializeDict(res.RawJson)
                    Dim isApiOk As Boolean = resp.IsSuccessStatusCode AndAlso GetBool(root, "IsSuccess", resp.IsSuccessStatusCode)

                    If isApiOk Then
                        Dim dataDict = GetDict(root, "Data")
                        Dim refId As String = GetStr(dataDict, "RefundId")
                        If String.IsNullOrWhiteSpace(refId) Then refId = GetStr(dataDict, "RefundReference")
                        If String.IsNullOrWhiteSpace(refId) Then refId = GetStr(root, "RefundId")

                        res.IsSuccess = True
                        res.ExternalRefundID = If(String.IsNullOrWhiteSpace(refId), $"MF_REF_{request.LinkID}", refId)
                        res.RefundStatus = "REFUNDED"
                        res.MessageAr = $"✅ تم تنفيذ إرجاع المبلغ عبر MyFatoorah بنجاح (رقم الاسترداد: {res.ExternalRefundID})."
                    Else
                        res.IsSuccess = False
                        res.RefundStatus = "FAILED"
                        Dim errDetail = ExtractMyFatoorahErrorDetails(res.RawJson)
                        res.MessageAr = TranslateGatewayRefundError("MyFatoorah", CInt(resp.StatusCode), res.RawJson, errDetail)
                    End If
                End Using
            Catch ex As Exception
                res.IsSuccess = False
                res.RefundStatus = "ERROR"
                res.MessageAr = "❌ استثناء أثناء إرجاع المبلغ عبر MyFatoorah: " & ex.Message
            End Try

            Return res
        End Function

        ''' <summary>
        ''' الاستعلام عن حالة الاسترداد عبر POST /v2/GetRefundStatus
        ''' </summary>
        Public Async Function GetRefundStatusAsync(config As IntegrationProviderConfig, key As String, Optional keyType As String = "InvoiceId") As Task(Of String)
            Try
                If String.IsNullOrWhiteSpace(key) Then Return "PENDING"
                Dim url As String = ResolveBaseUrl(config) & "/v2/GetRefundStatus"
                Dim bodyJson As String = JsonSerializer.Serialize(New Dictionary(Of String, Object) From {
                    {"Key", key.Trim()},
                    {"KeyType", keyType}
                })
                Using client = CreateClient(config.SecretKeyEncrypted, 15)
                    Dim resp = Await client.PostAsync(url, New StringContent(bodyJson, Encoding.UTF8, "application/json"))
                    Dim rawJson = Await resp.Content.ReadAsStringAsync()
                    If Not resp.IsSuccessStatusCode Then Return "PENDING"

                    Dim root = DeserializeDict(rawJson)
                    Dim dataDict = GetDict(root, "Data")
                    Dim listArr = GetArray(dataDict, "RefundStatusResult")
                    If listArr IsNot Nothing AndAlso listArr.Length > 0 Then
                        Dim firstItem = TryCast(listArr(0), Dictionary(Of String, Object))
                        Dim st = GetStr(firstItem, "RefundStatus").Trim().ToUpperInvariant()
                        If Not String.IsNullOrWhiteSpace(st) Then Return st
                    End If
                End Using
            Catch
            End Try
            Return "PENDING"
        End Function

    End Class

End Namespace
