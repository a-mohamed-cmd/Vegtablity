Namespace Models
    Public Class RolePermission
        Inherits ViewModels.BaseViewModel

        Private _permID As Integer
        Public Property PermID As Integer
            Get
                Return _permID
            End Get
            Set(value As Integer)
                SetProperty(_permID, value)
            End Set
        End Property

        Private _roleID As Integer
        Public Property RoleID As Integer
            Get
                Return _roleID
            End Get
            Set(value As Integer)
                SetProperty(_roleID, value)
            End Set
        End Property

        Private _formName As String
        Public Property FormName As String
            Get
                Return _formName
            End Get
            Set(value As String)
                SetProperty(_formName, value)
            End Set
        End Property

        Private _canAdd As Boolean
        Public Property CanAdd As Boolean
            Get
                Return _canAdd
            End Get
            Set(value As Boolean)
                SetProperty(_canAdd, value)
            End Set
        End Property

        Private _canEdit As Boolean
        Public Property CanEdit As Boolean
            Get
                Return _canEdit
            End Get
            Set(value As Boolean)
                SetProperty(_canEdit, value)
            End Set
        End Property

        Private _canDelete As Boolean
        Public Property CanDelete As Boolean
            Get
                Return _canDelete
            End Get
            Set(value As Boolean)
                SetProperty(_canDelete, value)
            End Set
        End Property

        Private _canView As Boolean
        Public Property CanView As Boolean
            Get
                Return _canView
            End Get
            Set(value As Boolean)
                SetProperty(_canView, value)
            End Set
        End Property

        Private _canPrint As Boolean
        Public Property CanPrint As Boolean
            Get
                Return _canPrint
            End Get
            Set(value As Boolean)
                SetProperty(_canPrint, value)
            End Set
        End Property

        Private _displayName As String
        Public Property DisplayName As String
            Get
                Return _displayName
            End Get
            Set(value As String)
                SetProperty(_displayName, value)
            End Set
        End Property
    End Class
End Namespace
