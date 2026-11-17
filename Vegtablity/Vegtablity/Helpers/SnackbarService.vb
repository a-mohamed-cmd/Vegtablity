Imports System
Imports System.Windows

Namespace Helpers
    Public Enum SnackbarSeverity
        Success
        Warning
        [Error]
    End Enum

    ''' <summary>
    ''' خدمة عرض الإشعارات المنبثقة السفلية (SnapMessage / Snackbar) على مستوى التطبيق بالكامل
    ''' </summary>
    Public NotInheritable Class SnackbarService
        Private Sub New()
        End Sub

        Public Shared Event SnackbarRequested As Action(Of String, SnackbarSeverity)

        Public Shared Sub ShowSuccess(message As String)
            Dispatch(message, SnackbarSeverity.Success)
        End Sub

        Public Shared Sub ShowWarning(message As String)
            Dispatch(message, SnackbarSeverity.Warning)
        End Sub

        Public Shared Sub ShowErrorMessage(message As String)
            Dispatch(message, SnackbarSeverity.[Error])
        End Sub

        Public Shared Sub ShowError(ex As Exception, Optional prefix As String = Nothing)
            Dim formatted = DatabaseErrorHelper.FormatError(ex, prefix)
            Dispatch(formatted, SnackbarSeverity.[Error])
        End Sub

        Private Shared Sub Dispatch(message As String, severity As SnackbarSeverity)
            If String.IsNullOrWhiteSpace(message) Then Return

            Dim app = Application.Current
            If app IsNot Nothing AndAlso app.Dispatcher IsNot Nothing Then
                app.Dispatcher.BeginInvoke(New Action(Sub()
                    RaiseOrFallback(message, severity)
                End Sub))
            Else
                RaiseOrFallback(message, severity)
            End If
        End Sub

        Private Shared Sub RaiseOrFallback(message As String, severity As SnackbarSeverity)
            If SnackbarRequestedEvent IsNot Nothing AndAlso SnackbarRequestedEvent.GetInvocationList().Length > 0 Then
                RaiseEvent SnackbarRequested(message, severity)
                Return
            End If

            ' Fallback فقط عند عدم وجود نافذة لوحة التحكم (مثل شاشة تسجيل الدخول أو الترخيص)
            Dim img = If(severity = SnackbarSeverity.[Error], MessageBoxImage.[Error],
                         If(severity = SnackbarSeverity.Warning, MessageBoxImage.Warning, MessageBoxImage.Information))
            Dim title = If(severity = SnackbarSeverity.[Error], "تنبيه خطأ",
                           If(severity = SnackbarSeverity.Warning, "تنبيه", "إشعار"))
            MessageBox.Show(message, title, MessageBoxButton.OK, img)
        End Sub
    End Class
End Namespace
