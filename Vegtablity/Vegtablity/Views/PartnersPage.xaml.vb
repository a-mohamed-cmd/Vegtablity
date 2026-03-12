Imports System.Windows

Namespace Views
    Partial Public Class PartnersPage
        Inherits System.Windows.Controls.UserControl

        Private _vm As ViewModels.PartnersViewModel

        Private Sub PartnersPage_Loaded(sender As Object, e As RoutedEventArgs) Handles Me.Loaded
            _vm = TryCast(Me.DataContext, ViewModels.PartnersViewModel)
            If _vm IsNot Nothing Then
                AddHandler _vm.RequestNavigateToQuote, AddressOf OnNavigateToQuote
            End If
        End Sub

        Private Sub PartnersPage_Unloaded(sender As Object, e As RoutedEventArgs) Handles Me.Unloaded
            If _vm IsNot Nothing Then
                RemoveHandler _vm.RequestNavigateToQuote, AddressOf OnNavigateToQuote
            End If
        End Sub

        ''' <summary>
        ''' Called by the ViewModel when the user clicks "فتح تفاصيل العرض".
        ''' Navigates to QuotePage and loads the selected quote.
        ''' </summary>
        Private Sub OnNavigateToQuote(selectedQuote As Models.QuoteHeader)
            ' Find the parent DashboardWindow
            Dim dashWin = TryCast(Window.GetWindow(Me), DashboardWindow)
            If dashWin Is Nothing Then Return

            ' Create a new QuotePage and pass the quote for editing
            Dim quotePage As New QuotePage()
            Dim quoteVm = TryCast(quotePage.DataContext, ViewModels.QuoteViewModel)

            ' Close the side panel
            If _vm IsNot Nothing Then _vm.IsQuotesPanelOpen = False

            ' Navigate first
            dashWin.NavigateTo(quotePage, keepCurrentInStack:=True)

            ' Then load the quote (after navigation so VM is ready)
            If quoteVm IsNot Nothing Then
                quoteVm.LoadQuoteForEditing(selectedQuote)
            End If
        End Sub
    End Class
End Namespace
