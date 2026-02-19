Imports System.Globalization
Imports System.Windows
Imports System.Windows.Data

Namespace Helpers
    ''' <summary>
    ''' Converts a non-empty string to Visible, and null/empty to Collapsed.
    ''' Used for showing/hiding inline validation error messages.
    ''' </summary>
    Public Class StringToVisibilityConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If value IsNot Nothing AndAlso TypeOf value Is String AndAlso Not String.IsNullOrEmpty(CStr(value)) Then
                Return Visibility.Visible
            End If
            Return Visibility.Collapsed
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class
End Namespace
