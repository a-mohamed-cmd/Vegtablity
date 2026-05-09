Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media.Animation
Imports Vegtablity.ViewModels

Namespace Views
    Public Class InvoiceDashboardPage

        Private ReadOnly Property VM As InvoiceDashboardViewModel
            Get
                Return TryCast(Me.DataContext, InvoiceDashboardViewModel)
            End Get
        End Property

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub Page_Loaded(sender As Object, e As RoutedEventArgs)
            ' Wire ViewModel events
            If VM IsNot Nothing Then
                AddHandler VM.RequestOpenInvoice, AddressOf OnRequestOpenInvoice
                AddHandler VM.RequestSnackbar, AddressOf ShowSnackbar
            End If

            ' Animate cards in - Disabled: Now hidden by default and controlled by ToggleStatsBtn
            ' AnimateCards()

            ' Animate payment panel when IsPaymentPanelOpen changes
            AddHandler VM.PropertyChanged, Sub(s, args)
                If args.PropertyName = "IsPaymentPanelOpen" AndAlso VM.IsPaymentPanelOpen Then
                    Dim sb = TryCast(Me.Resources("SlideInRight"), Storyboard)
                    sb?.Begin()
                End If
            End Sub
        End Sub

        ' ══════════════════════════════════════════════════
        '  Stats Cards Toggle (إخفاء / إظهار الإحصائيات)
        ' ══════════════════════════════════════════════════
        Private _statsVisible As Boolean = False

        Private Sub ToggleStatsBtn_Click(sender As Object, e As RoutedEventArgs)
            If _statsVisible Then
                ' Collapse
                Dim sb = TryCast(Me.Resources("CollapseStats"), Storyboard)
                If sb IsNot Nothing Then sb.Begin(Me)
            Else
                ' Expand
                StatsPanel.Visibility = Visibility.Visible
                Dim sb = TryCast(Me.Resources("ExpandStats"), Storyboard)
                If sb IsNot Nothing Then sb.Begin(Me)
                _statsVisible = True
                UpdateStatsBtnLabel()
            End If
        End Sub

        Private Sub CollapseStats_Completed(sender As Object, e As EventArgs)
            StatsPanel.Visibility = Visibility.Collapsed
            _statsVisible = False
            UpdateStatsBtnLabel()
        End Sub

        Private Sub UpdateStatsBtnLabel()
            Dim lbl = TryCast(ToggleStatsBtn.Template.FindName("StatsBtnLabel", ToggleStatsBtn), TextBlock)
            If lbl IsNot Nothing Then
                lbl.Text = If(_statsVisible, "إخفاء الإحصائيات", "إظهار الإحصائيات")
            End If
        End Sub

        ''' <summary>Staggered fade-in for the stats cards</summary>
        Private Sub AnimateCards()
            Dim sb = TryCast(Me.Resources("FadeIn"), Storyboard)
            If sb IsNot Nothing Then
                Storyboard.SetTarget(sb, CardsGrid)
                sb.Begin()
            End If
        End Sub

        ''' <summary>Navigate to the appropriate invoice page and load the selected invoice</summary>
        Private Sub OnRequestOpenInvoice(invID As Integer, invType As String)
            Dim parent = FindParentWindow()
            If parent Is Nothing Then Return

            If invType = "Sales" Then
                Dim page = New SalesInvoicePage()
                Dim vm = TryCast(page.DataContext, SalesInvoiceViewModel)
                vm?.LoadInvoice(invID)
                parent.NavigateTo(page, keepCurrentInStack:=True)
            Else
                Dim page = New PurchaseInvoicePage()
                Dim vm = TryCast(page.DataContext, PurchaseInvoiceViewModel)
                vm?.LoadInvoice(invID)
                parent.NavigateTo(page, keepCurrentInStack:=True)
            End If
        End Sub

        ''' <summary>Find the parent DashboardWindow</summary>
        Private Function FindParentWindow() As DashboardWindow
            Dim parent = Window.GetWindow(Me)
            Return TryCast(parent, DashboardWindow)
        End Function

        ' ── Filter buttons ──
        Private Sub FilterType_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing OrElse VM Is Nothing Then Return
            VM.FilterType = CStr(btn.Tag)
            ' Visual highlight
            BtnAll.Background = New System.Windows.Media.SolidColorBrush(If(VM.FilterType = "All", CType(System.Windows.Media.ColorConverter.ConvertFromString("#3B82F6"), System.Windows.Media.Color), CType(System.Windows.Media.ColorConverter.ConvertFromString("#64748B"), System.Windows.Media.Color)))
            BtnSales.Background = New System.Windows.Media.SolidColorBrush(If(VM.FilterType = "Sales", CType(System.Windows.Media.ColorConverter.ConvertFromString("#3B82F6"), System.Windows.Media.Color), CType(System.Windows.Media.ColorConverter.ConvertFromString("#64748B"), System.Windows.Media.Color)))
            BtnPurchase.Background = New System.Windows.Media.SolidColorBrush(If(VM.FilterType = "Purchase", CType(System.Windows.Media.ColorConverter.ConvertFromString("#3B82F6"), System.Windows.Media.Color), CType(System.Windows.Media.ColorConverter.ConvertFromString("#64748B"), System.Windows.Media.Color)))
        End Sub

        Private Sub FilterStatus_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing OrElse VM Is Nothing Then Return
            ' Toggle: if already same status, revert to All
            VM.FilterStatus = If(VM.FilterStatus = CStr(btn.Tag), "All", CStr(btn.Tag))
        End Sub

        ' ── Invoice actions ──
        Private Sub OpenInvoiceBtn_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn IsNot Nothing Then
                VM?.OpenInvoiceCommand.Execute(btn.Tag)
            End If
        End Sub

        Private Sub NewSalesInvoice_Click(sender As Object, e As RoutedEventArgs)
            Dim parent = FindParentWindow()
            If parent IsNot Nothing Then
                parent.NavigateTo(New SalesInvoicePage(), keepCurrentInStack:=True)
            End If
        End Sub

        Private Sub NewPurchaseInvoice_Click(sender As Object, e As RoutedEventArgs)
            Dim parent = FindParentWindow()
            If parent IsNot Nothing Then
                parent.NavigateTo(New PurchaseInvoicePage(), keepCurrentInStack:=True)
            End If
        End Sub

        Private Sub AddPaymentBtn_Click(sender As Object, e As RoutedEventArgs)
            Dim btn = TryCast(sender, Button)
            If btn IsNot Nothing Then
                VM?.ShowPaymentPanelCommand.Execute(btn.Tag)
            End If
        End Sub

        Private Sub ClosePaymentPanel_Click(sender As Object, e As RoutedEventArgs)
            VM?.ClosePaymentPanelCommand.Execute(Nothing)
        End Sub

        Private Sub Overlay_MouseDown(sender As Object, e As Input.MouseButtonEventArgs)
            VM?.ClosePaymentPanelCommand.Execute(Nothing)
        End Sub

        ' ── Row stagger animation ──
        Private Sub DgInvoices_LoadingRow(sender As Object, e As DataGridRowEventArgs)
            e.Row.Opacity = 0
            Dim delay = e.Row.GetIndex() * 30
            Dim anim = New DoubleAnimation(0, 1, New Duration(TimeSpan.FromMilliseconds(250)))
            anim.BeginTime = TimeSpan.FromMilliseconds(delay)
            e.Row.BeginAnimation(UIElement.OpacityProperty, anim)
        End Sub

        ' ── Snackbar ──
        Private Sub ShowSnackbar(message As String)
            SnackbarText.Text = message
            SnackbarBorder.Visibility = Visibility.Visible
            Dim timer = New System.Windows.Threading.DispatcherTimer()
            timer.Interval = TimeSpan.FromSeconds(3)
            AddHandler timer.Tick, Sub(s, ev)
                SnackbarBorder.Visibility = Visibility.Collapsed
                DirectCast(s, System.Windows.Threading.DispatcherTimer).Stop()
            End Sub
            timer.Start()
        End Sub

        ' ── Payment Amount: allow decimal numbers only ──
        Private Sub PaymentAmount_PreviewTextInput(sender As Object, e As Input.TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            ' Allow digits only, and a single decimal point
            Dim newText = tb.Text.Substring(0, tb.SelectionStart) &
                          e.Text &
                          tb.Text.Substring(tb.SelectionStart + tb.SelectionLength)

            Dim isValid = System.Text.RegularExpressions.Regex.IsMatch(newText, "^\d*\.?\d*$")
            e.Handled = Not isValid
        End Sub

        ''' <summary>Handle decimal point from Numpad or keyboard — works for all Windows locale settings.</summary>
        Private Sub PaymentAmount_PreviewKeyDown(sender As Object, e As Input.KeyEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            ' Key.Decimal = Numpad "." (may produce "," in Arabic locale)
            ' Key.OemPeriod = regular "." key
            ' Key.OemComma = "," key (Arabic locale numpad sends this instead of period)
            Dim isDecimalKey = (e.Key = Input.Key.OemPeriod OrElse
                                e.Key = Input.Key.Decimal OrElse
                                e.Key = Input.Key.OemComma)

            If isDecimalKey Then
                ' Always insert "." regardless of locale
                If Not tb.Text.Contains(".") Then
                    Dim pos = tb.SelectionStart
                    Dim current = tb.Text.Remove(pos, tb.SelectionLength)
                    tb.Text = current.Insert(pos, ".")
                    tb.SelectionStart = pos + 1
                End If
                e.Handled = True ' Block the key's default character
            End If
        End Sub

        Private Sub PaymentAmount_Pasting(sender As Object, e As System.Windows.DataObjectPastingEventArgs)
            If e.DataObject.GetDataPresent(GetType(String)) Then
                Dim pastedText = CStr(e.DataObject.GetData(GetType(String)))
                If Not System.Text.RegularExpressions.Regex.IsMatch(pastedText, "^\d*\.?\d*$") Then
                    e.CancelCommand()
                End If
            Else
                e.CancelCommand()
            End If
        End Sub
    End Class
End Namespace
