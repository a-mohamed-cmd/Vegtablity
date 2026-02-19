Namespace Models
    Public Class MenuItem
        Inherits ViewModels.BaseViewModel

        Public Property Title As String
        Public Property Icon As String
        Public Property FormName As String
        Public Property IsVisible As Boolean

        Private _isSelected As Boolean
        Public Property IsSelected As Boolean
            Get
                Return _isSelected
            End Get
            Set(value As Boolean)
                SetProperty(_isSelected, value)
            End Set
        End Property
    End Class
End Namespace
