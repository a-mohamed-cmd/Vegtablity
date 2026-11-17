Imports System
Imports System.Data.SqlClient
Imports System.Reflection
Imports System.Text.RegularExpressions

Namespace Helpers
    ''' <summary>
    ''' محوّل استثناءات قاعدة البيانات (SqlException) والأخطاء التقنية إلى رسائل عربية واضحة ومفهومة للمستخدم
    ''' </summary>
    Public NotInheritable Class DatabaseErrorHelper
        Private Sub New()
        End Sub

        Private Shared ReadOnly _boilerplateRegex As New Regex(
            "(?:The statement has been terminated\.?|The transaction ended in the trigger\. The batch has been aborted\.?|تم إنهاء المعاملة في المشغل\.?|تم إيقاف الدفعة\.?)",
            RegexOptions.IgnoreCase Or RegexOptions.Compiled)

        ''' <summary>
        ''' استخراج وترجمة خطأ قاعدة البيانات أو الاستثناء إلى رسالة مفهومة للمستخدم
        ''' </summary>
        Public Shared Function FormatError(ex As Exception, Optional prefix As String = Nothing) As String
            If ex Is Nothing Then
                Return If(String.IsNullOrWhiteSpace(prefix), "حدث خطأ غير متوقع.", prefix.Trim())
            End If

            Dim sqlEx = FindSqlException(ex)
            Dim friendly As String

            If sqlEx IsNot Nothing Then
                friendly = TranslateSqlException(sqlEx)
            Else
                Dim root = UnwrapException(ex)
                If TypeOf root Is TimeoutException Then
                    friendly = "انتهت مهلة تنفيذ العملية مع قاعدة البيانات، يرجى المحاولة مرة أخرى."
                ElseIf TypeOf root Is System.IO.IOException Then
                    friendly = "تعذر الوصول إلى الملف المطلوب؛ تأكد من عدم فتحه في برنامج آخر."
                Else
                    friendly = CleanMessage(root.Message)
                End If
            End If

            If String.IsNullOrWhiteSpace(friendly) Then
                friendly = "حدث خطأ غير متوقع أثناء تنفيذ العملية."
            End If

            If Not String.IsNullOrWhiteSpace(prefix) Then
                Dim p = prefix.Trim().TrimEnd(":"c)
                If Not friendly.Contains(p) Then
                    Return $"{p}: {friendly}"
                End If
            End If

            Return friendly
        End Function

        Private Shared Function FindSqlException(ex As Exception) As SqlException
            Dim current As Exception = ex
            While current IsNot Nothing
                If TypeOf current Is SqlException Then
                    Return DirectCast(current, SqlException)
                End If
                If TypeOf current Is AggregateException Then
                    For Each inner In DirectCast(current, AggregateException).Flatten().InnerExceptions
                        Dim found = FindSqlException(inner)
                        If found IsNot Nothing Then Return found
                    Next
                End If
                current = current.InnerException
            End While
            Return Nothing
        End Function

        Private Shared Function UnwrapException(ex As Exception) As Exception
            Dim current As Exception = ex
            While current IsNot Nothing AndAlso current.InnerException IsNot Nothing AndAlso
                  (TypeOf current Is TargetInvocationException OrElse
                   TypeOf current Is AggregateException OrElse
                   current.Message.StartsWith("فشل حفظ الفاتورة بنظام XML", StringComparison.OrdinalIgnoreCase))
                current = current.InnerException
            End While
            Return If(current, ex)
        End Function

        Private Shared Function TranslateSqlException(sqlEx As SqlException) As String
            Dim msgLower = If(sqlEx.Message, "").ToLowerInvariant()

            ' اختيار أهم خطأ فعلي في مجموعة SqlError (تجنب رسائل المعاملة العامة مثل 3609 أو 3621 إذا سبقها خطأ مخصص)
            Dim primaryNum As Integer = sqlEx.Number
            Dim primaryMsg As String = sqlEx.Message

            For Each err As SqlError In sqlEx.Errors
                If err.Number >= 50000 Then
                    primaryNum = err.Number
                    primaryMsg = err.Message
                    Exit For
                ElseIf err.Number <> 3621 AndAlso err.Number <> 3609 AndAlso err.Number <> 0 Then
                    primaryNum = err.Number
                    primaryMsg = err.Message
                    Exit For
                End If
            Next

            Select Case primaryNum
                Case 53, 40, 2, 10060, 10061, 11001, 18456, 4060, -1
                    Return "تعذر الاتصال بخادم قاعدة البيانات، يرجى التأكد من الشبكة وتوافر السيرفر."
                Case -2
                    Return "انتهت مهلة تنفيذ العملية في قاعدة البيانات، يرجى المحاولة مرة أخرى."
                Case 1205
                    Return "قاعدة البيانات مشغولة حالياً بسبب عملية متزامنة، يرجى إعادة المحاولة بعد لحظة."
                Case 547
                    If msgLower.Contains("delete statement conflicted") OrElse msgLower.Contains("statement conflicted with the reference") Then
                        Return "لا يمكن حذف هذا السجل لأنه مرتبط ببيانات أو عمليات أخرى في النظام."
                    End If
                    Return "لا يمكن إتمام العملية لوجود بيانات مرجعية غير مطابقة أو مرتبطة بسجلات أخرى."
                Case 2627, 2601
                    Return "البيانات المدخلة مكررة وموجودة مسبقاً (مثل الكود أو الباركود أو اسم المستخدم). يرجى المراجعة."
                Case 515
                    Return "توجد حقول إلزامية لم يتم تعبئتها، يرجى التأكد من إدخال جميع البيانات المطلوبة."
                Case 2628, 8152
                    Return "النص المدخل أطول من الحد الأقصى المسموح به لهذا الحقل."
                Case 8114, 8115, 245, 242, 241, 220
                    Return "توجد قيمة رقمية أو تاريخ غير صالح أو يتجاوز الحد المسموح به."
                Case 229, 262
                    Return "لا تملك الصلاحية الكافية في قاعدة البيانات لتنفيذ هذا الإجراء."
                Case 2812, 208, 207
                    Return "بنية قاعدة البيانات بحاجة للتحديث لتنفيذ هذه العملية، يرجى مراجعة تحديثات قاعدة البيانات."
                Case Else
                    If primaryNum >= 50000 Then
                        Dim cleaned = CleanMessage(primaryMsg)
                        If Not String.IsNullOrWhiteSpace(cleaned) Then Return cleaned
                    End If
            End Select

            ' فحص نص الرسالة في حال كانت رسالة SQL معروفة برقم مختلف
            If msgLower.Contains("reference constraint") OrElse msgLower.Contains("foreign key constraint") Then
                Return "لا يمكن تنفيذ العملية لأن هذا السجل مرتبط ببيانات أو عمليات أخرى في النظام."
            End If
            If msgLower.Contains("duplicate key") OrElse msgLower.Contains("unique key") OrElse msgLower.Contains("primary key") Then
                Return "البيانات المدخلة مكررة وموجودة مسبقاً، يرجى المراجعة."
            End If
            If msgLower.Contains("timeout expired") Then
                Return "انتهت مهلة تنفيذ العملية في قاعدة البيانات، يرجى المحاولة مرة أخرى."
            End If

            Return CleanMessage(primaryMsg)
        End Function

        Private Shared Function CleanMessage(raw As String) As String
            If String.IsNullOrWhiteSpace(raw) Then Return ""
            Dim cleaned = _boilerplateRegex.Replace(raw, "")
            cleaned = Regex.Replace(cleaned, "\s{2,}", " ").Trim()
            Return cleaned
        End Function
    End Class
End Namespace
