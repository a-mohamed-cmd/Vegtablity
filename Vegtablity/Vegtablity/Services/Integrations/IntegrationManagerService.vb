Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Diagnostics
Imports System.Linq
Imports System.Threading.Tasks
Imports Dapper
Imports Vegtablity.Helpers
Imports Vegtablity.Models.Integrations

Namespace Services.Integrations

    ''' <summary>
    ''' الخدمة المركزية المعزولة لإدارة بوابات الدفع ومنصات التوصيل (IntegrationManagerService)
    ''' تطبق معمارية MVVM الصارمة واستدعاء الإجراءات المخزنة المعتمدة في SQLVegtablity.sql حصراً دون أي استعلامات نصية مباشرة
    ''' </summary>
    Public Class IntegrationManagerService

        Private ReadOnly _dbHelper As New DatabaseHelper()
        Private ReadOnly _paymentProviders As Dictionary(Of String, IPaymentGatewayProvider)
        Private ReadOnly _deliveryProviders As Dictionary(Of String, IDeliveryPlatformProvider)
        Public ReadOnly Property QrService As New PaymentQrGeneratorService()

        Public Sub New()
            _paymentProviders = New Dictionary(Of String, IPaymentGatewayProvider)(StringComparer.OrdinalIgnoreCase) From {
                {"TAP", New TapPaymentProvider()},
                {"MYFATOORAH", New MyFatoorahProvider()},
                {"UPAYMENTS", New UPaymentsProvider()}
            }

            _deliveryProviders = New Dictionary(Of String, IDeliveryPlatformProvider)(StringComparer.OrdinalIgnoreCase) From {
                {"TALABAT", New TalabatPlatformProvider()}
            }
        End Sub

        ''' <summary>
        ''' جلب جميع البوابات (أو البوابات المفعلة فقط في CompanySettings)
        ''' </summary>
        Public Function GetProviders(Optional onlyEnabled As Boolean = False) As List(Of IntegrationProviderConfig)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of IntegrationProviderConfig)(
                        StoredProcedures.SP_INTEGRATION_GETPROVIDERS,
                        New With {.OnlyEnabled = onlyEnabled},
                        commandType:=CommandType.StoredProcedure
                    ).ToList()
                End Using
            Catch ex As Exception
                Return New List(Of IntegrationProviderConfig)()
            End Try
        End Function

        ''' <summary>
        ''' التحقق مما إذا كانت منصة Talabat مفعلة ومختبرة الاتصال ومحفوظة (لإظهار صفحة المبيعات الخاصة بـ Talabat)
        ''' </summary>
        Public Function IsTalabatConfiguredAndActive() As Boolean
            Try
                Dim list = GetProviders(onlyEnabled:=True)
                Dim talabat = list.FirstOrDefault(Function(p) String.Equals(p.ProviderCode, "TALABAT", StringComparison.OrdinalIgnoreCase))
                Return talabat IsNot Nothing AndAlso talabat.IsEnabledInCompany AndAlso talabat.IsConfigured AndAlso talabat.IsConnectionVerified
            Catch
                Return False
            End Try
        End Function

        ''' <summary>
        ''' التحقق مما إذا كانت هناك أي بوابة دفع مفعلة ومهيأة
        ''' </summary>
        Public Function HasAnyConfiguredPaymentGateway() As Boolean
            Try
                Dim list = GetProviders(onlyEnabled:=True)
                Return list.Any(Function(p) p.IsPaymentGateway AndAlso p.IsEnabledInCompany)
            Catch
                Return False
            End Try
        End Function

        ''' <summary>
        ''' اختبار الاتصال الحي مع أي بوابة (Payment Gateway أو Delivery Platform)
        ''' </summary>
        Public Async Function TestProviderConnectionAsync(config As IntegrationProviderConfig) As Task(Of ConnectionTestResult)
            If config Is Nothing Then
                Return New ConnectionTestResult With {
                    .IsSuccess = False,
                    .VerifiedStatus = "Error",
                    .MessageAr = "❌ لم يتم تحديد بوابة لاختبار الاتصال."
                }
            End If

            Try
                Dim code As String = If(config.ProviderCode, "").ToUpperInvariant()
                If _paymentProviders.ContainsKey(code) Then
                    Return Await _paymentProviders(code).TestConnectionAsync(config)
                ElseIf _deliveryProviders.ContainsKey(code) Then
                    Return Await _deliveryProviders(code).TestConnectionAsync(config)
                Else
                    If String.IsNullOrWhiteSpace(config.SecretKeyEncrypted) Then
                        Return New ConnectionTestResult With {
                            .IsSuccess = False,
                            .VerifiedStatus = "Error",
                            .MessageAr = "❌ يرجى إدخال مفتاح الربط السري (API Secret Key) أولاً."
                        }
                    End If
                    Return New ConnectionTestResult With {
                        .IsSuccess = True,
                        .VerifiedStatus = If(String.Equals(config.EnvironmentMode, "Live", StringComparison.OrdinalIgnoreCase), "LiveVerified", "SandboxVerified"),
                        .MessageAr = $"✅ تم التحقق من إعدادات {config.ProviderNameAr} بنجاح.",
                        .NextStepGuidanceAr = "يمكنك الآن الضغط على حفظ الإعدادات وتفعيل البوابة."
                    }
                End If
            Catch ex As Exception
                Return New ConnectionTestResult With {
                    .IsSuccess = False,
                    .VerifiedStatus = "Error",
                    .MessageAr = "❌ فشل اختبار الاتصال: " & ex.Message
                }
            End Try
        End Function

        ''' <summary>
        ''' حفظ إعدادات البوابة بعد نجاح اختبار الاتصال حصراً (ينشئ الحساب المحاسبي أو عميل Talabat تلقائياً)
        ''' </summary>
        Public Function SaveProviderConfiguration(config As IntegrationProviderConfig) As IntegrationProviderConfig
            If config Is Nothing Then Throw New ArgumentNullException(NameOf(config))

            If Not config.IsConnectionVerified Then
                Throw New InvalidOperationException("لا يمكن حفظ إعدادات البوابة وتنفيذ ما يترتب عليها إلا بعد نجاح اختبار الاتصال (Test Connection) أولاً.")
            End If

            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim saved = conn.Query(Of IntegrationProviderConfig)(
                    StoredProcedures.SP_INTEGRATION_SAVEPROVIDERCONFIG,
                    New With {
                        .ProviderID = config.ProviderID,
                        .EnvironmentMode = config.EnvironmentMode,
                        .BaseUrl = config.BaseUrl,
                        .MerchantID = config.MerchantID,
                        .PublicKey = config.PublicKey,
                        .SecretKeyEncrypted = config.SecretKeyEncrypted,
                        .WebhookSecret = config.WebhookSecret,
                        .CallbackUrl = config.CallbackUrl,
                        .DefaultCurrency = config.DefaultCurrency,
                        .CommissionPercent = config.CommissionPercent,
                        .FixedFee = config.FixedFee,
                        .LinkedAccountID = config.LinkedAccountID,
                        .DefaultCreditAccountID = config.DefaultCreditAccountID,
                        .CommissionAccountID = config.CommissionAccountID,
                        .RefundDebitAccountID = config.RefundDebitAccountID,
                        .RefundCreditAccountID = config.RefundCreditAccountID,
                        .AutoSendLinkOnInvoiceSave = config.AutoSendLinkOnInvoiceSave,
                        .PrintQrOnPos80mm = config.PrintQrOnPos80mm,
                        .PrintQrOnPos58mm = config.PrintQrOnPos58mm,
                        .PrintQrOnWpfInvoice = config.PrintQrOnWpfInvoice,
                        .AutoSendWhatsApp = config.AutoSendWhatsApp,
                        .AutoSendSms = config.AutoSendSms,
                        .LinkExpiryHours = config.LinkExpiryHours,
                        .EnableConsolidatedLinks = config.EnableConsolidatedLinks,
                        .DeductCommissionOnShiftClose = config.DeductCommissionOnShiftClose,
                        .EnableGatewayRefunds = config.EnableGatewayRefunds,
                        .AllowPartialRefunds = config.AllowPartialRefunds,
                        .AutoPostRefundJournalEntry = config.AutoPostRefundJournalEntry,
                        .RefundChargeOnCustomer = config.RefundChargeOnCustomer,
                        .ServiceChargeOnCustomer = config.ServiceChargeOnCustomer,
                        .ConnectionStatus = config.ConnectionStatus,
                        .StatusMessageAr = config.StatusMessageAr
                    },
                    commandType:=CommandType.StoredProcedure
                ).FirstOrDefault()

                Return If(saved, config)
            End Using
        End Function

        ''' <summary>
        ''' فصل الاتصال بالبوابة وإلغاء حالتها المفعلة (Disconnect Provider)
        ''' </summary>
        Public Function DisconnectProvider(providerId As Integer) As IntegrationProviderConfig
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of IntegrationProviderConfig)(
                    StoredProcedures.SP_INTEGRATION_DISCONNECTPROVIDER,
                    New With {.ProviderID = providerId},
                    commandType:=CommandType.StoredProcedure
                ).FirstOrDefault()
            End Using
        End Function

        ''' <summary>
        ''' جلب جميع الحسابات الحركية (Transactional Accounts) لاختيار وتخصيص طرفي القيد المحاسبي (المدين والدائن)
        ''' </summary>
        Public Function GetTransactionalAccounts() As List(Of Models.Account)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim all = conn.Query(Of Models.Account)(
                        StoredProcedures.SP_ACCOUNT_GETALL,
                        commandType:=CommandType.StoredProcedure
                    ).Where(Function(a) a.IsTransactional).OrderBy(Function(a) a.AccountCode).ToList()
                    Return all
                End Using
            Catch
                Return New List(Of Models.Account)()
            End Try
        End Function

        ''' <summary>
        ''' إنشاء رابط دفع إلكتروني فعلي عبر البوابة وحفظه في قاعدة البيانات
        ''' </summary>
        Public Async Function CreateAndSavePaymentLinkAsync(config As IntegrationProviderConfig, request As PaymentLinkRequest) As Task(Of (Success As Boolean, Record As PaymentLinkRecord, MessageAr As String))
            Try
                If config Is Nothing OrElse Not config.IsConfigured Then
                    Return (False, Nothing, "البوابة المختارة غير مهيأة أو لم يتم التحقق من اتصالها بعد.")
                End If

                Dim code As String = config.ProviderCode.ToUpperInvariant()
                If Not _paymentProviders.ContainsKey(code) Then
                    Return (False, Nothing, "مزود بوابة الدفع غير مدعوم لإصدار الروابط.")
                End If

                Dim apiResult As PaymentLinkCreationResult = Await _paymentProviders(code).CreatePaymentLinkAsync(config, request)
                If Not apiResult.IsSuccess Then
                    Return (False, Nothing, apiResult.ErrorMessageAr)
                End If

                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim saved = conn.Query(Of PaymentLinkRecord)(
                        StoredProcedures.SP_PAYMENTLINK_SAVE,
                        New With {
                            .InvID = request.InvID,
                            .PartnerID = request.PartnerID,
                            .ProviderID = config.ProviderID,
                            .ProviderCode = config.ProviderCode,
                            .ExternalChargeID = apiResult.ExternalChargeID,
                            .ExternalInvoiceID = apiResult.ExternalInvoiceID,
                            .PaymentUrl = apiResult.PaymentUrl,
                            .QrCodePayload = apiResult.QrCodePayload,
                            .Amount = request.Amount,
                            .CurrencyCode = If(String.IsNullOrWhiteSpace(request.CurrencyCode), config.DefaultCurrency, request.CurrencyCode),
                            .CustomerName = request.CustomerName,
                            .CustomerPhone = request.CustomerPhone,
                            .CustomerEmail = request.CustomerEmail,
                            .SendViaWhatsApp = request.SendViaWhatsApp,
                            .SendViaSms = request.SendViaSms,
                            .SendViaEmail = request.SendViaEmail,
                            .PrintQrMode = config.PrintOptionsSummary,
                            .CreatedByUserID = request.CreatedByUserID,
                            .ShiftID = request.ShiftID,
                            .RawResponseJson = apiResult.RawJson,
                            .Notes = request.Description,
                            .IsConsolidated = request.IsConsolidated,
                            .ConsolidatedInvoicesCsv = request.ConsolidatedInvoicesCsv
                        },
                        commandType:=CommandType.StoredProcedure
                    ).FirstOrDefault()

                    If request.SendViaWhatsApp AndAlso Not String.IsNullOrWhiteSpace(apiResult.PaymentUrl) Then
                        SendPaymentLinkViaWhatsApp(request.CustomerPhone, request.CustomerName, request.InvID, request.Amount, config.DefaultCurrency, apiResult.PaymentUrl)
                    End If

                    Return (True, saved, "✅ تم إنشاء رابط الدفع الإلكتروني وحفظه بنجاح.")
                End Using
            Catch ex As Exception
                Return (False, Nothing, "❌ خطأ أثناء إنشاء رابط الدفع: " & ex.Message)
            End Try
        End Function

        ''' <summary>
        ''' التحقق الفوري من حالة الدفع من البوابة وتحديث قاعدة البيانات (مما يفعل تريجر السداد والقيد المحاسبي آلياً)
        ''' </summary>
        Public Async Function RefreshPaymentLinkStatusAsync(record As PaymentLinkRecord) As Task(Of String)
            Dim res = Await RefreshPaymentLinkStatusWithFeedbackAsync(record)
            Return res.NewStatus
        End Function

        ''' <summary>
        ''' التحقق الفوري من حالة الدفع مع إرجاع رسالة نتيجة تفصيلية أو رسالة سبب توقف التريجر في حال حدوث خطأ محاسبي
        ''' </summary>
        Public Async Function RefreshPaymentLinkStatusWithFeedbackAsync(record As PaymentLinkRecord) As Task(Of (Success As Boolean, NewStatus As String, MessageAr As String))
            If record Is Nothing Then
                Return (False, "Pending", "⚠️ لم يتم تحديد رابط الدفع المراد فحص حالته.")
            End If
            Try
                Dim providers = GetProviders(onlyEnabled:=False)
                Dim cfg = providers.FirstOrDefault(Function(p) p.ProviderID = record.ProviderID OrElse String.Equals(p.ProviderCode, record.ProviderCode, StringComparison.OrdinalIgnoreCase))
                If cfg Is Nothing Then
                    Return (False, record.LinkStatus, "⚠️ لم يتم العثور على إعدادات البوابة المرتبطة بهذا الرابط.")
                End If

                Dim code As String = cfg.ProviderCode.ToUpperInvariant()
                If _paymentProviders.ContainsKey(code) AndAlso Not String.IsNullOrWhiteSpace(record.ExternalChargeID) Then
                    Dim newStatus As String = Await _paymentProviders(code).CheckPaymentStatusAsync(cfg, record.ExternalChargeID)
                    If Not String.Equals(newStatus, record.LinkStatus, StringComparison.OrdinalIgnoreCase) Then
                        Using conn As IDbConnection = _dbHelper.GetConnection()
                            conn.Execute(
                                StoredProcedures.SP_PAYMENTLINK_UPDATESTATUS,
                                New With {
                                    .LinkID = record.LinkID,
                                    .ExternalChargeID = record.ExternalChargeID,
                                    .NewStatus = newStatus,
                                    .RawResponseJson = CType(Nothing, String)
                                },
                                commandType:=CommandType.StoredProcedure
                            )
                        End Using
                        Return (True, newStatus, $"✅ تم تحديث حالة الرابط #{record.LinkID} إلى ({newStatus}) وترحيل القيد المحاسبي بنجاح.")
                    End If
                    Return (True, record.LinkStatus, $"ℹ️ حالة الرابط #{record.LinkID} لدى البوابة ما زالت ({record.LinkStatus}).")
                End If
                Return (True, record.LinkStatus, $"ℹ️ حالة الرابط #{record.LinkID} الحالية: ({record.LinkStatus}).")
            Catch ex As Exception
                Return (False, record.LinkStatus, "❌ توقف تحديث الحالة / القيد المحاسبي: " & ex.Message)
            End Try
        End Function

        ''' <summary>
        ''' التحقق الفوري من صلاحية المستخدم في تنفيذ عمليات الاسترداد لبوابات الدفع قبل الاتصال بالبوابة
        ''' </summary>
        Public Function CanUserRefundPaymentGateway(userId As Integer) As Boolean
            If userId <= 0 Then Return False
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.QueryFirstOrDefault(Of Boolean)(
                        StoredProcedures.SP_USER_CANREFUNDPAYMENTGATEWAY,
                        New With {.UserID = userId},
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch
                Try
                    Using conn As IDbConnection = _dbHelper.GetConnection()
                        Dim users = conn.Query(Of Models.User)(
                            StoredProcedures.SP_USER_GETALL,
                            commandType:=CommandType.StoredProcedure
                        )
                        Dim match = users.FirstOrDefault(Function(u) u.UserID = userId)
                        If match Is Nothing OrElse Not match.IsActive Then Return False
                        Dim perm = New PermissionService().GetPermissionsForForm(match.RoleID, "PaymentGatewayInvoices")
                        Return perm IsNot Nothing AndAlso perm.CanDelete
                    End Using
                Catch
                    Return False
                End Try
            End Try
        End Function

        ''' <summary>
        ''' تنفيذ إرجاع المبلغ (Refund) عبر البوابة ثم تسجيل القيد المحاسبي العكسي وتحديث الفاتورة
        ''' </summary>
        Public Async Function RefundPaymentLinkAsync(record As PaymentLinkRecord, refundAmount As Decimal, reason As String, userId As Integer) As Task(Of PaymentRefundResult)
            Dim failRes As New PaymentRefundResult With {.IsSuccess = False}
            Try
                If record Is Nothing Then
                    failRes.MessageAr = "لم يتم تحديد رابط الدفع المراد استرداده."
                    Return failRes
                End If

                If userId <= 0 OrElse Not CanUserRefundPaymentGateway(userId) Then
                    failRes.MessageAr = "عذراً، لا تملك صلاحية استرداد مبالغ بوابات الدفع الإلكتروني."
                    Return failRes
                End If

                Dim providers = GetProviders(onlyEnabled:=False)
                Dim cfg = providers.FirstOrDefault(Function(p) p.ProviderID = record.ProviderID OrElse String.Equals(p.ProviderCode, record.ProviderCode, StringComparison.OrdinalIgnoreCase))
                If cfg Is Nothing OrElse Not cfg.EnableGatewayRefunds Then
                    failRes.MessageAr = "خاصية إرجاع المبالغ غير مفعلة لهذه البوابة في الإعدادات."
                    Return failRes
                End If

                Dim code As String = cfg.ProviderCode.ToUpperInvariant()
                If Not _paymentProviders.ContainsKey(code) Then
                    failRes.MessageAr = "هذه البوابة لا تدعم الاسترداد المباشر."
                    Return failRes
                End If

                Dim req As New PaymentRefundRequest With {
                    .LinkID = record.LinkID,
                    .ExternalChargeID = If(String.IsNullOrWhiteSpace(record.ExternalChargeID), record.ExternalInvoiceID, record.ExternalChargeID),
                    .RefundAmount = refundAmount,
                    .CurrencyCode = record.CurrencyCode,
                    .Reason = reason,
                    .RefundChargeOnCustomer = cfg.RefundChargeOnCustomer,
                    .ServiceChargeOnCustomer = cfg.ServiceChargeOnCustomer,
                    .UserID = userId
                }

                Dim gatewayRefund As PaymentRefundResult = Await _paymentProviders(code).ProcessRefundAsync(cfg, req)
                If Not gatewayRefund.IsSuccess Then
                    Return gatewayRefund
                End If

                Using conn As IDbConnection = _dbHelper.GetConnection()
                    conn.Execute(
                        StoredProcedures.SP_PAYMENTLINK_RECORDREFUND,
                        New With {
                            .LinkID = record.LinkID,
                            .RefundAmount = refundAmount,
                            .ExternalRefundID = gatewayRefund.ExternalRefundID,
                            .RefundReason = reason,
                            .UserID = userId
                        },
                        commandType:=CommandType.StoredProcedure
                    )
                End Using

                Return gatewayRefund
            Catch ex As Exception
                failRes.MessageAr = "❌ خطأ أثناء استرداد المبلغ: " & ex.Message
                Return failRes
            End Try
        End Function

        ''' <summary>
        ''' جلب قائمة روابط وفواتير الدفع مع الفلترة والترقيم على مستوى قاعدة البيانات (Server-Side Pagination)
        ''' </summary>
        Public Function GetFilteredPaymentLinks(Optional providerCode As String = Nothing, Optional status As String = Nothing, Optional startDate As DateTime? = Nothing, Optional endDate As DateTime? = Nothing, Optional searchText As String = Nothing, Optional pageNumber As Integer = 1, Optional pageSize As Integer = 25) As List(Of PaymentLinkRecord)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of PaymentLinkRecord)(
                        StoredProcedures.SP_PAYMENTLINK_GETFILTERED,
                        New With {
                            .ProviderCode = providerCode,
                            .LinkStatus = status,
                            .StartDate = startDate,
                            .EndDate = endDate,
                            .SearchText = searchText,
                            .PageNumber = If(pageNumber < 1, 1, pageNumber),
                            .PageSize = If(pageSize < 1, 25, pageSize)
                        },
                        commandType:=CommandType.StoredProcedure
                    ).ToList()
                End Using
            Catch
                Return New List(Of PaymentLinkRecord)()
            End Try
        End Function

        ''' <summary>
        ''' جلب بيانات فاتورة سريعة (المبلغ المتبقي والعميل) عبر الإجراء المخزن sp_InvoicePaymentLink_GetInvoiceQuickInfo
        ''' </summary>
        Public Function GetInvoiceQuickInfo(invId As Integer) As (Found As Boolean, Amount As Decimal, PartnerID As Integer?, PartnerName As String, PartnerPhone As String)
            If invId <= 0 Then Return (False, 0D, Nothing, "", "")
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim row = conn.QueryFirstOrDefault(
                        StoredProcedures.SP_PAYMENTLINK_GETINVOICEQUICKINFO,
                        New With {.InvID = invId},
                        commandType:=CommandType.StoredProcedure
                    )
                    If row IsNot Nothing Then
                        Dim remAmt As Decimal = If(row.Remainder IsNot Nothing, CDec(row.Remainder), 0D)
                        Dim netAmt As Decimal = If(row.NetAmount IsNot Nothing, CDec(row.NetAmount), 0D)
                        Dim targetAmt As Decimal = If(remAmt > 0D, remAmt, netAmt)
                        Dim pId As Integer? = If(row.PartnerID IsNot Nothing, CType(CInt(row.PartnerID), Integer?), Nothing)
                        Dim pName As String = If(row.PartnerName IsNot Nothing, CStr(row.PartnerName), "")
                        Dim pPhone As String = If(row.Phone IsNot Nothing, CStr(row.Phone), "")
                        Return (True, targetAmt, pId, pName, pPhone)
                    End If
                End Using
            Catch
            End Try
            Return (False, 0D, Nothing, "", "")
        End Function

        ''' <summary>
        ''' إرسال رابط الدفع عبر واتساب مباشرة
        ''' </summary>
        Public Sub SendPaymentLinkViaWhatsApp(phone As String, customerName As String, invId As Integer, amount As Decimal, currency As String, paymentUrl As String)
            Try
                Dim cleanDigits As String = IntegrationJsonHelper.CleanPhoneDigits(phone)
                If Not cleanDigits.StartsWith("965") AndAlso cleanDigits.Length = 8 Then
                    cleanDigits = "965" & cleanDigits
                End If
                Dim msg As String = $"مرحباً {If(String.IsNullOrWhiteSpace(customerName), "عميلنا العزيز", customerName)}،" & Environment.NewLine &
                                    $"يرجى التفضل بسداد فاتورة رقم #{invId} بقيمة {amount:N3} {currency} عبر رابط الدفع الآمن:" & Environment.NewLine &
                                    paymentUrl
                Dim waUrl As String = $"https://wa.me/{cleanDigits}?text={Uri.EscapeDataString(msg)}"
                Process.Start(New ProcessStartInfo(waUrl) With {.UseShellExecute = True})
            Catch
            End Try
        End Sub

        ' =================================================================================
        ' عمليات منصة Talabat (استقبال الطلبات، القبول، الرفض، الجاهزية، حالة الفرع)
        ' =================================================================================

        Public Function GetTalabatOrders(Optional status As String = Nothing, Optional startDate As DateTime? = Nothing, Optional endDate As DateTime? = Nothing, Optional searchText As String = Nothing) As List(Of TalabatOrderRecord)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Return conn.Query(Of TalabatOrderRecord)(
                        StoredProcedures.SP_TALABATORDER_GETFILTERED,
                        New With {
                            .OrderStatus = status,
                            .StartDate = startDate,
                            .EndDate = endDate,
                            .SearchText = searchText
                        },
                        commandType:=CommandType.StoredProcedure
                    ).ToList()
                End Using
            Catch
                Return New List(Of TalabatOrderRecord)()
            End Try
        End Function

        Public Function SaveOrUpdateTalabatOrder(order As TalabatOrderRecord, Optional autoCreateInvoice As Boolean = False) As TalabatOrderRecord
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of TalabatOrderRecord)(
                    StoredProcedures.SP_TALABATORDER_SAVEORUPDATE,
                    New With {
                        .OrderToken = order.OrderToken,
                        .OrderCode = order.OrderCode,
                        .ShortCode = order.ShortCode,
                        .RemoteVendorId = order.RemoteVendorId,
                        .ExpeditionType = order.ExpeditionType,
                        .PaymentType = order.PaymentType,
                        .SubTotal = order.SubTotal,
                        .DeliveryFee = order.DeliveryFee,
                        .DiscountAmount = order.DiscountAmount,
                        .GrandTotal = order.GrandTotal,
                        .CurrencyCode = order.CurrencyCode,
                        .OrderStatus = order.OrderStatus,
                        .CustomerName = order.CustomerName,
                        .CustomerPhone = order.CustomerPhone,
                        .DeliveryAddress = order.DeliveryAddress,
                        .Comments = order.Comments,
                        .ItemsJson = order.ItemsJson,
                        .RawPayloadJson = order.RawPayloadJson,
                        .RejectionReason = order.RejectionReason,
                        .UserID = 1,
                        .AutoCreateSalesInvoice = autoCreateInvoice
                    },
                    commandType:=CommandType.StoredProcedure
                ).FirstOrDefault()
            End Using
        End Function

        Public Async Function AcceptTalabatOrderAsync(order As TalabatOrderRecord, prepTimeMinutes As Integer) As Task(Of (Success As Boolean, MessageAr As String))
            Try
                Dim cfg = GetProviders(onlyEnabled:=False).FirstOrDefault(Function(p) String.Equals(p.ProviderCode, "TALABAT", StringComparison.OrdinalIgnoreCase))
                If cfg IsNot Nothing AndAlso _deliveryProviders.ContainsKey("TALABAT") Then
                    Await _deliveryProviders("TALABAT").AcceptOrderAsync(cfg, order.OrderToken, prepTimeMinutes)
                End If

                order.OrderStatus = "Accepted"
                Dim updated = SaveOrUpdateTalabatOrder(order, autoCreateInvoice:=True)
                Return (True, $"✅ تم قبول طلب Talabat رقم #{order.OrderCode} وإصدار فاتورة مبيعات رقم #{If(updated?.InvID, 0)} باسم عميل المبيعات (Talabat).")
            Catch ex As Exception
                Return (False, "❌ خطأ أثناء قبول طلب Talabat: " & ex.Message)
            End Try
        End Function

        Public Async Function RejectTalabatOrderAsync(order As TalabatOrderRecord, reason As String) As Task(Of (Success As Boolean, MessageAr As String))
            Try
                Dim cfg = GetProviders(onlyEnabled:=False).FirstOrDefault(Function(p) String.Equals(p.ProviderCode, "TALABAT", StringComparison.OrdinalIgnoreCase))
                If cfg IsNot Nothing AndAlso _deliveryProviders.ContainsKey("TALABAT") Then
                    Await _deliveryProviders("TALABAT").RejectOrderAsync(cfg, order.OrderToken, reason)
                End If

                order.OrderStatus = "Rejected"
                order.RejectionReason = reason
                SaveOrUpdateTalabatOrder(order, autoCreateInvoice:=False)
                Return (True, $"🚫 تم رفض طلب Talabat رقم #{order.OrderCode} وإشعار المنصة بالسبب ({reason}).")
            Catch ex As Exception
                Return (False, "❌ خطأ أثناء رفض طلب Talabat: " & ex.Message)
            End Try
        End Function

        Public Async Function MarkTalabatOrderPreparedAsync(order As TalabatOrderRecord) As Task(Of (Success As Boolean, MessageAr As String))
            Try
                Dim cfg = GetProviders(onlyEnabled:=False).FirstOrDefault(Function(p) String.Equals(p.ProviderCode, "TALABAT", StringComparison.OrdinalIgnoreCase))
                If cfg IsNot Nothing AndAlso _deliveryProviders.ContainsKey("TALABAT") Then
                    Await _deliveryProviders("TALABAT").MarkOrderPreparedAsync(cfg, order.OrderToken)
                End If

                order.OrderStatus = "Prepared"
                SaveOrUpdateTalabatOrder(order, autoCreateInvoice:=False)
                Return (True, $"👨‍🍳 تم إشعار منصة Talabat وسائق التوصيل بأن الطلب #{order.OrderCode} جاهز للتسليم (Order Prepared).")
            Catch ex As Exception
                Return (False, "❌ خطأ أثناء تحديث جاهزية طلب Talabat: " & ex.Message)
            End Try
        End Function

        Public Async Function SetTalabatBranchAvailabilityAsync(isOpen As Boolean) As Task(Of Boolean)
            Try
                Dim cfg = GetProviders(onlyEnabled:=False).FirstOrDefault(Function(p) String.Equals(p.ProviderCode, "TALABAT", StringComparison.OrdinalIgnoreCase))
                If cfg IsNot Nothing AndAlso _deliveryProviders.ContainsKey("TALABAT") Then
                    Return Await _deliveryProviders("TALABAT").UpdateVendorAvailabilityAsync(cfg, cfg.WebhookSecret, isOpen)
                End If
            Catch
            End Try
            Return False
        End Function

    End Class

End Namespace
