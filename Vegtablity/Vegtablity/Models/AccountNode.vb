Imports System.Collections.ObjectModel
Imports System.Windows.Media
Imports Vegtablity.Models

Namespace Models
    Public Class AccountNode
        Inherits ViewModels.BaseViewModel

        Private _account As Account
        Private _parentNode As AccountNode
        Private _children As ObservableCollection(Of AccountNode)
        Private _level As Integer
        Private _isExpanded As Boolean = True
        Private _isSelected As Boolean
        Private _isHighlighted As Boolean
        Private _isVisible As Boolean = True

        Public Sub New(acc As Account, Optional parent As AccountNode = Nothing, Optional nodeLevel As Integer = 0)
            _account = acc
            _parentNode = parent
            _level = nodeLevel
            _children = New ObservableCollection(Of AccountNode)()
        End Sub

        Public Property Account As Account
            Get
                Return _account
            End Get
            Set(value As Account)
                SetProperty(_account, value)
                OnPropertyChanged(NameOf(AccountCode))
                OnPropertyChanged(NameOf(AccountName))
                OnPropertyChanged(NameOf(AccountType))
                OnPropertyChanged(NameOf(IsTransactional))
                OnPropertyChanged(NameOf(DisplayText))
                OnPropertyChanged(NameOf(NodeIcon))
            End Set
        End Property

        Public Property ParentNode As AccountNode
            Get
                Return _parentNode
            End Get
            Set(value As AccountNode)
                SetProperty(_parentNode, value)
            End Set
        End Property

        Public Property Children As ObservableCollection(Of AccountNode)
            Get
                Return _children
            End Get
            Set(value As ObservableCollection(Of AccountNode))
                SetProperty(_children, value)
                OnPropertyChanged(NameOf(HasChildren))
                OnPropertyChanged(NameOf(ChildrenCountText))
                OnPropertyChanged(NameOf(NodeIcon))
            End Set
        End Property

        Public Property Level As Integer
            Get
                Return _level
            End Get
            Set(value As Integer)
                SetProperty(_level, value)
                OnPropertyChanged(NameOf(LevelBadgeText))
                OnPropertyChanged(NameOf(LevelBadgeBackground))
                OnPropertyChanged(NameOf(LevelBadgeForeground))
            End Set
        End Property

        Public Property IsExpanded As Boolean
            Get
                Return _isExpanded
            End Get
            Set(value As Boolean)
                SetProperty(_isExpanded, value)
            End Set
        End Property

        Public Property IsSelected As Boolean
            Get
                Return _isSelected
            End Get
            Set(value As Boolean)
                SetProperty(_isSelected, value)
            End Set
        End Property

        Public Property IsHighlighted As Boolean
            Get
                Return _isHighlighted
            End Get
            Set(value As Boolean)
                SetProperty(_isHighlighted, value)
            End Set
        End Property

        Public Property IsVisible As Boolean
            Get
                Return _isVisible
            End Get
            Set(value As Boolean)
                SetProperty(_isVisible, value)
            End Set
        End Property

        Public ReadOnly Property HasChildren As Boolean
            Get
                Return Children IsNot Nothing AndAlso Children.Count > 0
            End Get
        End Property

        Public ReadOnly Property ChildrenCountText As String
            Get
                If HasChildren Then
                    Return $"({Children.Count})"
                End If
                Return String.Empty
            End Get
        End Property

        Public ReadOnly Property AccountCode As String
            Get
                Return If(Account?.AccountCode, "")
            End Get
        End Property

        Public ReadOnly Property AccountName As String
            Get
                Return If(Account?.AccountName, "")
            End Get
        End Property

        Public ReadOnly Property AccountType As String
            Get
                Return If(Account?.AccountType, "")
            End Get
        End Property

        Public ReadOnly Property IsTransactional As Boolean
            Get
                Return If(Account?.IsTransactional, False)
            End Get
        End Property

        Public ReadOnly Property DisplayText As String
            Get
                Return $"{AccountCode}  —  {AccountName}"
            End Get
        End Property

        Public ReadOnly Property LevelBadgeText As String
            Get
                Select Case Level
                    Case 0
                        Return "مستوى 0 (رئيسي)"
                    Case 1
                        Return "مستوى 1 (فرعي)"
                    Case 2
                        Return "مستوى 2 (فرعي للفرعي)"
                    Case Else
                        Return $"مستوى {Level}"
                End Select
            End Get
        End Property

        Public ReadOnly Property LevelBadgeBackground As String
            Get
                Select Case Level
                    Case 0
                        Return "#EDE9FE" ' Purple-100
                    Case 1
                        Return "#E0F2FE" ' Sky-100
                    Case 2
                        Return "#FEF3C7" ' Amber-100
                    Case Else
                        Return "#F1F5F9" ' Slate-100
                End Select
            End Get
        End Property

        Public ReadOnly Property LevelBadgeForeground As String
            Get
                Select Case Level
                    Case 0
                        Return "#6D28D9" ' Purple-700
                    Case 1
                        Return "#0369A1" ' Sky-700
                    Case 2
                        Return "#B45309" ' Amber-700
                    Case Else
                        Return "#475569" ' Slate-600
                End Select
            End Get
        End Property

        Public ReadOnly Property AccountTypeBadgeBackground As String
            Get
                Select Case Account?.AccountType?.ToLowerInvariant()
                    Case "assets", "الأصول"
                        Return "#DCFCE7" ' Green-100
                    Case "liabilities", "الخصوم"
                        Return "#FEE2E2" ' Red-100
                    Case "equity", "حقوق الملكية"
                        Return "#E0E7FF" ' Indigo-100
                    Case "revenue", "الإيرادات"
                        Return "#CCFBF1" ' Teal-100
                    Case "expenses", "المصروفات"
                        Return "#FFEDD5" ' Orange-100
                    Case Else
                        Return "#F1F5F9"
                End Select
            End Get
        End Property

        Public ReadOnly Property AccountTypeBadgeForeground As String
            Get
                Select Case Account?.AccountType?.ToLowerInvariant()
                    Case "assets", "الأصول"
                        Return "#15803D" ' Green-700
                    Case "liabilities", "الخصوم"
                        Return "#B91C1C" ' Red-700
                    Case "equity", "حقوق الملكية"
                        Return "#4338CA" ' Indigo-700
                    Case "revenue", "الإيرادات"
                        Return "#0F766E" ' Teal-700
                    Case "expenses", "المصروفات"
                        Return "#C2410C" ' Orange-700
                    Case Else
                        Return "#475569"
                End Select
            End Get
        End Property

        Public ReadOnly Property AccountTypeArabicName As String
            Get
                Select Case Account?.AccountType?.ToLowerInvariant()
                    Case "assets"
                        Return "الأصول"
                    Case "liabilities"
                        Return "الخصوم"
                    Case "equity"
                        Return "حقوق الملكية"
                    Case "revenue"
                        Return "الإيرادات"
                    Case "expenses"
                        Return "المصروفات"
                    Case Else
                        Return If(Account?.AccountType, "")
                End Select
            End Get
        End Property

        Public ReadOnly Property NodeIcon As String
            Get
                If Level = 0 Then
                    Return "📁"
                ElseIf HasChildren Then
                    Return "📂"
                ElseIf IsTransactional Then
                    Return "📄"
                Else
                    Return "📑"
                End If
            End Get
        End Property

        Public Sub SetExpandedRecursive(expanded As Boolean)
            IsExpanded = expanded
            If Children IsNot Nothing Then
                For Each child In Children
                    child.SetExpandedRecursive(expanded)
                Next
            End If
        End Sub
    End Class
End Namespace
