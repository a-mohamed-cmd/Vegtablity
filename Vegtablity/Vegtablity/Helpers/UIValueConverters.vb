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
    Public Class AccountingAmountConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If value Is Nothing OrElse Not IsNumeric(value) Then Return "0.000"

            Dim amount = System.Convert.ToDecimal(value)
            Dim format = "N3"

            If amount < 0 Then
                Return String.Format("({0})", Math.Abs(amount).ToString(format, culture))
            Else
                Return amount.ToString(format, culture)
            End If
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class

    Public Class DirToArrowConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            Dim dir As String = TryCast(value, String)
            If dir = "IN" Then Return "▼" ' سهم لأسفل (وارد)
            If dir = "OUT" Then Return "▲" ' سهم لأعلى (صادر)
            Return "-"
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class

    Public Class DirToColorConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            Dim dir As String = TryCast(value, String)
            If dir = "IN" Then Return New SolidColorBrush(Color.FromRgb(16, 185, 129)) ' Green #10B981
            If dir = "OUT" Then Return New SolidColorBrush(Color.FromRgb(239, 68, 68)) ' Red #EF4444
            Return New SolidColorBrush(Color.FromRgb(100, 116, 139)) ' Gray
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class
    Public Class PeriodToColorConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If value Is Nothing OrElse parameter Is Nothing Then Return New SolidColorBrush(Color.FromRgb(148, 163, 184)) ' Gray #94A3B8

            Dim selectedMonths As Integer
            Dim buttonMonths As Integer

            If Integer.TryParse(value.ToString(), selectedMonths) AndAlso Integer.TryParse(parameter.ToString(), buttonMonths) Then
                If selectedMonths = buttonMonths Then
                    Return New SolidColorBrush(Color.FromRgb(59, 130, 246)) ' Blue #3B82F6 (Selected)
                End If
            End If

            Return New SolidColorBrush(Color.FromRgb(148, 163, 184)) ' Gray #94A3B8 (Unselected)
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class

End Namespace
