Namespace Models
    Public Class PagedResult(Of T)
        Public Property Data As List(Of T)
        Public Property TotalCount As Integer

        Public Sub New()
            Data = New List(Of T)()
        End Sub
    End Class
End Namespace
