Imports System

Namespace Models.HR
    Public Class CustomFieldDefinition
        Public Property FieldID As Integer
        Public Property FieldKey As String
        Public Property FieldNameAr As String
        Public Property FieldType As String = "Text" ' Text, Number, Date, Dropdown, File
        Public Property OptionsJson As String
        Public Property IsAlertable As Boolean = False
        Public Property AlertDaysBefore As Integer = 30
        Public Property IsRequired As Boolean = False
        Public Property SortOrder As Integer = 0
        Public Property IsActive As Boolean = True
        Public Property CreatedAt As DateTime = DateTime.Now

        Public ReadOnly Property FieldTypeIcon As String
            Get
                Select Case FieldType
                    Case "Date"
                        Return "📅"
                    Case "Text"
                        Return "📝"
                    Case "Number"
                        Return "🔢"
                    Case Else
                        Return "🧩"
                End Select
            End Get
        End Property

        Public ReadOnly Property FieldTypeDisplay As String
            Get
                Select Case FieldType
                    Case "Date"
                        Return "تاريخ"
                    Case "Text"
                        Return "نص"
                    Case "Number"
                        Return "رقم"
                    Case Else
                        Return FieldType
                End Select
            End Get
        End Property

        Public ReadOnly Property FieldTypeTooltip As String
            Get
                Select Case FieldType
                    Case "Date"
                        Return "نوع البيانات: تاريخ (Date) - يدعم التنبيهات المسبقة ومتابعة فترات الصلاحية والانتهاء"
                    Case "Text"
                        Return "نوع البيانات: نص (Text) - حقل كتابة حر لأي بيانات أو أرقام وثائق أو ملاحظات"
                    Case "Number"
                        Return "نوع البيانات: رقم (Number) - يقبل القيم الرقمية والأعداد الصحيحة أو العشرية"
                    Case Else
                        Return $"نوع البيانات: {FieldType}"
                End Select
            End Get
        End Property

        Public ReadOnly Property AlertDescription As String
            Get
                If IsAlertable Then
                    Return $"🔔 تنبيه مسبق: قبل {AlertDaysBefore} يوم"
                Else
                    Return "⚪ بدون تنبيه مسبق"
                End If
            End Get
        End Property

        Public ReadOnly Property StatusDescription As String
            Get
                Return If(IsActive, "✓ مفعل", "⏸️ معطل")
            End Get
        End Property
    End Class
End Namespace
