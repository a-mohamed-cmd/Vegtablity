Imports System
Imports System.Collections.Generic

Namespace Models
    Public Class PartnerQuoteSummaryItem
        Public Property QuoteID As Integer
        Public Property QuoteTitle As String
        Public Property QuoteDate As DateTime
        Public Property QuoteDateFormatted As String
        Public Property IsActive As Boolean = True
        Public Property RawQuote As Object
        Public Property PartnerType As String ' Customer / Supplier
    End Class

    Public Class Partner
        Public Property PartnerID As Integer
        Public Property PartnerName As String
        Public Property PartnerType As String          ' Supplier / Customer
        Public Property Phone As String
        Public Property Address As String
        Public Property CurrentBalance As Decimal
        Public Property IsActive As Boolean = True
        Public Property AccountID As Integer?
        Public Property AccountCode As String          ' رقم الحساب المحاسبي

        ' ===== Quotes & Offers Properties =====
        Public Property QuotesCount As Integer = 0
        Public Property LatestQuote As Object
        Public Property QuotesList As List(Of Object)
        Public Property DisplayQuotes As List(Of PartnerQuoteSummaryItem) = New List(Of PartnerQuoteSummaryItem)()

        Public ReadOnly Property HasQuotes As Boolean
            Get
                Return QuotesCount > 0 OrElse (DisplayQuotes IsNot Nothing AndAlso DisplayQuotes.Count > 0)
            End Get
        End Property

        Public ReadOnly Property HasNoQuotes As Boolean
            Get
                Return Not HasQuotes
            End Get
        End Property

        Public ReadOnly Property QuotesButtonText As String
            Get
                If QuotesCount > 1 Then
                    Return $"📋 عروض الأسعار ({QuotesCount})"
                ElseIf QuotesCount = 1 Then
                    Return "📋 عرض السعر"
                Else
                    Return "⚪ لا توجد عروض أسعار"
                End If
            End Get
        End Property

        Public ReadOnly Property PhoneDisplay As String
            Get
                Return If(String.IsNullOrWhiteSpace(Phone), "غير مسجل", Phone)
            End Get
        End Property

        Public ReadOnly Property AddressDisplay As String
            Get
                Return If(String.IsNullOrWhiteSpace(Address), "غير مسجل", Address)
            End Get
        End Property

        Public ReadOnly Property TypeBadgeText As String
            Get
                Return If(PartnerType = "Supplier", "🏭 مورد", "👤 عميل")
            End Get
        End Property

        ''' <summary>النص المعروض في قائمة البحث: (م) اسم المورد [كود] أو (ع) اسم العميل [كود]</summary>
        Public ReadOnly Property SearchText As String
            Get
                Dim typeLabel = If(PartnerType = "Supplier", "(م)", "(ع)")
                Dim code = If(String.IsNullOrEmpty(AccountCode), "", $" [{AccountCode}]")
                Return $"{typeLabel} {PartnerName}{code}"
            End Get
        End Property
    End Class
End Namespace
