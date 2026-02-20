Imports System.Collections.ObjectModel

Namespace Models
    Public Class MenuItem
        Inherits ViewModels.BaseViewModel

        Public Property Title As String
        Public Property Icon As String
        Public Property FormName As String
        Public Property IsVisible As Boolean

        ' === Parent/Child Support ===
        Public Property IsParent As Boolean = False
        Public Property Children As ObservableCollection(Of MenuItem)

        Private _isExpanded As Boolean
        Public Property IsExpanded As Boolean
            Get
                Return _isExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isExpanded, value)
            End Set
        End Property

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
