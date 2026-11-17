Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Linq
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Vegtablity.Models.Integrations
Imports Vegtablity.Services.Integrations

Namespace Views.Integrations

    Public Partial Class SendPaymentLinkDialog
        Inherits Window

        Private ReadOnly _integrationService As New IntegrationManagerService()
        Private ReadOnly _invId As Integer
        Private ReadOnly _partnerId As Integer?
        Private ReadOnly _isPaidViaGateway As Boolean
        Private ReadOnly _preferredAccountId As Integer?
        Private _configuredGateways As List(Of IntegrationProviderConfig)
        Private _createdRecord As PaymentLinkRecord

        Public ReadOnly Property CreatedLinkRecord As PaymentLinkRecord
            Get
                Return _createdRecord
            End Get
        End Property

        Public Sub New(invId As Integer,
                       partnerId As Integer?,
                       customerName As String,
                       customerPhone As String,
                       amount As Decimal,
                       Optional isPaidViaGateway As Boolean = False,
                       Optional preferredAccountId As Integer? = Nothing)
            InitializeComponent()

            _invId = invId
            _partnerId = partnerId
            _isPaidViaGateway = isPaidViaGateway
            _preferredAccountId = preferredAccountId

            TxtInvoiceBadge.Text = $"فاتورة #{invId}"
            TxtAmount.Text = amount.ToString("0.000", CultureInfo.InvariantCulture)
            TxtCustomerName.Text = If(String.IsNullOrWhiteSpace(customerName), "عميل نقدي", customerName)
            TxtCustomerPhone.Text = If(customerPhone, "").Trim()

            If isPaidViaGateway Then
                TxtDialogTitle.Text = "💳 إصدار وإرسال رابط الدفع الإلكتروني للعميل"
                TxtDialogSubtitle.Text = "تم اختيار الدفع عبر البوابة الإلكترونية — جاري تجهيز رابط الدفع ورمز QR لإرساله للعميل."
            Else
                TxtDialogTitle.Text = "🔗 إرسال رابط دفع إلكتروني لتحصيل فاتورة آجل"
                TxtDialogSubtitle.Text = "الفاتورة محفوظة كـ (آجل) — يمكنك إصدار وإرسال رابط دفع إلكتروني للعميل لتحصيل المبلغ المتبقي."
            End If

            LoadGateways()
            AddHandler Me.Loaded, AddressOf OnDialogLoaded
        End Sub

        Private Sub LoadGateways()
            _configuredGateways = _integrationService.GetProviders(onlyEnabled:=True) _
                .Where(Function(p) p.IsPaymentGateway AndAlso (p.IsConfigured OrElse p.IsConnectionVerified)) _
                .ToList()

            CmbGateways.ItemsSource = _configuredGateways

            If _configuredGateways.Count > 0 Then
                Dim matched As IntegrationProviderConfig = Nothing
                If _preferredAccountId.HasValue Then
                    matched = _configuredGateways.FirstOrDefault(Function(g) g.LinkedAccountID.HasValue AndAlso g.LinkedAccountID.Value = _preferredAccountId.Value)
                End If
                If matched Is Nothing Then
                    matched = _configuredGateways.First()
                End If
                CmbGateways.SelectedItem = matched
                ApplyGatewayDefaults(matched)
            End If
        End Sub

        Private Sub CmbGateways_SelectionChanged(sender As Object, e As SelectionChangedEventArgs)
            Dim selected = TryCast(CmbGateways.SelectedItem, IntegrationProviderConfig)
            If selected IsNot Nothing Then
                ApplyGatewayDefaults(selected)
            End If
        End Sub

        Private Sub ApplyGatewayDefaults(cfg As IntegrationProviderConfig)
            If cfg Is Nothing Then Return
            ChkSendWhatsApp.IsChecked = cfg.AutoSendWhatsApp
            ChkPrint80mm.IsChecked = cfg.PrintQrOnPos80mm
            ChkPrint58mm.IsChecked = cfg.PrintQrOnPos58mm
            ChkPrintWpf.IsChecked = cfg.PrintQrOnWpfInvoice
        End Sub

        Private Async Sub OnDialogLoaded(sender As Object, e As RoutedEventArgs)
            ' إذا كانت الفاتورة مدفوعة مباشرة عبر البوابة، نقوم بإنشاء الرابط تلقائياً فور فتح النافذة
            If _isPaidViaGateway AndAlso _configuredGateways IsNot Nothing AndAlso _configuredGateways.Count > 0 Then
                Await CreateLinkInternalAsync()
            End If
        End Sub

        Private Async Sub BtnCreateAndSend_Click(sender As Object, e As RoutedEventArgs)
            Await CreateLinkInternalAsync()
        End Sub

        Private Async Function CreateLinkInternalAsync() As System.Threading.Tasks.Task
            Dim selectedGateway = TryCast(CmbGateways.SelectedItem, IntegrationProviderConfig)
            If selectedGateway Is Nothing Then
                ShowStatus("⚠️ لا توجد بوابة دفع مفعلة ومختبرة الاتصال حالياً.", isError:=True)
                Return
            End If

            Dim amt As Decimal = 0D
            If Not Decimal.TryParse(TxtAmount.Text.Trim(), NumberStyles.Any, CultureInfo.InvariantCulture, amt) OrElse amt <= 0D Then
                Decimal.TryParse(TxtAmount.Text.Trim(), amt)
            End If
            If amt <= 0D Then
                ShowStatus("⚠️ يرجى إدخال مبلغ صحيح أكبر من الصفر.", isError:=True)
                Return
            End If

            Try
                BtnCreateAndSend.IsEnabled = False
                BtnCreateAndSend.Content = "⏳ جاري الاتصال بالبوابة وتوليد الرابط..."
                ShowStatus($"⏳ جاري إنشاء رابط الدفع عبر ({selectedGateway.ProviderNameAr})...", isError:=False)

                Dim userId As Integer = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 1)
                Dim req As New PaymentLinkRequest With {
                    .InvID = _invId,
                    .PartnerID = _partnerId,
                    .ProviderID = selectedGateway.ProviderID,
                    .ProviderCode = selectedGateway.ProviderCode,
                    .Amount = amt,
                    .CurrencyCode = If(String.IsNullOrWhiteSpace(selectedGateway.DefaultCurrency), "KWD", selectedGateway.DefaultCurrency),
                    .CustomerName = TxtCustomerName.Text.Trim(),
                    .CustomerPhone = TxtCustomerPhone.Text.Trim(),
                    .SendViaWhatsApp = (ChkSendWhatsApp.IsChecked = True),
                    .SendViaSms = selectedGateway.AutoSendSms,
                    .CreatedByUserID = userId,
                    .Description = $"فاتورة مبيعات رقم #{_invId}"
                }

                Dim res = Await _integrationService.CreateAndSavePaymentLinkAsync(selectedGateway, req)
                If res.Success AndAlso res.Record IsNot Nothing Then
                    _createdRecord = res.Record
                    TxtGeneratedUrl.Text = res.Record.PaymentUrl
                    ImgQrPreview.Source = _integrationService.QrService.GenerateQrBitmapImage(res.Record.PaymentUrl, "80mm")
                    ResultCard.Visibility = Visibility.Visible
                    ShowStatus(res.MessageAr, isError:=False, isSuccess:=True)
                    BtnCreateAndSend.Content = "🔄 إعادة توليد وإرسال رابط جديد"

                    ' تنفيذ خيارات الطباعة المحددة
                    If ChkPrint80mm.IsChecked = True Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(_invId, req.CustomerName, amt, req.CurrencyCode, selectedGateway.ProviderNameAr, res.Record.PaymentUrl, "80mm")
                    End If
                    If ChkPrint58mm.IsChecked = True Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(_invId, req.CustomerName, amt, req.CurrencyCode, selectedGateway.ProviderNameAr, res.Record.PaymentUrl, "58mm")
                    End If
                    If ChkPrintWpf.IsChecked = True Then
                        _integrationService.QrService.PrintPaymentLinkReceipt(_invId, req.CustomerName, amt, req.CurrencyCode, selectedGateway.ProviderNameAr, res.Record.PaymentUrl, "WPF")
                    End If
                Else
                    ShowStatus(res.MessageAr, isError:=True)
                    BtnCreateAndSend.Content = "🔗 إنشاء وإرسال رابط الدفع الآن"
                End If
            Catch ex As Exception
                ShowStatus("❌ خطأ غير متوقع: " & ex.Message, isError:=True)
                BtnCreateAndSend.Content = "🔗 إنشاء وإرسال رابط الدفع الآن"
            Finally
                BtnCreateAndSend.IsEnabled = True
            End Try
        End Function

        Private Sub ShowStatus(msg As String, Optional isError As Boolean = False, Optional isSuccess As Boolean = False)
            StatusBanner.Visibility = Visibility.Visible
            TxtStatusMessage.Text = msg
            If isError Then
                StatusBanner.Background = New SolidColorBrush(Color.FromRgb(254, 242, 242))
                StatusBanner.BorderBrush = New SolidColorBrush(Color.FromRgb(252, 165, 165))
                TxtStatusMessage.Foreground = New SolidColorBrush(Color.FromRgb(185, 28, 28))
            ElseIf isSuccess Then
                StatusBanner.Background = New SolidColorBrush(Color.FromRgb(240, 253, 244))
                StatusBanner.BorderBrush = New SolidColorBrush(Color.FromRgb(134, 239, 172))
                TxtStatusMessage.Foreground = New SolidColorBrush(Color.FromRgb(22, 101, 52))
            Else
                StatusBanner.Background = New SolidColorBrush(Color.FromRgb(239, 246, 255))
                StatusBanner.BorderBrush = New SolidColorBrush(Color.FromRgb(191, 219, 254))
                TxtStatusMessage.Foreground = New SolidColorBrush(Color.FromRgb(30, 64, 175))
            End If
        End Sub

        Private Sub BtnCopyUrl_Click(sender As Object, e As RoutedEventArgs)
            If Not String.IsNullOrWhiteSpace(TxtGeneratedUrl.Text) Then
                Clipboard.SetText(TxtGeneratedUrl.Text)
                ShowStatus("✅ تم نسخ رابط الدفع إلى الحافظة بنجاح.", isError:=False, isSuccess:=True)
            End If
        End Sub

        Private Sub BtnSendWhatsAppNow_Click(sender As Object, e As RoutedEventArgs)
            If _createdRecord Is Nothing OrElse String.IsNullOrWhiteSpace(TxtGeneratedUrl.Text) Then Return
            _integrationService.SendPaymentLinkViaWhatsApp(
                TxtCustomerPhone.Text.Trim(),
                TxtCustomerName.Text.Trim(),
                _invId,
                _createdRecord.Amount,
                _createdRecord.CurrencyCode,
                TxtGeneratedUrl.Text
            )
        End Sub

        Private Sub BtnPrintQrNow_Click(sender As Object, e As RoutedEventArgs)
            If _createdRecord Is Nothing OrElse String.IsNullOrWhiteSpace(TxtGeneratedUrl.Text) Then Return
            Dim selectedGateway = TryCast(CmbGateways.SelectedItem, IntegrationProviderConfig)
            Dim provName As String = If(selectedGateway IsNot Nothing, selectedGateway.ProviderNameAr, "بوابة الدفع")
            Dim mode As String = If(ChkPrint58mm.IsChecked = True, "58mm", If(ChkPrintWpf.IsChecked = True, "WPF", "80mm"))
            _integrationService.QrService.PrintPaymentLinkReceipt(
                _invId,
                TxtCustomerName.Text.Trim(),
                _createdRecord.Amount,
                _createdRecord.CurrencyCode,
                provName,
                TxtGeneratedUrl.Text,
                mode
            )
        End Sub

        Private Sub BtnClose_Click(sender As Object, e As RoutedEventArgs)
            Me.DialogResult = (_createdRecord IsNot Nothing)
            Me.Close()
        End Sub

    End Class

End Namespace

