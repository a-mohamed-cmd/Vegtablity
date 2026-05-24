Imports System.Windows

Namespace Views
    Partial Public Class PartnersPage
        Inherits System.Windows.Controls.UserControl

        Private _vm As ViewModels.PartnersViewModel

        Private Sub PartnersPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            _vm = TryCast(Me.DataContext, ViewModels.PartnersViewModel)
            If _vm IsNot Nothing Then
                AddHandler _vm.RequestNavigateToQuote, AddressOf OnNavigateToQuote
                AddHandler _vm.RequestNavigateToPurchaseQuote, AddressOf OnNavigateToPurchaseQuote
            End If
        End Sub

        Private Sub PartnersPage_Unloaded(sender As Object, e As RoutedEventArgs) Handles Me.Unloaded
            If _vm IsNot Nothing Then
                RemoveHandler _vm.RequestNavigateToQuote, AddressOf OnNavigateToQuote
                RemoveHandler _vm.RequestNavigateToPurchaseQuote, AddressOf OnNavigateToPurchaseQuote
            End If
        End Sub

        ''' <summary>
        ''' Called by the ViewModel when the user clicks "فتح تفاصيل العرض" for Customers.
        ''' </summary>
        Private Sub OnNavigateToQuote(selectedQuote As Models.QuoteHeader)
            Dim dashWin = TryCast(Window.GetWindow(Me), DashboardWindow)
            If dashWin Is Nothing Then Return

            Dim quotePage As New QuotePage()
            Dim quoteVm = TryCast(quotePage.DataContext, ViewModels.QuoteViewModel)

            If _vm IsNot Nothing Then _vm.IsQuotesPanelOpen = False

            dashWin.NavigateTo(quotePage, keepCurrentInStack:=True)

            If quoteVm IsNot Nothing Then
                quoteVm.LoadQuoteForEditing(selectedQuote)
            End If
        End Sub

        ''' <summary>
        ''' Called by the ViewModel when the user clicks "فتح تفاصيل العرض" for Suppliers.
        ''' </summary>
        Private Sub OnNavigateToPurchaseQuote(selectedQuote As Models.PurchaseQuoteHeader)
            Dim dashWin = TryCast(Window.GetWindow(Me), DashboardWindow)
            If dashWin Is Nothing Then Return

            ' Navigate to PurchaseQuotePage
            Dim pQuotePage As New PurchaseQuotePage()
            Dim pQuoteVm = TryCast(pQuotePage.DataContext, ViewModels.PurchaseQuoteViewModel)

            ' Close side panel
            If _vm IsNot Nothing Then _vm.IsSupplierQuotesPanelOpen = False

            ' Navigate
            dashWin.NavigateTo(pQuotePage, keepCurrentInStack:=True)

            ' Load the selected quote
            If pQuoteVm IsNot Nothing Then
                pQuoteVm.EditQuoteCommand.Execute(selectedQuote)
            End If
        End Sub
    End Class
End Namespace
