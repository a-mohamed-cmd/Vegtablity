Imports System.Windows.Data
Imports System.Globalization
Imports System.Windows.Media
Imports System.Windows

Namespace Helpers
    Public Class BooleanToBrushConverter
        Implements IValueConverter

        Public Property TrueBrush As Brush
        Public Property FalseBrush As Brush

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If TypeOf value Is Boolean Then
                Return If(DirectCast(value, Boolean), TrueBrush, FalseBrush)
            End If
            Return FalseBrush
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class

    Public Class BooleanToTextConverter
        Implements IValueConverter

        Public Property TrueText As String
        Public Property FalseText As String

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If TypeOf value Is Boolean Then
                Return If(DirectCast(value, Boolean), TrueText, FalseText)
            End If
            Return FalseText
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class
    Public Class BooleanToVisibilityConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If TypeOf value Is Boolean Then
                Return If(DirectCast(value, Boolean), Visibility.Visible, Visibility.Collapsed)
            End If
            Return Visibility.Collapsed
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            If TypeOf value Is Visibility Then
                Return DirectCast(value, Visibility) = Visibility.Visible
            End If
            Return False
        End Function
    End Class
End Namespace
