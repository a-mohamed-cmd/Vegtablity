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

            dd.ItemsSource = vm.GetFilteredAccounts(searchText)
        End Sub

        Private Sub AccountDropdown_ItemSelected(sender As Object, selectedItem As Object)
            Dim dd = TryCast(sender, SearchableDropdown)
            Dim vm = TryCast(Me.DataContext, IntegrationSettingsViewModel)
            If dd Is Nothing OrElse vm Is Nothing Then Return

            ' إعادة قائمة الحسابات الكاملة بعد الاختيار لتكون جاهزة عند فتح القائمة المنسدلة لاحقاً
            dd.ItemsSource = vm.AvailableAccounts
        End Sub
    End Class
End Namespace

