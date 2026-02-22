Imports System.Windows

Namespace Helpers
    Public Class BindingProxy
        Inherits Freezable

        #Region "Overrides of Freezable"

        Protected Overrides Function CreateInstanceCore() As Freezable
            Return New BindingProxy()
        End Function

        #Region "Data Property"

        Public Shared ReadOnly DataProperty As DependencyProperty =
            DependencyProperty.Register("Data", GetType(Object), GetType(BindingProxy), New UIPropertyMetadata(Nothing))

        Public Property Data As Object
            Get
                Return GetValue(DataProperty)
            End Get
            Set(value As Object)
                SetValue(DataProperty, value)
            End Set
        End Property

        #End Region

        #End Region
    End Class
End Namespace
