Namespace Models
    Public Class CompanyInfo
        Public Property CompanyName As String
        Public Property Address As String
        Public Property Phone As String
        Public Property Email As String
        Public Property Logo As Byte()
        Public Property CurrencySymbol As String
        Public Property UnifiedPartnerSearch As Boolean = True
        Public Property UseDetailedInvoiceDesign As Boolean = False
        Public Property UseCustomInvoiceDesign As Boolean = False
        Public Property ProductionMode As Boolean = False
        Public Property EnableDailyOrders As Boolean = False
        Public Property DeliverySystemMode As String = Nothing
        Public Property EnableSalesDiscounts As Boolean = False
        Public Property EnableHR As Boolean = False

        ' === Integration Feature Flags ===
        Public Property EnableTapIntegration As Boolean = False
        Public Property EnableMyFatoorahIntegration As Boolean = False
        Public Property EnableUPaymentsIntegration As Boolean = False
        Public Property EnableTalabatIntegration As Boolean = False
        Public Property EnableJahezIntegration As Boolean = False
        Public Property PromptSendPaymentLinkOnSave As Boolean = False

        Public ReadOnly Property HasAnyIntegrationEnabled As Boolean
            Get
                Return EnableTapIntegration OrElse EnableMyFatoorahIntegration OrElse EnableUPaymentsIntegration OrElse EnableTalabatIntegration OrElse EnableJahezIntegration
            End Get
        End Property
    End Class
End Namespace
