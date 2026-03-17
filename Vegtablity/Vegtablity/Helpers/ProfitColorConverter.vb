Imports System.Windows.Data
Imports System.Windows.Media
Imports System.Globalization

Namespace Helpers
    Public Class ProfitColorConverter
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.Convert
            If value IsNot Nothing AndAlso IsNumeric(value) Then
                Dim val As Decimal = System.Convert.ToDecimal(value)
                If val < 0 Then
                    Return New SolidColorBrush(Colors.Red)
                Else
                    Return New SolidColorBrush(Color.FromRgb(16, 185, 129)) ' #10B981 (Green)
                End If
            End If
            Return New SolidColorBrush(Colors.Black)
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function
    End Class
End Namespace
