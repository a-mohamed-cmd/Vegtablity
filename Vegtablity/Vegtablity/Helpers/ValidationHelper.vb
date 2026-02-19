Imports System.Collections.Generic
Imports System.Text.RegularExpressions

Namespace Helpers
    ''' <summary>
    ''' كلاس عام للتحقق من صحة المدخلات - يمكن استخدامه في جميع الصفحات
    ''' </summary>
    Public NotInheritable Class ValidationHelper

        Private Sub New()
        End Sub

        ''' <summary>
        ''' نتيجة التحقق
        ''' </summary>
        Public Class ValidationResult
            Public Property IsValid As Boolean
            Public Property Errors As List(Of String)

            Public Sub New()
                IsValid = True
                Errors = New List(Of String)()
            End Sub

            Public Sub AddError(message As String)
                IsValid = False
                Errors.Add(message)
            End Sub

            ''' <summary>
            ''' إرجاع جميع الأخطاء كنص واحد
            ''' </summary>
            Public Function GetErrorMessage() As String
                Return String.Join(Environment.NewLine, Errors)
            End Function
        End Class

        ' =============================================
        ' التحقق من النصوص
        ' =============================================

        ''' <summary>
        ''' التحقق من أن الحقل غير فارغ
        ''' </summary>
        Public Shared Function IsRequired(value As String, fieldName As String) As String
            If String.IsNullOrWhiteSpace(value) Then
                Return fieldName & " مطلوب."
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من الحد الأدنى للطول
        ''' </summary>
        Public Shared Function MinLength(value As String, minLen As Integer, fieldName As String) As String
            If Not String.IsNullOrEmpty(value) AndAlso value.Length < minLen Then
                Return fieldName & " يجب أن يكون " & minLen.ToString() & " أحرف على الأقل."
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من الحد الأقصى للطول
        ''' </summary>
        Public Shared Function MaxLength(value As String, maxLen As Integer, fieldName As String) As String
            If Not String.IsNullOrEmpty(value) AndAlso value.Length > maxLen Then
                Return fieldName & " يجب ألا يتجاوز " & maxLen.ToString() & " حرف."
            End If
            Return Nothing
        End Function

        ' =============================================
        ' التحقق من الأرقام
        ' =============================================

        ''' <summary>
        ''' التحقق من أن القيمة رقم صحيح
        ''' </summary>
        Public Shared Function IsInteger(value As String, fieldName As String) As String
            Dim result As Integer
            If Not String.IsNullOrEmpty(value) AndAlso Not Integer.TryParse(value, result) Then
                Return fieldName & " يجب أن يكون رقم صحيح."
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من أن القيمة رقم عشري
        ''' </summary>
        Public Shared Function IsDecimal(value As String, fieldName As String) As String
            Dim result As Decimal
            If Not String.IsNullOrEmpty(value) AndAlso Not Decimal.TryParse(value, result) Then
                Return fieldName & " يجب أن يكون رقم."
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من أن الرقم أكبر من صفر
        ''' </summary>
        Public Shared Function IsPositive(value As Decimal, fieldName As String) As String
            If value <= 0 Then
                Return fieldName & " يجب أن يكون أكبر من صفر."
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من النطاق
        ''' </summary>
        Public Shared Function InRange(value As Decimal, minVal As Decimal, maxVal As Decimal, fieldName As String) As String
            If value < minVal OrElse value > maxVal Then
                Return fieldName & " يجب أن يكون بين " & minVal.ToString() & " و " & maxVal.ToString() & "."
            End If
            Return Nothing
        End Function

        ' =============================================
        ' التحقق من البريد والهاتف
        ' =============================================

        ''' <summary>
        ''' التحقق من صحة البريد الإلكتروني
        ''' </summary>
        Public Shared Function IsValidEmail(value As String, fieldName As String) As String
            If Not String.IsNullOrEmpty(value) Then
                Dim pattern As String = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
                If Not Regex.IsMatch(value, pattern) Then
                    Return fieldName & " غير صالح."
                End If
            End If
            Return Nothing
        End Function

        ''' <summary>
        ''' التحقق من صحة رقم الهاتف (الكويت: 8 أرقام)
        ''' </summary>
        Public Shared Function IsValidPhone(value As String, fieldName As String) As String
            If Not String.IsNullOrEmpty(value) Then
                Dim cleanPhone As String = Regex.Replace(value, "[^0-9]", "")
                If cleanPhone.Length < 8 Then
                    Return fieldName & " يجب أن يكون 8 أرقام على الأقل."
                End If
            End If
            Return Nothing
        End Function

        ' =============================================
        ' التحقق من ComboBox / القوائم
        ' =============================================

        ''' <summary>
        ''' التحقق من اختيار عنصر من القائمة
        ''' </summary>
        Public Shared Function IsSelected(value As Integer, fieldName As String) As String
            If value <= 0 Then
                Return "يرجى اختيار " & fieldName & "."
            End If
            Return Nothing
        End Function

        ' =============================================
        ' تنفيذ مجموعة تحققات معاً
        ' =============================================

        ''' <summary>
        ''' تشغيل عدة تحققات دفعة واحدة وإرجاع النتيجة
        ''' </summary>
        Public Shared Function Validate(ParamArray errors() As String) As ValidationResult
            Dim result As New ValidationResult()
            For Each err As String In errors
                If err IsNot Nothing Then
                    result.AddError(err)
                End If
            Next
            Return result
        End Function

    End Class
End Namespace
