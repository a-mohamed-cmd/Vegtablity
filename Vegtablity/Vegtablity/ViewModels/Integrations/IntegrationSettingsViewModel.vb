Imports System
Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows
Imports Vegtablity.Helpers
Imports Vegtablity.Models.Integrations
Imports Vegtablity.Services.Integrations

Namespace ViewModels.Integrations

    ''' <summary>
    ''' ViewModel شاشة إعدادات الربط وبوابات الدفع الإلكتروني ومنصات التوصيل
    ''' يطبق القاعدة الإلزامية: لا يتم حفظ الإعدادات ولا تنفيذ ما يترتب عليها إلا بعد نجاح اختبار الاتصال الفعلي لكل بوابة على حدة
    ''' </summary>
    Public Class IntegrationSettingsViewModel
        Inherits BaseViewModel

        Private ReadOnly _integrationService As New IntegrationManagerService()

        Public Property EnabledProviders As New ObservableCollection(Of IntegrationProviderConfig)()
        Public Property AvailableAccounts As New ObservableCollection(Of GatewayAccountOption)()

        Private _selectedProvider As IntegrationProviderConfig
        Public Property SelectedProvider As IntegrationProviderConfig
            Get
                Return _selectedProvider
            End Get
            Set(value As IntegrationProviderConfig)
                _selectedProvider = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(HasSelectedProvider))
                OnPropertyChanged(NameOf(IsPaymentGatewaySelected))
                OnPropertyChanged(NameOf(IsDeliveryPlatformSelected))
                OnPropertyChanged(NameOf(CanSaveConfig))
                OnPropertyChanged(NameOf(CanDisconnectProvider))
                OnPropertyChanged(NameOf(ConnectionStatusBadge))
                OnPropertyChanged(NameOf(GuidanceMessageAr))
                OnPropertyChanged(NameOf(LinkedEntitySummary))
                NotifyAccountSelectionsChanged()
            End Set
        End Property

        Private Function FindAccountOption(accId As Integer?) As GatewayAccountOption
            If AvailableAccounts Is Nothing OrElse AvailableAccounts.Count = 0 Then Return Nothing
            If Not accId.HasValue OrElse accId.Value <= 0 Then
                Return AvailableAccounts.FirstOrDefault(Function(a) Not a.AccountID.HasValue)
            End If
            Return AvailableAccounts.FirstOrDefault(Function(a) a.AccountID.HasValue AndAlso a.AccountID.Value = accId.Value)
        End Function

        Public Property SelectedDebitAccount As GatewayAccountOption
            Get
                If SelectedProvider Is Nothing Then Return Nothing
                Return FindAccountOption(SelectedProvider.LinkedAccountID)
            End Get
            Set(value As GatewayAccountOption)
                If SelectedProvider IsNot Nothing Then
                    SelectedProvider.LinkedAccountID = If(value IsNot Nothing, value.AccountID, Nothing)
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Public Property SelectedCreditAccount As GatewayAccountOption
            Get
                If SelectedProvider Is Nothing Then Return Nothing
                Return FindAccountOption(SelectedProvider.DefaultCreditAccountID)
            End Get
            Set(value As GatewayAccountOption)
                If SelectedProvider IsNot Nothing Then
                    SelectedProvider.DefaultCreditAccountID = If(value IsNot Nothing, value.AccountID, Nothing)
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Public Property SelectedCommissionAccount As GatewayAccountOption
            Get
                If SelectedProvider Is Nothing Then Return Nothing
                Return FindAccountOption(SelectedProvider.CommissionAccountID)
            End Get
            Set(value As GatewayAccountOption)
                If SelectedProvider IsNot Nothing Then
                    SelectedProvider.CommissionAccountID = If(value IsNot Nothing, value.AccountID, Nothing)
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Public Property SelectedRefundDebitAccount As GatewayAccountOption
            Get
                If SelectedProvider Is Nothing Then Return Nothing
                Return FindAccountOption(SelectedProvider.RefundDebitAccountID)
            End Get
            Set(value As GatewayAccountOption)
                If SelectedProvider IsNot Nothing Then
                    SelectedProvider.RefundDebitAccountID = If(value IsNot Nothing, value.AccountID, Nothing)
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Public Property SelectedRefundCreditAccount As GatewayAccountOption
            Get
                If SelectedProvider Is Nothing Then Return Nothing
                Return FindAccountOption(SelectedProvider.RefundCreditAccountID)
            End Get
            Set(value As GatewayAccountOption)
                If SelectedProvider IsNot Nothing Then
                    SelectedProvider.RefundCreditAccountID = If(value IsNot Nothing, value.AccountID, Nothing)
                    OnPropertyChanged()
                End If
            End Set
        End Property

        Public Function GetFilteredAccounts(searchText As String) As System.Collections.Generic.List(Of GatewayAccountOption)
            If AvailableAccounts Is Nothing Then Return New System.Collections.Generic.List(Of GatewayAccountOption)()
            If String.IsNullOrWhiteSpace(searchText) Then
                Return AvailableAccounts.ToList()
            End If
            Dim q = searchText.Trim()
            Return AvailableAccounts.Where(Function(a) _
                (a.DisplayText IsNot Nothing AndAlso a.DisplayText.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0) OrElse
                (a.AccountCode IsNot Nothing AndAlso a.AccountCode.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0) OrElse
                (a.AccountName IsNot Nothing AndAlso a.AccountName.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0)
            ).ToList()
        End Function

        Private Sub NotifyAccountSelectionsChanged()
            OnPropertyChanged(NameOf(SelectedDebitAccount))
            OnPropertyChanged(NameOf(SelectedCreditAccount))
            OnPropertyChanged(NameOf(SelectedCommissionAccount))
            OnPropertyChanged(NameOf(SelectedRefundDebitAccount))
            OnPropertyChanged(NameOf(SelectedRefundCreditAccount))
        End Sub

        Private _isBusy As Boolean = False
        Public Property IsBusy As Boolean
            Get
                Return _isBusy
            End Get
            Set(value As Boolean)
                _isBusy = value
                OnPropertyChanged()
            End Set
        End Property

        Private _guidanceText As String = "يرجى اختيار البوابة، إدخال مفاتيح الربط، ثم الضغط على زر (🔌 اختبار الاتصال) لتفعيل زر الحفظ."
        Public Property GuidanceMessageAr As String
            Get
                Return _guidanceText
            End Get
            Set(value As String)
                _guidanceText = value
                OnPropertyChanged()
            End Set
        End Property

        Public ReadOnly Property HasSelectedProvider As Boolean
            Get
                Return SelectedProvider IsNot Nothing
            End Get
        End Property

        Public ReadOnly Property HasNoEnabledProviders As Boolean
            Get
                Return EnabledProviders Is Nothing OrElse EnabledProviders.Count = 0
            End Get
        End Property

        Public ReadOnly Property IsPaymentGatewaySelected As Boolean
            Get
                Return SelectedProvider IsNot Nothing AndAlso SelectedProvider.IsPaymentGateway
            End Get
        End Property

        Public ReadOnly Property IsDeliveryPlatformSelected As Boolean
            Get
                Return SelectedProvider IsNot Nothing AndAlso SelectedProvider.IsDeliveryPlatform
            End Get
        End Property

        ''' <summary>
        ''' زر الحفظ لا يتفعل إلا إذا نجح اختبار الاتصال للبوابة المحددة
        ''' </summary>
        Public ReadOnly Property CanSaveConfig As Boolean
            Get
                Return SelectedProvider IsNot Nothing AndAlso SelectedProvider.IsConnectionVerified AndAlso Not IsBusy
            End Get
        End Property

        ''' <summary>
        ''' زر فصل الاتصال يتفعل عندما تكون البوابة متصلة أو مفعلة حالياً
        ''' </summary>
        Public ReadOnly Property CanDisconnectProvider As Boolean
            Get
                Return SelectedProvider IsNot Nothing AndAlso
                       (SelectedProvider.IsConfigured OrElse SelectedProvider.IsConnectionVerified) AndAlso
                       Not IsBusy
            End Get
        End Property

        Public ReadOnly Property ConnectionStatusBadge As String
            Get
                If SelectedProvider Is Nothing Then Return "⚪ لم يتم اختيار بوابة"
                Return SelectedProvider.StatusBadgeText
            End Get
        End Property

        Public ReadOnly Property LinkedEntitySummary As String
            Get
                If SelectedProvider Is Nothing Then Return "-"
                If Not SelectedProvider.IsConfigured Then
                    Return "⏳ سيتم الإنشاء والربط تلقائياً فور نجاح اختبار الاتصال وحفظ الإعدادات"
                End If
                If SelectedProvider.IsDeliveryPlatform Then
                    Return $"👤 عميل المبيعات: {If(String.IsNullOrWhiteSpace(SelectedProvider.LinkedPartnerName), SelectedProvider.ProviderNameAr, SelectedProvider.LinkedPartnerName)} | 🏦 رقم الحساب: {If(String.IsNullOrWhiteSpace(SelectedProvider.LinkedAccountCode), "مرتبط تلقائياً", SelectedProvider.LinkedAccountCode & " - " & SelectedProvider.LinkedAccountName)}"
                End If
                Return $"🏦 الحساب الفرعي في شجرة الحسابات: {If(String.IsNullOrWhiteSpace(SelectedProvider.LinkedAccountCode), "سيتم توليده عند الحفظ", SelectedProvider.LinkedAccountCode & " - " & SelectedProvider.LinkedAccountName)}"
            End Get
        End Property

        ' === Commands ===
        Public Property RefreshProvidersCommand As RelayCommand
        Public Property TestConnectionCommand As RelayCommand
        Public Property SaveProviderConfigCommand As RelayCommand
        Public Property DisconnectProviderCommand As RelayCommand
        Public Property SetSandboxModeCommand As RelayCommand
        Public Property SetLiveModeCommand As RelayCommand

        Public Sub New()
            RefreshProvidersCommand = New RelayCommand(AddressOf ExecuteRefreshProviders)
            TestConnectionCommand = New RelayCommand(AddressOf ExecuteTestConnection)
            SaveProviderConfigCommand = New RelayCommand(AddressOf ExecuteSaveProviderConfig)
            DisconnectProviderCommand = New RelayCommand(AddressOf ExecuteDisconnectProvider)
            SetSandboxModeCommand = New RelayCommand(AddressOf ExecuteSetSandboxMode)
            SetLiveModeCommand = New RelayCommand(AddressOf ExecuteSetLiveMode)

            LoadAvailableAccounts()
            LoadEnabledProviders()
        End Sub

        Public Sub LoadAvailableAccounts()
            Try
                AvailableAccounts.Clear()
                AvailableAccounts.Add(New GatewayAccountOption With {
                    .AccountID = Nothing,
                    .AccountCode = "AUTO",
                    .AccountName = "تلقائي",
                    .DisplayText = "🔄 تلقائي (الافتراضي: حساب البوابة / حساب العميل في الفاتورة)"
                })

                Dim list = _integrationService.GetTransactionalAccounts()
                For Each acc In list
                    AvailableAccounts.Add(New GatewayAccountOption With {
                        .AccountID = acc.AccountID,
                        .AccountCode = acc.AccountCode,
                        .AccountName = acc.AccountName,
                        .DisplayText = $"{acc.AccountCode}  —  {acc.AccountName}"
                    })
                Next
                NotifyAccountSelectionsChanged()
            Catch
            End Try
        End Sub

        Public Sub LoadEnabledProviders()
            Try
                Dim currentCode As String = SelectedProvider?.ProviderCode
                EnabledProviders.Clear()

                Dim list = _integrationService.GetProviders(onlyEnabled:=True)
                For Each item In list
                    EnabledProviders.Add(item)
                Next

                OnPropertyChanged(NameOf(HasNoEnabledProviders))

                If EnabledProviders.Count > 0 Then
                    SelectedProvider = If(
                        EnabledProviders.FirstOrDefault(Function(p) String.Equals(p.ProviderCode, currentCode, StringComparison.OrdinalIgnoreCase)),
                        EnabledProviders.First()
                    )
                    GuidanceMessageAr = If(SelectedProvider.IsConnectionVerified,
                                           SelectedProvider.StatusMessageAr,
                                           $"أدخل بيانات الربط الخاصة بـ ({SelectedProvider.ProviderNameAr}) ثم اضغط (🔌 اختبار الاتصال الفوري) لتفعيل الحفظ.")
                Else
                    SelectedProvider = Nothing
                    GuidanceMessageAr = "لا توجد بوابات مفعلة حالياً في إعدادات الشركة (CompanySettings). يرجى تفعيل البوابات المطلوبة أولاً."
                End If
            Catch ex As Exception
                GuidanceMessageAr = "حدث خطأ أثناء تحميل البوابات: " & ex.Message
            End Try
        End Sub

        Private Sub ExecuteRefreshProviders(obj As Object)
            LoadAvailableAccounts()
            LoadEnabledProviders()
        End Sub

        Private Sub ExecuteSetSandboxMode(obj As Object)
            If SelectedProvider Is Nothing Then Return
            SelectedProvider.EnvironmentMode = "Sandbox"
            SelectedProvider.ConnectionStatus = "Disconnected"
            Select Case SelectedProvider.ProviderCode.ToUpperInvariant()
                Case "TAP"
                    SelectedProvider.BaseUrl = "https://api.tap.company/v2"
                Case "MYFATOORAH"
                    SelectedProvider.BaseUrl = "https://apitest.myfatoorah.com"
                Case "UPAYMENTS"
                    SelectedProvider.BaseUrl = "https://sandboxapi.upayments.com/api/v1"
                Case "TALABAT"
                    SelectedProvider.BaseUrl = "https://integration-middleware.stg.restaurant-partners.com"
            End Select
            GuidanceMessageAr = "🟡 تم التبديل إلى بيئة الاختبار (Sandbox). يرجى الضغط على (🔌 اختبار الاتصال) للتحقق قبل الحفظ."
            NotifyProviderStateChanged()
        End Sub

        Private Sub ExecuteSetLiveMode(obj As Object)
            If SelectedProvider Is Nothing Then Return
            SelectedProvider.EnvironmentMode = "Live"
            SelectedProvider.ConnectionStatus = "Disconnected"
            Select Case SelectedProvider.ProviderCode.ToUpperInvariant()
                Case "TAP"
                    SelectedProvider.BaseUrl = "https://api.tap.company/v2"
                Case "MYFATOORAH"
                    SelectedProvider.BaseUrl = "https://api.myfatoorah.com"
                Case "UPAYMENTS"
                    SelectedProvider.BaseUrl = "https://uapi.upayments.com/api/v1"
                Case "TALABAT"
                    SelectedProvider.BaseUrl = "https://integration-middleware.restaurant-partners.com"
            End Select
            GuidanceMessageAr = "🟢 تم التبديل إلى البيئة الفعلية (Live). يرجى الضغط على (🔌 اختبار الاتصال) للتحقق قبل الحفظ."
            NotifyProviderStateChanged()
        End Sub

        Private Async Sub ExecuteTestConnection(obj As Object)
            If SelectedProvider Is Nothing OrElse IsBusy Then Return

            Try
                IsBusy = True
                GuidanceMessageAr = $"⏳ جاري اختبار الاتصال الفعلي مع خوادم {SelectedProvider.ProviderNameAr}..."
                NotifyProviderStateChanged()

                Dim result As ConnectionTestResult = Await _integrationService.TestProviderConnectionAsync(SelectedProvider)
                SelectedProvider.ConnectionStatus = result.VerifiedStatus
                SelectedProvider.StatusMessageAr = result.MessageAr
                SelectedProvider.LastTestedAt = DateTime.Now

                GuidanceMessageAr = result.MessageAr & Environment.NewLine & "💡 الخطوة التالية: " & result.NextStepGuidanceAr
            Catch ex As Exception
                SelectedProvider.ConnectionStatus = "Error"
                SelectedProvider.StatusMessageAr = "❌ خطأ أثناء الاختبار: " & ex.Message
                GuidanceMessageAr = SelectedProvider.StatusMessageAr
            Finally
                IsBusy = False
                NotifyProviderStateChanged()
            End Try
        End Sub

        Private Sub ExecuteSaveProviderConfig(obj As Object)
            If SelectedProvider Is Nothing Then Return

            If Not SelectedProvider.IsConnectionVerified Then
                MessageBox.Show(
                    "لا يمكن حفظ الإعدادات وتنفيذ ما يترتب عليها إلا بعد نجاح اختبار الاتصال (🔌 اختبار الاتصال الفوري) أولاً!",
                    "اختبار الاتصال إلزامي قبل الحفظ",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning
                )
                Return
            End If

            Try
                IsBusy = True
                Dim saved = _integrationService.SaveProviderConfiguration(SelectedProvider)
                LoadEnabledProviders()

                Dim extraMsg As String = If(saved.IsDeliveryPlatform,
                    "تم إنشاء وربط عميل المبيعات (Talabat) في شجرة الحسابات وتفعيل شاشة طلبات Talabat في قسم المبيعات وتطبيق الكاشير.",
                    "تم إنشاء وربط الحساب الفرعي للبوابة في شجرة الحسابات وتفعيل إصدار روابط الدفع ورموز QR.")

                GuidanceMessageAr = $"✅ تم حفظ إعدادات ({saved.ProviderNameAr}) بنجاح! {extraMsg}"
                LoadAvailableAccounts()
                MessageBox.Show(GuidanceMessageAr, "تم الحفظ والتفعيل بنجاح", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                Helpers.SnackbarService.ShowError(ex, "تعذر حفظ إعدادات البوابة")
            Finally
                IsBusy = False
                NotifyProviderStateChanged()
            End Try
        End Sub

        Private Sub ExecuteDisconnectProvider(obj As Object)
            If SelectedProvider Is Nothing OrElse IsBusy Then Return

            Dim confirm = MessageBox.Show(
                $"هل أنت متأكد من فصل الاتصال ببوابة ({SelectedProvider.ProviderNameAr}) وإيقاف تفعيلها حالياً؟" & Environment.NewLine &
                "لن يتمكن النظام من إصدار روابط دفع أو استقبال طلبات عبر هذه البوابة حتى يتم اختبار الاتصال وحفظ الإعدادات مجدداً.",
                "تأكيد فصل الاتصال بالبوابة",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question
            )
            If confirm <> MessageBoxResult.Yes Then Return

            Try
                IsBusy = True
                Dim provName As String = SelectedProvider.ProviderNameAr
                _integrationService.DisconnectProvider(SelectedProvider.ProviderID)
                LoadEnabledProviders()
                GuidanceMessageAr = $"⚪ تم فصل الاتصال ببوابة ({provName}) وإيقاف تفعيلها بنجاح."
                MessageBox.Show(GuidanceMessageAr, "تم فصل الاتصال", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                Helpers.SnackbarService.ShowError(ex, "تعذر فصل الاتصال بالبوابة")
            Finally
                IsBusy = False
                NotifyProviderStateChanged()
            End Try
        End Sub

        Private Sub NotifyProviderStateChanged()
            OnPropertyChanged(NameOf(SelectedProvider))
            OnPropertyChanged(NameOf(CanSaveConfig))
            OnPropertyChanged(NameOf(CanDisconnectProvider))
            OnPropertyChanged(NameOf(ConnectionStatusBadge))
            OnPropertyChanged(NameOf(LinkedEntitySummary))
        End Sub

    End Class

End Namespace

