Namespace Helpers
    Public Class NullToVisibilityConverter
        Inherits Markup.MarkupExtension
        Implements IValueConverter

        Public Function Convert(value As Object, targetType As Type, parameter As Object, culture As Globalization.CultureInfo) As Object Implements IValueConverter.Convert
            If value Is Nothing Then Return Visibility.Visible
            If TypeOf value Is Byte() AndAlso DirectCast(value, Byte()).Length = 0 Then Return Visibility.Visible
            Return Visibility.Collapsed
        End Function

        Public Function ConvertBack(value As Object, targetType As Type, parameter As Object, culture As Globalization.CultureInfo) As Object Implements IValueConverter.ConvertBack
            Throw New NotImplementedException()
        End Function

        Public Overrides Function ProvideValue(serviceProvider As IServiceProvider) As Object
            Return Me
        End Function
    End Class
End Namespace
