Imports System.Windows.Data
Imports System.Globalization

Namespace Helpers
    Public Class BooleanInverterConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If TypeOf value Is Boolean Then
                Return Not DirectCast(value, Boolean)
            End If
            Return value
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            If TypeOf value Is Boolean Then
                Return Not DirectCast(value, Boolean)
            End If
            Return value
        End Function
    End Class
End Namespace
