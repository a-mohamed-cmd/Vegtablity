Imports System
Imports System.Windows
Imports Vegtablity.Controls
Imports Vegtablity.ViewModels.Integrations

Namespace Views
    Partial Public Class IntegrationSettingsPage
        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub AccountDropdown_SearchChanged(sender As Object, searchText As String)
            Dim dd = TryCast(sender, SearchableDropdown)
            Dim vm = TryCast(Me.DataContext, IntegrationSettingsViewModel)
            If dd Is Nothing OrElse vm Is Nothing Then Return

            dd.ItemsSource = vm.GetFilteredAccounts(searchText, dd.Name)
        End Sub

        Private Sub AccountDropdown_ItemSelected(sender As Object, selectedItem As Object)
            Dim dd = TryCast(sender, SearchableDropdown)
            Dim vm = TryCast(Me.DataContext, IntegrationSettingsViewModel)
            If dd Is Nothing OrElse vm Is Nothing Then Return

            ' إعادة قائمة الحسابات المطابقة للقائمة المحددة بعد الاختيار
            dd.ItemsSource = vm.GetAccountsCollectionForDropdown(dd.Name)
        End Sub
    End Class
End Namespace

