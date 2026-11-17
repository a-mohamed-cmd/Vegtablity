Imports System
Imports System.Collections.ObjectModel
Imports System.Linq
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Documents
Imports System.Windows.Media
Imports Vegtablity.Helpers
Imports Vegtablity.Models.Integrations
Imports Vegtablity.Services.Integrations

Namespace ViewModels.Sales

    ''' <summary>
    ''' ViewModel شاشة طلبات منصة Talabat (تحت قسم المبيعات)
    ''' يظهر ويعمل بعد تفعيل Talabat في إعدادات الشركة ونجاح اختبار الاتصال وحفظ الإعدادات
    ''' </summary>
    Public Class TalabatOrdersViewModel
        Inherits BaseViewModel

        Private ReadOnly _integrationService As New IntegrationManagerService()

        Public Property Orders As New ObservableCollection(Of TalabatOrderRecord)()

        Private _selectedOrder As TalabatOrderRecord
        Public Property SelectedOrder As TalabatOrderRecord
            Get
                Return _selectedOrder
            End Get
            Set(value As TalabatOrderRecord)
                _selectedOrder = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(HasSelectedOrder))
            End Set
        End Property

        Private _filterStatus As String = "ALL"
        Public Property FilterStatus As String
            Get
                Return _filterStatus
            End Get
            Set(value As String)
                _filterStatus = value
                OnPropertyChanged()
                LoadOrders()
            End Set
        End Property

        Private _searchText As String = ""
        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                _searchText = value
                OnPropertyChanged()
            End Set
        End Property

        Private _prepTimeMinutes As Integer = 15
        Public Property PrepTimeMinutes As Integer
            Get
                Return _prepTimeMinutes
            End Get
            Set(value As Integer)
                _prepTimeMinutes = value
                OnPropertyChanged()
            End Set
        End Property

        Private _rejectionReason As String = "ITEM_UNAVAILABLE"
        Public Property RejectionReason As String
            Get
                Return _rejectionReason
            End Get
            Set(value As String)
                _rejectionReason = value
                OnPropertyChanged()
            End Set
        End Property

        Private _isBranchOpenOnTalabat As Boolean = True
        Public Property IsBranchOpenOnTalabat As Boolean
            Get
                Return _isBranchOpenOnTalabat
            End Get
            Set(value As Boolean)
                _isBranchOpenOnTalabat = value
                OnPropertyChanged()
                OnPropertyChanged(NameOf(BranchStatusText))
            End Set
        End Property

        Public ReadOnly Property BranchStatusText As String
            Get
                Return If(IsBranchOpenOnTalabat, "🟢 الفرع مفتوح لاستقبال طلبات Talabat", "🔴 الفرع مغلق مؤقتاً على Talabat")
            End Get
        End Property

        Public ReadOnly Property HasSelectedOrder As Boolean
            Get
                Return SelectedOrder IsNot Nothing
            End Get
        End Property

        Public ReadOnly Property NewOrdersCount As Integer
            Get
                Return Orders.Where(Function(o) o.OrderStatus = "Received").Count()
            End Get
        End Property

        Public ReadOnly Property PreparingOrdersCount As Integer
            Get
                Return Orders.Where(Function(o) o.OrderStatus = "Accepted").Count()
            End Get
        End Property

        Public ReadOnly Property TotalTalabatSales As Decimal
            Get
                Return Orders.Where(Function(o) o.OrderStatus = "Accepted" OrElse o.OrderStatus = "Prepared").Sum(Function(o) o.GrandTotal)
            End Get
        End Property

        ' === Commands ===
        Public Property RefreshOrdersCommand As RelayCommand
        Public Property AcceptOrderCommand As RelayCommand
        Public Property RejectOrderCommand As RelayCommand
        Public Property MarkPreparedCommand As RelayCommand
        Public Property PrintOrderTicketCommand As RelayCommand
        Public Property ToggleBranchAvailabilityCommand As RelayCommand
        Public Property SimulateIncomingOrderCommand As RelayCommand

        Public Sub New()
            RefreshOrdersCommand = New RelayCommand(Sub(o) LoadOrders())
            AcceptOrderCommand = New RelayCommand(AddressOf ExecuteAcceptOrder)
            RejectOrderCommand = New RelayCommand(AddressOf ExecuteRejectOrder)
            MarkPreparedCommand = New RelayCommand(AddressOf ExecuteMarkPrepared)
            PrintOrderTicketCommand = New RelayCommand(AddressOf ExecutePrintOrderTicket)
            ToggleBranchAvailabilityCommand = New RelayCommand(AddressOf ExecuteToggleBranchAvailability)
            SimulateIncomingOrderCommand = New RelayCommand(AddressOf ExecuteSimulateIncomingOrder)

            LoadOrders()
        End Sub

        Public Sub LoadOrders()
            Try
                Orders.Clear()
                Dim list = _integrationService.GetTalabatOrders(status:=FilterStatus, searchText:=SearchText)
                For Each item In list
                    Orders.Add(item)
                Next
                If SelectedOrder Is Nothing AndAlso Orders.Count > 0 Then
                    SelectedOrder = Orders.First()
                End If
                OnPropertyChanged(NameOf(NewOrdersCount))
                OnPropertyChanged(NameOf(PreparingOrdersCount))
                OnPropertyChanged(NameOf(TotalTalabatSales))
            Catch
            End Try
        End Sub

        Private Async Sub ExecuteAcceptOrder(obj As Object)
            Dim target As TalabatOrderRecord = If(TryCast(obj, TalabatOrderRecord), SelectedOrder)
            If target Is Nothing Then Return

            Dim res = Await _integrationService.AcceptTalabatOrderAsync(target, PrepTimeMinutes)
            LoadOrders()
            If res.Success Then
                PrintThermalTicket(target)
                MessageBox.Show(res.MessageAr, "تم قبول الطلب وإصدار الفاتورة", MessageBoxButton.OK, MessageBoxImage.Information)
            Else
                Helpers.SnackbarService.ShowErrorMessage(res.MessageAr)
            End If
        End Sub

        Private Async Sub ExecuteRejectOrder(obj As Object)
            Dim target As TalabatOrderRecord = If(TryCast(obj, TalabatOrderRecord), SelectedOrder)
            If target Is Nothing Then Return

            If MessageBox.Show($"هل أنت متأكد من رفض طلب Talabat رقم #{target.OrderCode}؟", "تأكيد رفض الطلب", MessageBoxButton.YesNo, MessageBoxImage.Warning) <> MessageBoxResult.Yes Then
                Return
            End If

            Dim res = Await _integrationService.RejectTalabatOrderAsync(target, RejectionReason)
            LoadOrders()
            MessageBox.Show(res.MessageAr, "رفض الطلب", MessageBoxButton.OK, MessageBoxImage.Information)
        End Sub

        Private Async Sub ExecuteMarkPrepared(obj As Object)
            Dim target As TalabatOrderRecord = If(TryCast(obj, TalabatOrderRecord), SelectedOrder)
            If target Is Nothing Then Return

            Dim res = Await _integrationService.MarkTalabatOrderPreparedAsync(target)
            LoadOrders()
            MessageBox.Show(res.MessageAr, "جاهزية الطلب", MessageBoxButton.OK, MessageBoxImage.Information)
        End Sub

        Private Sub ExecutePrintOrderTicket(obj As Object)
            Dim target As TalabatOrderRecord = If(TryCast(obj, TalabatOrderRecord), SelectedOrder)
            If target Is Nothing Then Return
            PrintThermalTicket(target)
        End Sub

        Private Async Sub ExecuteToggleBranchAvailability(obj As Object)
            IsBranchOpenOnTalabat = Not IsBranchOpenOnTalabat
            Await _integrationService.SetTalabatBranchAvailabilityAsync(IsBranchOpenOnTalabat)
            MessageBox.Show(BranchStatusText, "حالة الفرع على Talabat", MessageBoxButton.OK, MessageBoxImage.Information)
        End Sub

        Private Sub ExecuteSimulateIncomingOrder(obj As Object)
            Try
                Dim rnd As New Random()
                Dim codeNum As Integer = rnd.Next(10000, 99999)
                Dim sample As New TalabatOrderRecord With {
                    .OrderToken = $"TLB_TOKEN_{codeNum}",
                    .OrderCode = $"TLB-{codeNum}",
                    .ShortCode = $"#{codeNum.ToString().Substring(2)}",
                    .RemoteVendorId = "BRANCH_MAIN",
                    .ExpeditionType = "delivery",
                    .PaymentType = "ONLINE",
                    .SubTotal = 12.5D,
                    .DeliveryFee = 1.0D,
                    .DiscountAmount = 0D,
                    .GrandTotal = 13.5D,
                    .CurrencyCode = "KWD",
                    .OrderStatus = "Received",
                    .CustomerName = "عميل طلبات (Talabat Customer)",
                    .CustomerPhone = "96550000000",
                    .DeliveryAddress = "الكويت - طلب توصيل عبر تطبيق Talabat",
                    .Comments = "يرجى تجهيز الطلب وتغليفه جيداً",
                    .ItemsJson = "[{""name"":""صندوق خضروات وفواكه مشكل"",""qty"":2,""price"":6.250}]"
                }
                _integrationService.SaveOrUpdateTalabatOrder(sample, autoCreateInvoice:=False)
                LoadOrders()
            Catch ex As Exception
                Helpers.SnackbarService.ShowError(ex, "تعذر محاكاة الطلب")
            End Try
        End Sub

        Private Sub PrintThermalTicket(order As TalabatOrderRecord)
            Try
                Dim doc As New FlowDocument() With {
                    .FlowDirection = FlowDirection.RightToLeft,
                    .FontFamily = New FontFamily("Cairo, Segoe UI, Arial"),
                    .PageWidth = 280,
                    .ColumnWidth = 280,
                    .PagePadding = New Thickness(12)
                }

                doc.Blocks.Add(New Paragraph(New Run($"🛵 طلب TALABAT رقم {order.OrderCode} ({order.ShortCode})")) With {
                    .FontSize = 15,
                    .FontWeight = FontWeights.Bold,
                    .TextAlignment = TextAlignment.Center
                })

                Dim details As New Paragraph() With {.FontSize = 12}
                details.Inlines.Add(New Run($"العميل: {order.CustomerName}" & Environment.NewLine))
                details.Inlines.Add(New Run($"الهاتف: {order.CustomerPhone}" & Environment.NewLine))
                details.Inlines.Add(New Run($"نوع التسليم: {order.ExpeditionType} | الدفع: {order.PaymentType}" & Environment.NewLine))
                details.Inlines.Add(New Run($"الإجمالي: {order.GrandTotal:N3} {order.CurrencyCode}" & Environment.NewLine) With {.FontWeight = FontWeights.Bold})
                If Not String.IsNullOrWhiteSpace(order.Comments) Then
                    details.Inlines.Add(New Run($"ملاحظات: {order.Comments}" & Environment.NewLine))
                End If
                If Not String.IsNullOrWhiteSpace(order.ItemsJson) Then
                    details.Inlines.Add(New Run($"الأصناف: {order.ItemsJson}"))
                End If
                doc.Blocks.Add(details)

                Dim dlg As New PrintDialog()
                If dlg.ShowDialog() = True Then
                    Dim paginator As IDocumentPaginatorSource = doc
                    dlg.PrintDocument(paginator.DocumentPaginator, $"TalabatOrder_{order.OrderCode}")
                End If
            Catch
            End Try
        End Sub

    End Class

End Namespace

